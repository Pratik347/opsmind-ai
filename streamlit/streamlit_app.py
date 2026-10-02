"""OpsMind AI — Command Center (Streamlit-in-Snowflake).

Enterprise operations intelligence platform. Five views:
  1. Operations Overview — fleet KPIs, risk summary, recent anomalies
  2. Asset Intelligence — per-machine risk drill-down with sensor trends
  3. AI Investigator — natural language investigation via Cortex Agent
  4. Decision Center — governed approval/execution workflow
  5. Audit & Governance — audit log, approval/action history

Security: runs as OPSMIND_STREAMLIT role (least-privilege).
Governance writes go through EXECUTE AS OWNER stored procedures.
Agent invocation uses DATA_AGENT_RUN with CORTEX_AGENT_USER.
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

from src.queries import (
    FLEET_RISK_SUMMARY, OEE_FLEET_LATEST, ANOMALY_RECENT, PLANT_SUMMARY,
    RISK_SCORES_ALL, OEE_TREND_FOR_MACHINE, SENSOR_TREND_FOR_MACHINE,
    MAINTENANCE_FOR_MACHINE, FAILURE_HISTORY_FOR_MACHINE, IMPACT_FOR_MACHINE,
    PENDING_RECOMMENDATIONS, ALL_RECOMMENDATIONS, APPROVED_READY_TO_EXECUTE,
    AUDIT_LOG_RECENT, APPROVAL_DECISIONS_RECENT, EXECUTED_ACTIONS_RECENT,
)
from src.agent import call_agent, extract_text_blocks, get_thread_info
from src.components import (
    render_risk_badge, render_kpi_row, render_risk_summary_cards,
    render_recommendation_card, render_oee_chart, render_sensor_chart,
)

st.set_page_config(
    page_title="OpsMind AI Command Center",
    page_icon="🏭",
    layout="wide",
    initial_sidebar_state="expanded",
)

session = get_active_session()


def run_query(sql: str, params: list = None) -> pd.DataFrame:
    """Execute a SQL query and return a pandas DataFrame.

    Uses Snowpark session.sql() with native ? bind variable support.
    """
    if params:
        return session.sql(sql, params=params).to_pandas()
    return session.sql(sql).to_pandas()


# -- Sidebar Navigation ---------------------------------------------------

st.sidebar.title("OpsMind AI")
st.sidebar.caption("Enterprise Operations Intelligence")

view = st.sidebar.radio(
    "Navigation",
    ["Operations Overview", "Asset Intelligence", "AI Investigator",
     "Decision Center", "Audit & Governance"],
    index=0,
)


# =========================================================================
# VIEW 1: Operations Overview
# =========================================================================

if view == "Operations Overview":
    st.title("Operations Overview")

    # Fleet risk summary
    st.subheader("Fleet Risk Summary")
    risk_df = run_query(FLEET_RISK_SUMMARY)
    render_risk_summary_cards(risk_df)

    # Plant summary
    st.subheader("Plant Inventory")
    plant_df = run_query(PLANT_SUMMARY)
    st.dataframe(plant_df, use_container_width=True, hide_index=True)

    # Latest OEE across fleet
    st.subheader("Latest OEE by Machine")
    oee_df = run_query(OEE_FLEET_LATEST)
    if not oee_df.empty:
        st.dataframe(
            oee_df[["MACHINE_NAME", "MACHINE_TYPE", "LINE_NAME", "OEE_PCT",
                     "AVAILABILITY_PCT", "PERFORMANCE_PCT", "QUALITY_PCT"]],
            use_container_width=True,
            hide_index=True,
        )

    # Recent anomalies
    st.subheader("Recent Anomaly Signals")
    anomaly_df = run_query(ANOMALY_RECENT)
    if not anomaly_df.empty:
        st.dataframe(
            anomaly_df[["MACHINE_NAME", "SIGNAL_TYPE", "SEVERITY",
                         "DEVIATION_PCT", "DETECTED_AT", "DESCRIPTION"]],
            use_container_width=True,
            hide_index=True,
        )
    else:
        st.info("No anomaly signals detected.")


# =========================================================================
# VIEW 2: Asset Intelligence
# =========================================================================

elif view == "Asset Intelligence":
    st.title("Asset Intelligence")

    # Risk scores table
    risk_all = run_query(RISK_SCORES_ALL)

    # Machine selector
    machine_options = risk_all["MACHINE_ID"].tolist()
    machine_names = risk_all.set_index("MACHINE_ID")["MACHINE_NAME"].to_dict()
    display_options = [f"{mid} — {machine_names.get(mid, '')}" for mid in machine_options]

    st.subheader("Fleet Risk Index")
    st.dataframe(
        risk_all[["MACHINE_ID", "MACHINE_NAME", "MACHINE_TYPE", "RISK_SCORE",
                   "RISK_BAND", "DATA_QUALITY", "DATA_COMPLETENESS_PCT"]],
        use_container_width=True,
        hide_index=True,
    )

    st.divider()

    # Machine detail drill-down
    selected_display = st.selectbox("Select machine for drill-down", display_options)
    if selected_display:
        selected_machine = selected_display.split(" — ")[0]
        machine_row = risk_all[risk_all["MACHINE_ID"] == selected_machine].iloc[0]

        # Risk header
        col1, col2, col3, col4 = st.columns(4)
        with col1:
            st.metric("Risk Score", f"{machine_row['RISK_SCORE']}" if pd.notna(machine_row["RISK_SCORE"]) else "N/A")
        with col2:
            st.markdown(f"**Risk Band:** {render_risk_badge(machine_row['RISK_BAND'])}")
        with col3:
            st.metric("Data Quality", machine_row["DATA_QUALITY"])
        with col4:
            st.metric("Criticality", machine_row["CRITICALITY_RATING"])

        # Feature score breakdown
        st.subheader("Risk Factor Breakdown")
        factors = {
            "Vibration Level (30%)": machine_row.get("VIBRATION_LEVEL_SCORE"),
            "Vibration Trend (20%)": machine_row.get("VIBRATION_TREND_SCORE"),
            "Thermal Deviation (20%)": machine_row.get("THERMAL_DEVIATION_SCORE"),
            "OEE Degradation (15%)": machine_row.get("OEE_DEGRADATION_SCORE"),
            "Maintenance Overdue (15%)": machine_row.get("MAINTENANCE_OVERDUE_SCORE"),
        }
        factor_df = pd.DataFrame([
            {"Factor": k, "Score": v if pd.notna(v) else None}
            for k, v in factors.items()
        ])
        st.dataframe(factor_df, use_container_width=True, hide_index=True)

        # OEE trend
        st.subheader("OEE Trend")
        oee_machine = run_query(OEE_TREND_FOR_MACHINE, [selected_machine])
        render_oee_chart(oee_machine)

        # Sensor trends
        st.subheader("Sensor Trends (7-day)")
        sensor_data = run_query(SENSOR_TREND_FOR_MACHINE, [selected_machine])
        tab_vib, tab_temp = st.tabs(["Vibration", "Bearing Temperature"])
        with tab_vib:
            render_sensor_chart(sensor_data, "vibration")
        with tab_temp:
            render_sensor_chart(sensor_data, "bearing_temp")

        # Maintenance history
        st.subheader("Maintenance History")
        maint_df = run_query(MAINTENANCE_FOR_MACHINE, [selected_machine])
        if not maint_df.empty:
            st.dataframe(maint_df, use_container_width=True, hide_index=True)
        else:
            st.info("No maintenance records.")

        # Failure history
        st.subheader("Failure History")
        fail_df = run_query(FAILURE_HISTORY_FOR_MACHINE, [selected_machine])
        if not fail_df.empty:
            st.dataframe(fail_df, use_container_width=True, hide_index=True)
        else:
            st.info("No failure records.")

        # Impact scenarios
        st.subheader("Business Impact Scenarios")
        impact_df = run_query(IMPACT_FOR_MACHINE, [selected_machine])
        if not impact_df.empty:
            for _, row in impact_df.iterrows():
                st.markdown(f"**Component:** {row['FAILURE_COMPONENT']} (Source: {row['ASSUMPTION_SOURCE']})")
                ic1, ic2, ic3 = st.columns(3)
                with ic1:
                    st.metric("Planned Intervention", f"${row['ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD']:,.0f}")
                with ic2:
                    st.metric("Unplanned Failure", f"${row['ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD']:,.0f}")
                with ic3:
                    st.metric("Potential Avoided Impact", f"${row['ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD']:,.0f}")
                st.caption(f"Basis: {row['ASSUMPTION_BASIS']} — These are estimates, not predictions.")
        else:
            st.info("No impact scenarios available for this machine.")


# =========================================================================
# VIEW 3: AI Investigator
# =========================================================================

elif view == "AI Investigator":
    st.title("AI Investigator")
    st.caption("Natural language investigation powered by Cortex Agent")

    # Initialize chat history
    if "agent_messages" not in st.session_state:
        st.session_state.agent_messages = []
    if "agent_thread_id" not in st.session_state:
        st.session_state.agent_thread_id = None
    if "agent_parent_msg_id" not in st.session_state:
        st.session_state.agent_parent_msg_id = None

    # Suggested questions
    st.markdown("**Suggested investigations:**")
    suggestions = [
        "Which machines are showing signs of operational degradation?",
        "What is the current failure risk index for M-302?",
        "What would be the business impact of a bearing failure on M-302?",
        "Are there any overdue maintenance tasks?",
        "Compare OEE trends for machines on Line 3.",
    ]
    suggestion_cols = st.columns(len(suggestions))
    for i, (col, suggestion) in enumerate(zip(suggestion_cols, suggestions)):
        with col:
            if st.button(suggestion[:30] + "...", key=f"sug_{i}", use_container_width=True):
                st.session_state.pending_question = suggestion

    # Display chat history
    for msg in st.session_state.agent_messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    # Chat input
    question = st.chat_input("Ask OpsMind AI about your operations...")

    # Handle suggestion button clicks
    if "pending_question" in st.session_state:
        question = st.session_state.pop("pending_question")

    if question:
        # Display user message
        st.session_state.agent_messages.append({"role": "user", "content": question})
        with st.chat_message("user"):
            st.markdown(question)

        # Call agent
        with st.chat_message("assistant"):
            with st.spinner("Investigating..."):
                response = call_agent(
                    session, question,
                    thread_id=st.session_state.agent_thread_id,
                    parent_message_id=st.session_state.agent_parent_msg_id,
                )

                # Update thread state
                thread_id, msg_id = get_thread_info(response)
                if thread_id is not None:
                    st.session_state.agent_thread_id = thread_id
                if msg_id is not None:
                    st.session_state.agent_parent_msg_id = msg_id

                # Render response
                text = extract_text_blocks(response)
                st.markdown(text)

                # Check for warnings
                warnings = response.get("warnings", [])
                for w in warnings:
                    st.warning(f"Agent warning: {w.get('message', '')}")

        st.session_state.agent_messages.append({"role": "assistant", "content": text})

    # Clear conversation button
    if st.session_state.agent_messages:
        if st.button("Clear conversation"):
            st.session_state.agent_messages = []
            st.session_state.agent_thread_id = None
            st.session_state.agent_parent_msg_id = None
            st.rerun()


# =========================================================================
# VIEW 4: Decision Center
# =========================================================================

elif view == "Decision Center":
    st.title("Decision Center")
    st.caption("Governed recommendation approval and execution workflow")

    tab_pending, tab_execute, tab_all = st.tabs(["Pending Approval", "Ready to Execute", "All Recommendations"])

    with tab_pending:
        pending_df = run_query(PENDING_RECOMMENDATIONS)

        if pending_df.empty:
            st.info("No pending recommendations. All actions have been reviewed.")
        else:
            st.markdown(f"**{len(pending_df)} pending recommendation(s)**")

            for _, rec in pending_df.iterrows():
                rec_dict = rec.to_dict()
                render_recommendation_card(rec_dict)

                rec_id = rec_dict["RECOMMENDATION_ID"]
                col_approve, col_reject = st.columns(2)

                with col_approve:
                    justification_approve = st.text_input(
                        "Approval justification", key=f"just_a_{rec_id}",
                        placeholder="Reason for approval..."
                    )
                    if st.button(f"Approve {rec_id}", key=f"btn_a_{rec_id}", type="primary"):
                        if not justification_approve.strip():
                            st.error("Justification required.")
                        else:
                            try:
                                session.sql(
                                    "CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION(?, ?, ?)",
                                    params=[rec_id, "approved", justification_approve]
                                ).collect()
                                st.success(f"{rec_id} approved.")
                                st.rerun()
                            except Exception as e:
                                st.error(f"Approval failed: {e}")

                with col_reject:
                    justification_reject = st.text_input(
                        "Rejection justification", key=f"just_r_{rec_id}",
                        placeholder="Reason for rejection..."
                    )
                    if st.button(f"Reject {rec_id}", key=f"btn_r_{rec_id}"):
                        if not justification_reject.strip():
                            st.error("Justification required.")
                        else:
                            try:
                                session.sql(
                                    "CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION(?, ?, ?)",
                                    params=[rec_id, "rejected", justification_reject]
                                ).collect()
                                st.success(f"{rec_id} rejected.")
                                st.rerun()
                            except Exception as e:
                                st.error(f"Rejection failed: {e}")

                st.divider()

    with tab_execute:
        approved_df = run_query(APPROVED_READY_TO_EXECUTE)

        if approved_df.empty:
            st.info("No approved recommendations awaiting execution.")
        else:
            st.markdown(f"**{len(approved_df)} approved recommendation(s) ready for execution**")

            for _, row in approved_df.iterrows():
                approval_id = row["APPROVAL_ID"]
                rec_id = row["RECOMMENDATION_ID"]
                st.markdown(f"**{rec_id}** (Approval: {approval_id}) — Approved by {row['DECIDED_BY']}")
                st.caption(f"Approved at: {row['DECIDED_AT']}")

                action_desc = st.text_input(
                    "Action description", key=f"act_desc_{approval_id}",
                    placeholder="Describe the action taken..."
                )
                action_type = st.text_input(
                    "Action type", key=f"act_type_{approval_id}",
                    value="Bearing inspection scheduled"
                )

                if st.button(f"Execute {approval_id}", key=f"btn_exec_{approval_id}", type="primary"):
                    if not action_desc.strip():
                        st.error("Action description required.")
                    else:
                        try:
                            session.sql(
                                "CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION(?, ?, ?)",
                                params=[approval_id, action_type, action_desc]
                            ).collect()
                            st.success(f"Action executed for {rec_id}.")
                            st.rerun()
                        except Exception as e:
                            st.error(f"Execution failed: {e}")

                st.divider()

    with tab_all:
        all_rec_df = run_query(ALL_RECOMMENDATIONS)
        st.dataframe(all_rec_df, use_container_width=True, hide_index=True)


# =========================================================================
# VIEW 5: Audit & Governance
# =========================================================================

elif view == "Audit & Governance":
    st.title("Audit & Governance")
    st.caption("Complete audit trail of all governance actions")

    tab_audit, tab_approvals, tab_actions = st.tabs(
        ["Audit Log", "Approval Decisions", "Executed Actions"]
    )

    with tab_audit:
        audit_df = run_query(AUDIT_LOG_RECENT)
        if not audit_df.empty:
            st.dataframe(audit_df, use_container_width=True, hide_index=True)
        else:
            st.info("No audit entries.")

    with tab_approvals:
        approvals_df = run_query(APPROVAL_DECISIONS_RECENT)
        if not approvals_df.empty:
            st.dataframe(approvals_df, use_container_width=True, hide_index=True)
        else:
            st.info("No approval decisions recorded.")

    with tab_actions:
        actions_df = run_query(EXECUTED_ACTIONS_RECENT)
        if not actions_df.empty:
            st.dataframe(actions_df, use_container_width=True, hide_index=True)
        else:
            st.info("No executed actions recorded.")


# -- Footer ----------------------------------------------------------------
st.sidebar.divider()
st.sidebar.caption("OpsMind AI v1.0 — Phase 5")
st.sidebar.caption("Powered by Snowflake Cortex")
