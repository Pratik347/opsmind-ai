"""OpsMind AI — UI components for the Streamlit Command Center."""

import re
import streamlit as st
import pandas as pd


# -- Actor display formatting ----------------------------------------------

_ACTOR_DISPLAY_NAMES = {
    "PRATIKPRITAM347": "Pratik Pritam",
}


def format_actor(raw_actor: str) -> str:
    """Return a human-friendly display name for a Snowflake actor."""
    if not raw_actor or not isinstance(raw_actor, str):
        return str(raw_actor) if raw_actor else ""
    stripped = raw_actor.strip()
    if stripped == "None":
        return "\u2014 (identity unavailable)"
    return _ACTOR_DISPLAY_NAMES.get(stripped, stripped)


def format_actor_column(df: pd.DataFrame, column: str) -> pd.DataFrame:
    """Apply actor formatting to a column in a DataFrame copy."""
    if column in df.columns:
        df = df.copy()
        df[column] = df[column].apply(format_actor)
    return df


# -- Column and value humanization -----------------------------------------

_COLUMN_LABELS = {
    "MACHINE_ID": "Machine ID",
    "MACHINE_NAME": "Machine Name",
    "MACHINE_TYPE": "Machine Type",
    "MACHINE_COUNT": "Machines",
    "RISK_SCORE": "Risk Index",
    "RISK_BAND": "Risk Band",
    "DATA_QUALITY": "Data Quality",
    "DATA_COMPLETENESS_PCT": "Completeness %",
    "OEE_PCT": "OEE %",
    "AVAILABILITY_PCT": "Availability %",
    "PERFORMANCE_PCT": "Performance %",
    "QUALITY_PCT": "Quality %",
    "SIGNAL_TYPE": "Signal Type",
    "DEVIATION_PCT": "Deviation %",
    "DETECTED_AT": "Detected At",
    "SEVERITY": "Severity",
    "DESCRIPTION": "Description",
    "EVENT_TYPE": "Event",
    "ENTITY_TYPE": "Entity",
    "ENTITY_ID": "Entity ID",
    "EVENT_TS": "Timestamp",
    "ACTOR": "Actor",
    "DETAILS": "Details",
    "AUDIT_ID": "Audit ID",
    "APPROVAL_ID": "Approval ID",
    "RECOMMENDATION_ID": "Rec. ID",
    "DECISION": "Decision",
    "DECIDED_BY": "Decided By",
    "DECIDED_AT": "Decided At",
    "COMMENTS": "Comments",
    "ACTION_ID": "Action ID",
    "ACTION_TYPE": "Action Type",
    "EXECUTED_BY": "Executed By",
    "EXECUTED_AT": "Executed At",
    "RESULT": "Result",
    "STATUS": "Status",
    "PRIORITY": "Priority",
    "GENERATED_AT": "Generated At",
    "PLANT_NAME": "Plant",
    "REGION": "Region",
    "LINE_COUNT": "Lines",
    "LINE_NAME": "Line",
    "METRIC_DATE": "Date",
    "CRITICALITY_RATING": "Criticality",
    "MAINTENANCE_ID": "Maintenance ID",
    "MAINTENANCE_TYPE": "Type",
    "COMPONENT": "Component",
    "SCHEDULED_DATE": "Scheduled",
    "COMPLETED_DATE": "Completed",
    "TECHNICIAN": "Technician",
    "COST_USD": "Cost (USD)",
    "FAILURE_ID": "Failure ID",
    "FAILURE_MODE": "Failure Mode",
    "ROOT_CAUSE": "Root Cause",
    "FAILURE_START": "Started",
    "FAILURE_END": "Ended",
    "DOWNTIME_MINUTES": "Downtime (min)",
    "REPAIR_COST_USD": "Repair Cost (USD)",
    "CONFIDENCE_SCORE": "Confidence",
    "ANOMALY_ID": "Anomaly ID",
}

_ENUM_LABELS = {
    "thermal_anomaly": "Thermal Anomaly",
    "vibration_anomaly": "Vibration Anomaly",
    "oee_decline": "OEE Decline",
    "coolant_system": "Coolant System",
    "bearing_failure": "Bearing Failure",
    "spindle_fault": "Spindle Fault",
    "motor_overload": "Motor Overload",
    "tool_wear": "Tool Wear",
    "pending": "Pending",
    "approved": "Approved",
    "rejected": "Rejected",
    "executed": "Executed",
    "completed": "Completed",
    "scheduled": "Scheduled",
    "overdue": "Overdue",
    "in_progress": "In Progress",
    "inspect": "Inspect",
    "replace": "Replace",
    "repair": "Repair",
    "overhaul": "Overhaul",
    "critical": "Critical",
    "high": "High",
    "medium": "Medium",
    "low": "Low",
    "warning": "Warning",
    "info": "Info",
    "CRITICAL": "Critical",
    "HIGH": "High",
    "MEDIUM": "Medium",
    "LOW": "Low",
    "COMPLETE": "Complete",
    "PARTIAL": "Partial",
    "INSUFFICIENT": "Insufficient",
    "SYNTHETIC_DEMO": "Demo Data \u00b7 Governed Assumptions",
    "preventive": "Preventive",
    "corrective": "Corrective",
    "predictive": "Predictive",
    "recommendation_created": "Recommendation Created",
    "recommendation_approved": "Recommendation Approved",
    "recommendation_rejected": "Recommendation Rejected",
    "action_executed": "Action Executed",
    "RECOMMENDATION": "Recommendation",
    "ACTION": "Action",
}


def humanize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Rename DataFrame columns to human-readable labels."""
    return df.rename(columns={c: _COLUMN_LABELS.get(c, c) for c in df.columns})


def humanize_value(val) -> str:
    """Convert an enum-like value to a human-readable label."""
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return ""
    s = str(val).strip()
    if s in _ENUM_LABELS:
        return _ENUM_LABELS[s]
    if "_" in s and s == s.lower():
        return s.replace("_", " ").title()
    return s


def humanize_enum_columns(df: pd.DataFrame, columns: list) -> pd.DataFrame:
    """Humanize enum values in specified columns of a DataFrame copy."""
    df = df.copy()
    for col in columns:
        if col in df.columns:
            df[col] = df[col].apply(humanize_value)
    return df


# -- Rendering helpers -----------------------------------------------------

def render_kpi_row(metrics: list[tuple[str, str, str]]):
    """Render a row of KPI cards."""
    cols = st.columns(len(metrics))
    for col, (label, value, delta) in zip(cols, metrics):
        with col:
            if delta:
                st.metric(label=label, value=value, delta=delta)
            else:
                st.metric(label=label, value=value)


def render_risk_summary_cards(risk_df: pd.DataFrame):
    """Render fleet risk summary as colored metric cards."""
    band_order = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INCOMPLETE"]
    counts = {row["RISK_BAND"]: int(row["MACHINE_COUNT"]) for _, row in risk_df.iterrows()}
    metrics = []
    for band in band_order:
        count = counts.get(band, 0)
        if count > 0 or band in ("CRITICAL", "HIGH", "LOW"):
            icon = {"CRITICAL": "\U0001f534", "HIGH": "\U0001f7e0", "MEDIUM": "\U0001f7e1", "LOW": "\U0001f7e2", "INCOMPLETE": "\u26aa"}.get(band, "")
            metrics.append((f"{icon} {band}", str(count), None))
    if metrics:
        render_kpi_row(metrics)


def render_recommendation_card(rec: dict):
    """Render a single recommendation as an expander."""
    priority_icon = {"critical": "\U0001f534", "high": "\U0001f7e0", "medium": "\U0001f7e1", "low": "\U0001f7e2"}.get(rec.get("PRIORITY", ""), "")
    action_label = humanize_value(rec.get("ACTION_TYPE", ""))
    title = f"{priority_icon} {rec.get('RECOMMENDATION_ID', '')} \u2014 {rec.get('MACHINE_ID', '')} \u2014 {action_label}"

    with st.expander(title, expanded=rec.get("PRIORITY") == "critical"):
        st.markdown(f"**Description:** {rec.get('DESCRIPTION', '')}")
        st.markdown(f"**Rationale:** {rec.get('RATIONALE', '')}")
        st.markdown(f"**Evidence:** {rec.get('EVIDENCE_SUMMARY', '')}")
        c1, c2 = st.columns(2)
        with c1:
            st.metric("Maintenance Cost", f"${rec.get('ESTIMATED_COST_USD', 0):,.0f}")
        with c2:
            st.metric("Planned Downtime", f"{rec.get('ESTIMATED_DOWNTIME_HRS', 0)}h")
        if rec.get("RISK_IF_DEFERRED"):
            safe_text = rec["RISK_IF_DEFERRED"].replace("$", "\\$")
            st.warning(f"**Risk if deferred:** {safe_text}")


def render_oee_chart(oee_df: pd.DataFrame):
    """Render an OEE trend line chart with humanized legend."""
    if oee_df.empty:
        st.info("No OEE data available.")
        return
    chart_df = oee_df[["METRIC_DATE", "OEE_PCT", "AVAILABILITY_PCT", "PERFORMANCE_PCT", "QUALITY_PCT"]].copy()
    chart_df = chart_df.rename(columns={
        "METRIC_DATE": "Date", "OEE_PCT": "OEE %",
        "AVAILABILITY_PCT": "Availability %", "PERFORMANCE_PCT": "Performance %",
        "QUALITY_PCT": "Quality %",
    })
    chart_df = chart_df.set_index("Date")
    st.line_chart(chart_df)


def render_sensor_chart(sensor_df: pd.DataFrame, sensor_type: str):
    """Render a sensor trend chart for a specific type."""
    filtered = sensor_df[sensor_df["SENSOR_TYPE"] == sensor_type].copy()
    if filtered.empty:
        st.info(f"No {sensor_type.replace('_', ' ')} data available.")
        return
    chart_data = filtered[["READING_TS", "VALUE"]].set_index("READING_TS")
    st.line_chart(chart_data)


_SQL_BLOCK_RE = re.compile(
    r'\n*\*Query executed \(\d+ rows?\)\*\n```sql\n.*?\n```',
    re.DOTALL,
)


def render_agent_response(text: str):
    """Render agent response with SQL details in a collapsible section."""
    sql_blocks = _SQL_BLOCK_RE.findall(text)
    main_text = _SQL_BLOCK_RE.sub("", text).strip()

    if main_text:
        st.markdown(main_text)

    if sql_blocks:
        label = f"Query details ({len(sql_blocks)} executed)"
        with st.expander(label):
            for block in sql_blocks:
                st.markdown(block.strip())
