"""OpsMind AI — Command Center (Streamlit-in-Snowflake).

Enterprise operations intelligence platform. Five views:
  1. Operations Overview — fleet KPIs, risk summary, attention alerts
  2. Asset Intelligence — per-machine risk drill-down with sensor trends
  3. AI Investigator — natural language investigation via Cortex Agent
  4. Decision Center — governed approval/execution workflow
  5. Audit & Governance — audit log, approval/action history

Security: runs as OPSMIND_STREAMLIT role (least-privilege, owner-rights).
Governance writes go through EXECUTE AS OWNER stored procedures.
Agent invocation uses DATA_AGENT_RUN with CORTEX_AGENT_USER.

Compatibility: requires Snowflake warehouse-runtime Streamlit >= 1.45.0
(pinned via environment.yml for st.user and hide_index support).
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

from src.queries import (
    FLEET_RISK_SUMMARY, OEE_FLEET_LATEST, ANOMALY_RECENT, PLANT_SUMMARY,
    RISK_SCORES_ALL, OEE_TREND_FOR_MACHINE, SENSOR_TREND_FOR_MACHINE,
    MAINTENANCE_FOR_MACHINE, FAILURE_HISTORY_FOR_MACHINE, IMPACT_FOR_MACHINE,
    EVIDENCE_COMPONENT_FOR_MACHINE,
    PENDING_RECOMMENDATIONS, ALL_RECOMMENDATIONS, APPROVED_READY_TO_EXECUTE,
    AUDIT_LOG_RECENT, APPROVAL_DECISIONS_RECENT, EXECUTED_ACTIONS_RECENT,
)
from src.agent import call_agent, extract_text_blocks, get_thread_info
from src.components import (
    render_risk_summary_cards, render_recommendation_card,
    render_oee_chart, render_sensor_chart, render_agent_response,
    format_actor, format_actor_column,
    humanize_columns, humanize_value, humanize_enum_columns,
)

session = get_active_session()

# Capture the authenticated viewer identity.
# In Streamlit owner-rights mode, CURRENT_USER() returns the owner (a role, not a user),
# which resolves to NULL. st.user.user_name is the Snowflake-authenticated viewer identity
# provided by the Streamlit runtime — it is not user-supplied text.
# See: https://docs.snowflake.com/en/developer-guide/streamlit/app-development/personalization
_viewer_user = st.user.user_name


def run_query(sql: str, params: list = None) -> pd.DataFrame:
    """Execute a SQL query and return a pandas DataFrame."""
    if params:
        return session.sql(sql, params=params).to_pandas()
    return session.sql(sql).to_pandas()


def safe_rerun():
    """Rerun the app using whichever API is available."""
    st.session_state.pop("_processing", None)
    if hasattr(st, "rerun"):
        st.rerun()
    else:
        st.experimental_rerun()


def _is_processing() -> bool:
    return st.session_state.get("_processing", False)


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

    # Fetch all data needed for this view
    risk_summary = run_query(FLEET_RISK_SUMMARY)
    risk_all = run_query(RISK_SCORES_ALL)
    oee_fleet = run_query(OEE_FLEET_LATEST)
    anomaly_df = run_query(ANOMALY_RECENT)
    plant_df = run_query(PLANT_SUMMARY)

    # -- Fleet Risk Summary ------------------------------------------------
    st.subheader("Fleet Risk Summary")
    total_machines = len(risk_all)
    st.caption(f"{total_machines} machines monitored")
    render_risk_summary_cards(risk_summary)

    # -- Attention Required ------------------------------------------------
    attention = risk_all[risk_all["RISK_BAND"].isin(["HIGH", "CRITICAL"])].copy()

    if not attention.empty:
        st.subheader("Attention Required")

        anomaly_counts = {}
        anomaly_types_map = {}
        if not anomaly_df.empty:
            anomaly_counts = anomaly_df.groupby("MACHINE_ID").size().to_dict()
            anomaly_types_map = (
                anomaly_df.groupby("MACHINE_ID")["SIGNAL_TYPE"]
                .apply(list).to_dict()
            )

        for _, m in attention.iterrows():
            mid = m["MACHINE_ID"]
            band = m["RISK_BAND"]
            band_icon = {"CRITICAL": "\U0001f534", "HIGH": "\U0001f7e0"}.get(band, "\u26aa")

            with st.container(border=True):
                st.markdown(f"#### {band_icon} {band} \u2014 {mid} \u00b7 {m['MACHINE_NAME']}")

                c1, c2, c3, c4 = st.columns(4)
                with c1:
                    score = m["RISK_SCORE"]
                    st.metric("Risk Index", f"{score:.1f}" if pd.notna(score) else "N/A")
                with c2:
                    oee = m.get("LATEST_OEE")
                    st.metric("Latest OEE", f"{oee:.1f}%" if pd.notna(oee) else "N/A")
                with c3:
                    st.metric("Active Anomalies", str(anomaly_counts.get(mid, 0)))
                with c4:
                    st.metric("Data Quality", humanize_value(m["DATA_QUALITY"]))

                atypes = anomaly_types_map.get(mid, [])
                if atypes:
                    labels = ", ".join(sorted(set(humanize_value(t) for t in atypes)))
                    st.caption(f"Conditions: {labels}")
    else:
        st.subheader("Fleet Status")
        st.success("All assets operating within normal parameters.")

    st.divider()

    # -- Plant Inventory ---------------------------------------------------
    st.subheader("Plant Inventory")
    st.dataframe(humanize_columns(plant_df), use_container_width=True, hide_index=True)

    # -- Latest OEE --------------------------------------------------------
    st.subheader("Latest OEE by Machine")
    if not oee_fleet.empty:
        oee_display = oee_fleet[["MACHINE_NAME", "MACHINE_TYPE", "LINE_NAME", "OEE_PCT",
                                  "AVAILABILITY_PCT", "PERFORMANCE_PCT", "QUALITY_PCT"]].copy()
        st.dataframe(humanize_columns(oee_display), use_container_width=True, hide_index=True)

    # -- Recent Anomalies --------------------------------------------------
    st.subheader("Recent Anomaly Signals")
    if not anomaly_df.empty:
        anom_display = anomaly_df[["MACHINE_NAME", "SIGNAL_TYPE", "SEVERITY",
                                    "DEVIATION_PCT", "DETECTED_AT", "DESCRIPTION"]].copy()
        anom_display = humanize_enum_columns(anom_display, ["SIGNAL_TYPE", "SEVERITY"])
        st.dataframe(humanize_columns(anom_display), use_container_width=True, hide_index=True)
    else:
        st.info("No anomaly signals detected.")


# =========================================================================
# VIEW 2: Asset Intelligence
# =========================================================================

elif view == "Asset Intelligence":
    st.title("Asset Intelligence")

    risk_all = run_query(RISK_SCORES_ALL)

    # Machine selector
    machine_options = risk_all["MACHINE_ID"].tolist()
    machine_names = risk_all.set_index("MACHINE_ID")["MACHINE_NAME"].to_dict()
    display_options = [f"{mid} \u2014 {machine_names.get(mid, '')}" for mid in machine_options]

    st.subheader("Fleet Risk Index")
    fleet_display = risk_all[["MACHINE_ID", "MACHINE_NAME", "MACHINE_TYPE", "RISK_SCORE",
                               "RISK_BAND", "DATA_QUALITY", "DATA_COMPLETENESS_PCT"]].copy()
    fleet_display = humanize_enum_columns(fleet_display, ["RISK_BAND", "DATA_QUALITY"])
    st.dataframe(humanize_columns(fleet_display), use_container_width=True, hide_index=True)

    st.divider()

    # -- Machine detail drill-down -----------------------------------------
    selected_display = st.selectbox("Select machine for drill-down", display_options)
    if selected_display:
        selected_machine = selected_display.split(" \u2014 ")[0]
        machine_row = risk_all[risk_all["MACHINE_ID"] == selected_machine].iloc[0]

        # Prominent risk header
        risk_band = machine_row["RISK_BAND"]
        band_icon = {"CRITICAL": "\U0001f534", "HIGH": "\U0001f7e0", "MEDIUM": "\U0001f7e1", "LOW": "\U0001f7e2"}.get(risk_band, "\u26aa")
        score = machine_row["RISK_SCORE"]
        score_text = f"{score:.1f}" if pd.notna(score) else "N/A"
        st.markdown(f"### {band_icon} {machine_row['MACHINE_NAME']} \u2014 Risk Index {score_text}")

        c1, c2, c3, c4 = st.columns(4)
        with c1:
            st.metric("Risk Index", score_text)
        with c2:
            st.metric("Risk Band", humanize_value(risk_band))
        with c3:
            st.metric("Data Quality", humanize_value(machine_row["DATA_QUALITY"]))
        with c4:
            st.metric("Criticality", str(machine_row["CRITICALITY_RATING"]))

        # Risk factor breakdown with progress bars
        st.subheader("Risk Factor Breakdown")
        factors = [
            ("Vibration Level (30%)", machine_row.get("VIBRATION_LEVEL_SCORE")),
            ("Vibration Trend (20%)", machine_row.get("VIBRATION_TREND_SCORE")),
            ("Thermal Deviation (20%)", machine_row.get("THERMAL_DEVIATION_SCORE")),
            ("OEE Degradation (15%)", machine_row.get("OEE_DEGRADATION_SCORE")),
            ("Maintenance Overdue (15%)", machine_row.get("MAINTENANCE_OVERDUE_SCORE")),
        ]
        for factor_name, factor_score in factors:
            col_label, col_bar = st.columns([2, 3])
            with col_label:
                st.markdown(f"**{factor_name}**")
            with col_bar:
                if pd.notna(factor_score):
                    val = float(factor_score)
                    st.progress(min(val / 100.0, 1.0), text=f"{val:.1f}")
                else:
                    st.caption("N/A")

        # OEE Trend
        st.subheader("OEE Trend")
        oee_machine = run_query(OEE_TREND_FOR_MACHINE, [selected_machine])
        render_oee_chart(oee_machine)

        # Sensor Trends
        st.subheader("Sensor Trends (7-day)")
        sensor_data = run_query(SENSOR_TREND_FOR_MACHINE, [selected_machine])
        tab_vib, tab_temp = st.tabs(["Vibration", "Bearing Temperature"])
        with tab_vib:
            render_sensor_chart(sensor_data, "vibration")
        with tab_temp:
            render_sensor_chart(sensor_data, "bearing_temp")

        # Maintenance History
        st.subheader("Maintenance History")
        maint_df = run_query(MAINTENANCE_FOR_MACHINE, [selected_machine])
        if not maint_df.empty:
            maint_display = humanize_enum_columns(maint_df, ["MAINTENANCE_TYPE", "STATUS", "COMPONENT"])
            st.dataframe(humanize_columns(maint_display), use_container_width=True, hide_index=True)
        else:
            st.info("No maintenance records.")

        # Failure History
        st.subheader("Failure History")
        fail_df = run_query(FAILURE_HISTORY_FOR_MACHINE, [selected_machine])
        if not fail_df.empty:
            fail_display = humanize_enum_columns(fail_df, ["FAILURE_MODE", "SEVERITY"])
            st.dataframe(humanize_columns(fail_display), use_container_width=True, hide_index=True)
        else:
            st.info("No failure records.")

        # Business Impact Scenarios
        st.subheader("Business Impact Scenarios")
        impact_df = run_query(IMPACT_FOR_MACHINE, [selected_machine])
        if not impact_df.empty:
            # Identify evidence-aligned component from active recommendations
            evidence_component = None
            rec_df = run_query(EVIDENCE_COMPONENT_FOR_MACHINE, [selected_machine])
            if not rec_df.empty:
                desc_lower = str(rec_df.iloc[0]["DESCRIPTION"]).lower()
                for comp in impact_df["FAILURE_COMPONENT"]:
                    if str(comp).lower() in desc_lower:
                        evidence_component = str(comp).lower()
                        break

            if evidence_component:
                impact_sorted = impact_df.copy()
                impact_sorted["_sort"] = impact_sorted["FAILURE_COMPONENT"].apply(
                    lambda c: 0 if str(c).lower() == evidence_component else 1
                )
                impact_sorted = impact_sorted.sort_values(
                    ["_sort", "ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD"],
                    ascending=[True, False],
                ).drop(columns=["_sort"]).reset_index(drop=True)
                primary_label = "Evidence-Aligned Scenario"
            else:
                impact_sorted = impact_df.sort_values(
                    "ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD", ascending=False
                ).reset_index(drop=True)
                primary_label = "Highest Avoided Impact"

            has_multiple = len(impact_sorted) > 1

            for idx, row in impact_sorted.iterrows():
                component_name = str(row["FAILURE_COMPONENT"]).replace("_", " ").title()
                source_label = humanize_value(row["ASSUMPTION_SOURCE"])

                if idx == 0 and has_multiple:
                    wrapper = st.container(border=True)
                    heading = f"#### {component_name} \u2014 {primary_label}"
                elif has_multiple:
                    wrapper = st.expander(component_name)
                    heading = None
                else:
                    wrapper = st.container()
                    heading = f"**{component_name}**"

                with wrapper:
                    if heading:
                        st.markdown(heading)
                    ic1, ic2, ic3 = st.columns(3)
                    with ic1:
                        st.metric("Planned Intervention", f"${row['ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD']:,.0f}")
                    with ic2:
                        st.metric("Unplanned Failure", f"${row['ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD']:,.0f}")
                    with ic3:
                        st.metric("Potential Avoided Impact", f"${row['ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD']:,.0f}")
                    st.caption(f"Source: {source_label} \u00b7 Basis: {row['ASSUMPTION_BASIS']}")
                    st.caption("These are estimates derived from governed assumptions, not predictions.")
        else:
            st.info("No impact scenarios available for this machine.")


# =========================================================================
# VIEW 3: AI Investigator
# =========================================================================

elif view == "AI Investigator":
    st.title("AI Investigator")
    st.caption("Natural language investigation powered by Cortex Agent")

    # Initialize session state
    if "agent_messages" not in st.session_state:
        st.session_state.agent_messages = []
    if "agent_thread_id" not in st.session_state:
        st.session_state.agent_thread_id = None
    if "agent_parent_msg_id" not in st.session_state:
        st.session_state.agent_parent_msg_id = None
    if "_input_version" not in st.session_state:
        st.session_state._input_version = 0

    # Recovery: if processing flag is stuck but no pending question exists, clear it.
    # This handles interrupted runs (e.g. user navigated away mid-agent-call).
    if st.session_state.get("_processing") and "_pending_agent_question" not in st.session_state:
        st.session_state.pop("_processing", None)

    # Suggested questions
    st.markdown("**Suggested investigations:**")
    suggestions = [
        "Which machines are showing signs of operational degradation?",
        "What is the current failure risk index for M-302?",
        "What would be the business impact of a bearing failure on M-302?",
        "Are there any overdue maintenance tasks?",
        "Compare OEE trends for machines on Line 3.",
    ]
    row1 = st.columns(3)
    row2 = st.columns(3)
    sug_layout = [row1[0], row1[1], row1[2], row2[0], row2[1]]
    for i, (col, suggestion) in enumerate(zip(sug_layout, suggestions)):
        with col:
            if st.button(suggestion, key=f"sug_{i}", use_container_width=True, disabled=_is_processing()):
                st.session_state.pending_question = suggestion

    # Display conversation history
    for msg in st.session_state.agent_messages:
        role_label = "You" if msg["role"] == "user" else "OpsMind AI"
        st.markdown(f"**{role_label}:**")
        if msg["role"] == "assistant":
            render_agent_response(msg["content"])
        else:
            st.markdown(msg["content"])
        st.markdown("---")

    # Question input form — Enter and click both submit via st.form
    with st.form("investigator_form", clear_on_submit=True):
        question = st.text_input(
            "Ask OpsMind AI about your operations",
            key=f"agent_question_input_{st.session_state._input_version}",
            placeholder="e.g., Why is M-302 at elevated risk?",
            disabled=_is_processing(),
        )
        form_submitted = st.form_submit_button(
            "Investigate", type="primary", disabled=_is_processing(),
        )

    # Handle suggestion button clicks — auto-investigate on next rerun
    auto_investigate = False
    if "pending_question" in st.session_state:
        question = st.session_state.pop("pending_question")
        auto_investigate = True

    # Stage 1: Accept question, set processing state, rerun so controls render disabled
    if (form_submitted or auto_investigate) and question and question.strip():
        st.session_state._pending_agent_question = question
        st.session_state._processing = True
        st.session_state.agent_messages.append({"role": "user", "content": question})
        st.session_state._input_version += 1
        st.rerun()

    # Stage 2: Execute agent call (controls are already rendered disabled)
    if "_pending_agent_question" in st.session_state:
        pending_q = st.session_state.pop("_pending_agent_question")

        try:
            with st.spinner("Investigating..."):
                response = call_agent(
                    session, pending_q,
                    thread_id=st.session_state.agent_thread_id,
                    parent_message_id=st.session_state.agent_parent_msg_id,
                )

                # Capture thread state for multi-turn context
                tid, amid = get_thread_info(response)
                if tid is not None:
                    st.session_state.agent_thread_id = tid
                if amid is not None:
                    st.session_state.agent_parent_msg_id = amid

                text = extract_text_blocks(response)

                warnings = response.get("warnings", [])
                if warnings:
                    st.warning("The investigation completed with warnings. Results may be partial.")
        except Exception:
            st.session_state.pop("_processing", None)
            st.error("Investigation failed. Please try again.")
            st.stop()

        st.session_state.agent_messages.append({"role": "assistant", "content": text})
        safe_rerun()

    if st.session_state.agent_messages:
        if st.button("Clear conversation", disabled=_is_processing()):
            st.session_state.agent_messages = []
            st.session_state.agent_thread_id = None
            st.session_state.agent_parent_msg_id = None
            safe_rerun()


# =========================================================================
# VIEW 4: Decision Center
# =========================================================================

elif view == "Decision Center":
    st.title("Decision Center")
    st.caption("Governed recommendation approval and execution workflow")

    # Recover from an interrupted run: a blocking procedure call cut short by
    # navigation leaves _processing=True with no pending action to consume.
    if st.session_state.get("_processing") and "_pending_governance_action" not in st.session_state:
        st.session_state.pop("_processing", None)
    # A pending action is only valid alongside _processing (Stage 1 sets both).
    # If _processing was cleared elsewhere, the pending action is stale.
    if "_pending_governance_action" in st.session_state and not st.session_state.get("_processing"):
        st.session_state.pop("_pending_governance_action", None)

    # Status area for Stage 2 output, rendered above the tabs
    governance_status = st.container()

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
                    if st.button(f"Approve {rec_id}", key=f"btn_a_{rec_id}", type="primary", disabled=_is_processing()):
                        if not justification_approve.strip():
                            st.error("Justification required.")
                        else:
                            # Stage 1: queue the action and rerun so controls render disabled
                            st.session_state._pending_governance_action = {
                                "operation": "approve",
                                "entity_id": rec_id,
                                "justification": justification_approve,
                            }
                            st.session_state._processing = True
                            st.rerun()

                with col_reject:
                    justification_reject = st.text_input(
                        "Rejection justification", key=f"just_r_{rec_id}",
                        placeholder="Reason for rejection..."
                    )
                    if st.button(f"Reject {rec_id}", key=f"btn_r_{rec_id}", disabled=_is_processing()):
                        if not justification_reject.strip():
                            st.error("Justification required.")
                        else:
                            # Stage 1: queue the action and rerun so controls render disabled
                            st.session_state._pending_governance_action = {
                                "operation": "reject",
                                "entity_id": rec_id,
                                "justification": justification_reject,
                            }
                            st.session_state._processing = True
                            st.rerun()

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
                raw_actor = row["DECIDED_BY"]
                actor_display = format_actor(raw_actor)

                # Detect invalid/legacy actor attribution
                actor_valid = bool(
                    raw_actor
                    and isinstance(raw_actor, str)
                    and raw_actor.strip()
                    and raw_actor.strip() != "None"
                )

                st.markdown(f"**{rec_id}** (Approval: {approval_id}) \u2014 Approved by {actor_display}")
                st.caption(f"Approved at: {row['DECIDED_AT']}")

                if not actor_valid:
                    st.warning("This approval has no verified actor and cannot be executed.")
                else:
                    action_desc = st.text_input(
                        "Action description", key=f"act_desc_{approval_id}",
                        placeholder="Describe the action taken..."
                    )
                    action_type = st.text_input(
                        "Action type", key=f"act_type_{approval_id}",
                        value="Bearing inspection scheduled"
                    )

                    if st.button(f"Execute {approval_id}", key=f"btn_exec_{approval_id}", type="primary", disabled=_is_processing()):
                        if not action_desc.strip():
                            st.error("Action description required.")
                        else:
                            # Stage 1: queue the action and rerun so controls render disabled
                            st.session_state._pending_governance_action = {
                                "operation": "execute",
                                "entity_id": approval_id,
                                "rec_id": rec_id,
                                "action_type": action_type,
                                "action_desc": action_desc,
                            }
                            st.session_state._processing = True
                            st.rerun()

                st.divider()

    with tab_all:
        all_rec_df = run_query(ALL_RECOMMENDATIONS)
        if not all_rec_df.empty:
            all_display = humanize_enum_columns(all_rec_df, ["ACTION_TYPE", "PRIORITY", "STATUS"])
            st.dataframe(humanize_columns(all_display), use_container_width=True, hide_index=True)
        else:
            st.info("No recommendations.")

    # Stage 2: execute the queued governance action. Runs after all tabs have
    # rendered, so every action control is already displayed disabled.
    if "_pending_governance_action" in st.session_state:
        pending = st.session_state.pop("_pending_governance_action")
        operation = pending["operation"]

        with governance_status:
            if operation == "approve":
                rec_id = pending["entity_id"]
                try:
                    with st.spinner(f"Approving {rec_id}..."):
                        session.sql(
                            "CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION(?, ?, ?, ?)",
                            params=[rec_id, "approved", pending["justification"], _viewer_user]
                        ).collect()
                except Exception:
                    st.session_state.pop("_processing", None)
                    st.error("Unable to approve this recommendation. Please retry or contact the OpsMind administrator.")
                    st.stop()
                st.success(f"{rec_id} approved.")
                safe_rerun()

            elif operation == "reject":
                rec_id = pending["entity_id"]
                try:
                    with st.spinner(f"Rejecting {rec_id}..."):
                        session.sql(
                            "CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION(?, ?, ?, ?)",
                            params=[rec_id, "rejected", pending["justification"], _viewer_user]
                        ).collect()
                except Exception:
                    st.session_state.pop("_processing", None)
                    st.error("Unable to reject this recommendation. Please retry or contact the OpsMind administrator.")
                    st.stop()
                st.success(f"{rec_id} rejected.")
                safe_rerun()

            elif operation == "execute":
                approval_id = pending["entity_id"]
                try:
                    with st.spinner(f"Executing {approval_id}..."):
                        session.sql(
                            "CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION(?, ?, ?, ?)",
                            params=[approval_id, pending["action_type"], pending["action_desc"], _viewer_user]
                        ).collect()
                except Exception:
                    st.session_state.pop("_processing", None)
                    st.error("Unable to execute this approved action. Please retry or contact the OpsMind administrator.")
                    st.stop()
                st.success(f"Action executed for {pending['rec_id']}.")
                safe_rerun()

            else:
                st.session_state.pop("_processing", None)


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
            audit_df = format_actor_column(audit_df, "ACTOR")
            audit_display = humanize_enum_columns(audit_df, ["EVENT_TYPE", "ENTITY_TYPE"])
            st.dataframe(humanize_columns(audit_display), use_container_width=True, hide_index=True)
        else:
            st.info("No audit entries.")

    with tab_approvals:
        approvals_df = run_query(APPROVAL_DECISIONS_RECENT)
        if not approvals_df.empty:
            approvals_df = format_actor_column(approvals_df, "DECIDED_BY")
            approvals_display = humanize_enum_columns(approvals_df, ["DECISION"])
            st.dataframe(humanize_columns(approvals_display), use_container_width=True, hide_index=True)
        else:
            st.info("No approval decisions recorded.")

    with tab_actions:
        actions_df = run_query(EXECUTED_ACTIONS_RECENT)
        if not actions_df.empty:
            actions_df = format_actor_column(actions_df, "EXECUTED_BY")
            st.dataframe(humanize_columns(actions_df), use_container_width=True, hide_index=True)
        else:
            st.info("No executed actions recorded.")


# -- Footer ----------------------------------------------------------------
st.sidebar.divider()
st.sidebar.caption("OpsMind AI v1.0")
st.sidebar.caption("Powered by Snowflake Cortex")
