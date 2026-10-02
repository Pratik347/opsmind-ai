"""OpsMind AI — UI components for the Streamlit Command Center."""

import streamlit as st
import pandas as pd


def render_risk_badge(risk_band: str) -> str:
    """Return a colored risk badge as markdown."""
    colors = {
        "CRITICAL": "🔴",
        "HIGH": "🟠",
        "MEDIUM": "🟡",
        "LOW": "🟢",
        "INCOMPLETE": "⚪",
    }
    icon = colors.get(risk_band, "⚪")
    return f"{icon} **{risk_band}**"


def render_kpi_row(metrics: list[tuple[str, str, str]]):
    """Render a row of KPI cards. Each tuple: (label, value, delta)."""
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
    counts = {}
    for _, row in risk_df.iterrows():
        counts[row["RISK_BAND"]] = int(row["MACHINE_COUNT"])

    metrics = []
    for band in band_order:
        count = counts.get(band, 0)
        if count > 0 or band in ("CRITICAL", "HIGH", "LOW"):
            icon = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢", "INCOMPLETE": "⚪"}.get(band, "")
            metrics.append((f"{icon} {band}", str(count), None))

    if metrics:
        render_kpi_row(metrics)


def render_recommendation_card(rec: dict):
    """Render a single recommendation as an expander."""
    priority_icon = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}.get(rec.get("PRIORITY", ""), "")
    title = f"{priority_icon} {rec.get('RECOMMENDATION_ID', '')} — {rec.get('MACHINE_ID', '')} — {rec.get('ACTION_TYPE', '')}"

    with st.expander(title, expanded=rec.get("PRIORITY") == "critical"):
        st.markdown(f"**Description:** {rec.get('DESCRIPTION', '')}")
        st.markdown(f"**Rationale:** {rec.get('RATIONALE', '')}")
        st.markdown(f"**Evidence:** {rec.get('EVIDENCE_SUMMARY', '')}")

        c1, c2 = st.columns(2)
        with c1:
            st.metric("Est. Cost", f"${rec.get('ESTIMATED_COST_USD', 0):,.0f}")
        with c2:
            st.metric("Est. Downtime", f"{rec.get('ESTIMATED_DOWNTIME_HRS', 0)}h")

        if rec.get("RISK_IF_DEFERRED"):
            st.warning(f"**Risk if deferred:** {rec['RISK_IF_DEFERRED']}")


def render_oee_chart(oee_df: pd.DataFrame):
    """Render an OEE trend line chart."""
    if oee_df.empty:
        st.info("No OEE data available.")
        return
    chart_df = oee_df[["METRIC_DATE", "OEE_PCT", "AVAILABILITY_PCT", "PERFORMANCE_PCT", "QUALITY_PCT"]].copy()
    chart_df = chart_df.set_index("METRIC_DATE")
    st.line_chart(chart_df)


def render_sensor_chart(sensor_df: pd.DataFrame, sensor_type: str):
    """Render a sensor trend chart for a specific type."""
    filtered = sensor_df[sensor_df["SENSOR_TYPE"] == sensor_type].copy()
    if filtered.empty:
        st.info(f"No {sensor_type} data available.")
        return
    chart_data = filtered[["READING_TS", "VALUE"]].set_index("READING_TS")
    st.line_chart(chart_data)
