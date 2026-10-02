---
name: operations-investigation
description: "Investigate equipment degradation using the OpsMind AI intelligence stack. Triggers: investigate machine, equipment investigation, degradation analysis, risk investigation, bearing inspection, vibration analysis, OEE investigation, failure risk, what's wrong with machine"
---

# Operations Investigation

Repeatable workflow for investigating equipment health using the OpsMind Snowflake intelligence stack: FAILURE_RISK_SCORES, Semantic View, Cortex Agent, Cortex Search, and IMPACT_SCENARIOS.

## Prerequisites

- Connection to the OPSMIND Snowflake database
- OPSMIND_STREAMLIT or OPSMIND_ANALYST role (or higher)
- OPSMIND.APP.OPSMIND_AGENT deployed and accessible

## Workflow

### Step 1: Identify Investigation Target

If the user specified a machine, use it. Otherwise, identify elevated-risk equipment:

```sql
SELECT MACHINE_ID, MACHINE_NAME, MACHINE_TYPE, RISK_SCORE, RISK_BAND,
       DATA_QUALITY, VIBRATION_LEVEL_SCORE, VIBRATION_TREND_SCORE,
       THERMAL_DEVIATION_SCORE, OEE_DEGRADATION_SCORE, MAINTENANCE_OVERDUE_SCORE
FROM OPSMIND.AI.FAILURE_RISK_SCORES
ORDER BY RISK_SCORE DESC NULLS LAST
```

Present the fleet risk summary. If no machine was specified, ask which machine to investigate, highlighting any with HIGH or CRITICAL risk bands.

### Step 2: Risk Index Assessment

For the target machine, retrieve and present the failure risk index:

```sql
SELECT * FROM OPSMIND.AI.FAILURE_RISK_SCORES
WHERE MACHINE_ID = ?  -- bind the target machine ID
```

Present:
- **Risk score** and **risk band** — always describe as "Equipment Failure Risk Index" or "condition-based risk score"
- **Individual feature scores** with their weights (F1: Vibration Level 30%, F2: Vibration Trend 20%, F3: Thermal Deviation 20%, F4: OEE Degradation 15%, F5: Maintenance Overdue 15%)
- **DATA_QUALITY** — if PARTIAL or INSUFFICIENT, state the score has reduced confidence
- **AS_OF_DATE** and **LOOKBACK_WINDOW_DAYS** (7-day trailing window)

**Terminology rules:**
- This is a RISK INDEX (0–100), NOT a probability, likelihood, or time-to-failure estimate
- It answers "How strongly does current operating evidence indicate elevated failure risk?"
- Feature weights and composite bands are expert-defined operational heuristics, not statistically calibrated
- Never describe it as "predicted failure", "remaining useful life", or "calibrated probability"

### Step 3: Telemetry Evidence

Use the Cortex Agent for structured telemetry investigation:

```sql
SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'OPSMIND.APP.OPSMIND_AGENT',
        '<request_json>',
        TRUE
    )
) AS resp
```

Or query directly via the semantic view for specific data:
- Vibration trends (sensor_type = 'vibration')
- Bearing temperature trends (sensor_type = 'bearing_temp')
- OEE trends over the lookback window

Compare against peer machines on the same line or of the same type.

### Step 4: Maintenance and Failure History

Query maintenance records for the target machine — look for overdue tasks, missed intervals, patterns of repeated issues:

```sql
SELECT TASK_ID, TASK_TYPE, STATUS, SCHEDULED_DATE, COMPLETED_DATE, DESCRIPTION
FROM OPSMIND.CORE.MAINTENANCE_HISTORY
WHERE MACHINE_ID = ?
ORDER BY SCHEDULED_DATE DESC
```

Query failure history for the same or similar equipment types to establish precedent.

### Step 5: Operational Knowledge

Use Cortex Search (via the Agent's KnowledgeSearch tool) to retrieve applicable SOPs, vibration thresholds (DOC-002), inspection procedures, and troubleshooting guidance. Cite document titles when available.

### Step 6: Business Impact Assessment

If the investigation reveals elevated risk, retrieve governed impact scenarios:

```sql
SELECT FAILURE_COMPONENT, ASSUMPTION_SOURCE, ASSUMPTION_BASIS,
       ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD,
       ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD,
       ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD,
       ESTIMATED_AVOIDED_DOWNTIME_HRS
FROM OPSMIND.AI.IMPACT_SCENARIOS
WHERE MACHINE_ID = ?
```

**Terminology rules for impact:**
- Always present ASSUMPTION_SOURCE and ASSUMPTION_BASIS
- Use "estimated" and "potential avoided impact" — never "guaranteed savings" or "predictions"
- Production loss uses line design capacity as proxy, not realized revenue

### Step 7: Investigation Summary

Structure the output as:

**OBSERVATIONS** — Facts from structured data with source identification
**RISK ASSESSMENT** — Risk index, band, contributing factors, data quality
**KNOWLEDGE** — Relevant SOPs, thresholds, guidance with document citations
**HYPOTHESIS** — Reasoning from correlating observations with knowledge; state which evidence converges and which does not
**BUSINESS IMPACT** — Governed cost comparison (planned vs unplanned) with assumption provenance
**RECOMMENDED ACTION** — Concrete next steps prioritized by urgency
**CONFIDENCE** — LOW/MEDIUM/HIGH justified by evidence convergence; no invented probabilities

If the machine is healthy (LOW risk, normal telemetry), report that clearly rather than inventing problems.

## Stopping Points

- After Step 1 if no target machine specified (ask user)
- After Step 7 to present findings

## Output

An evidence-grounded investigation summary following the structure above, with all risk terminology, impact disclaimers, and data quality caveats correctly applied.
