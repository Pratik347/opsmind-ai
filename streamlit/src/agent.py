"""OpsMind AI — Cortex Agent integration for Streamlit.

Invokes DATA_AGENT_RUN via SQL and parses the response. Thinking
blocks are silently skipped — only text, tool_use, and tool_result
blocks are rendered.
"""

import json
import streamlit as st


def call_agent(session, question: str, thread_id: int = None, parent_message_id: int = None) -> dict:
    """Call the OpsMind agent and return the parsed response dict."""
    messages = [
        {
            "role": "user",
            "content": [{"type": "text", "text": question}],
        }
    ]

    request_body = {"messages": messages}
    if thread_id is not None:
        request_body["thread_id"] = thread_id
        request_body["parent_message_id"] = parent_message_id if parent_message_id is not None else 0

    # DATA_AGENT_RUN requires its second argument to be a string constant
    # (Snowflake error: "argument 1 to function ... needs to be constant").
    # Snowpark session.sql() bind variables (?) cannot be used here.
    #
    # Mitigation layers:
    #   1. json.dumps() structurally escapes the user input within a JSON
    #      string value, preventing breakout from the JSON structure.
    #   2. The outer '' escaping handles the SQL string literal boundary.
    #   3. Snowflake does not interpret backslash as an escape in string
    #      literals, so multi-byte / backslash attacks are not applicable.
    #   4. The value cannot alter SQL structure — it is always the second
    #      positional argument to DATA_AGENT_RUN, parsed as a JSON body
    #      by the function, not as SQL.
    request_json = json.dumps(request_body)
    escaped = request_json.replace("'", "''")

    create_thread = "TRUE" if thread_id is None else "FALSE"

    sql = f"""
    SELECT TRY_PARSE_JSON(
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
            'OPSMIND.APP.OPSMIND_AGENT',
            '{escaped}',
            {create_thread}
        )
    ) AS resp
    """

    try:
        result = session.sql(sql).collect()
        if result and result[0]["RESP"]:
            resp = json.loads(str(result[0]["RESP"]))
            return resp
        return {"error": "Empty response from agent"}
    except Exception as e:
        return {"error": str(e)}


def extract_text_blocks(response: dict) -> str:
    """Extract displayable text from agent response.

    Silently skips thinking blocks. Renders text blocks directly.
    For tool_result blocks containing SQL results, formats a summary.
    """
    if "error" in response:
        return f"**Error:** {response['error']}"

    content = response.get("content", [])
    parts = []

    for block in content:
        block_type = block.get("type", "")

        if block_type == "thinking":
            continue

        elif block_type == "text":
            text = block.get("text", "")
            if text.strip():
                parts.append(text)

        elif block_type == "tool_result":
            tool_result = block.get("tool_result", {})
            tool_content = tool_result.get("content", [])
            for item in tool_content:
                if item.get("type") == "json":
                    json_data = item.get("json", {})
                    sql = json_data.get("sql", "")
                    results = json_data.get("results", {})
                    num_rows = results.get("numRows", 0)
                    if sql:
                        parts.append(f"\n*Query executed ({num_rows} rows)*\n```sql\n{sql}\n```")

    return "\n\n".join(parts) if parts else "No response content."


def get_thread_info(response: dict) -> tuple:
    """Extract thread_id and message_id from response metadata."""
    metadata = response.get("metadata", {})
    thread_id = metadata.get("thread_id")
    message_id = metadata.get("message_id")
    return thread_id, message_id
