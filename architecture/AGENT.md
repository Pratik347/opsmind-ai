# OpsMind AI — Cortex Agent Architecture

## Overview

`OPSMIND.APP.OPSMIND_AGENT` is the core investigation agent. It combines structured operational evidence from Cortex Analyst with operational knowledge from Cortex Search to perform evidence-grounded equipment investigations.

```
User Question
    |
    v
OPSMIND_AGENT (orchestration)
    |
    +---> OperationsAnalyst (Cortex Analyst)
    |         |
    |         v
    |     OPSMIND.APP.OPSMIND_OPERATIONS (Semantic View)
    |         |
    |         v
    |     CORE tables: sensors, OEE, maintenance, failures, work orders
    |
    +---> KnowledgeSearch (Cortex Search)
              |
              v
          OPSMIND.APP.OPS_KNOWLEDGE_SEARCH
              |
              v
          KNOWLEDGE.OPERATIONAL_DOCUMENTS (SOPs, thresholds, guides)
```

## Tools

| Tool | Type | Purpose | Source |
|------|------|---------|--------|
| OperationsAnalyst | cortex_analyst_text_to_sql | Structured data queries | OPSMIND.APP.OPSMIND_OPERATIONS |
| KnowledgeSearch | cortex_search | Knowledge document retrieval | OPSMIND.APP.OPS_KNOWLEDGE_SEARCH |

## Investigation Workflow

For equipment investigations, the agent follows this sequence:

1. Identify equipment and gather telemetry (vibration, temperature)
2. Examine OEE and operational performance trends
3. Check maintenance history for overdue or missed tasks
4. Check failure history for similar equipment
5. Compare against peer machines
6. Retrieve applicable SOPs and thresholds
7. Correlate structured evidence with operational knowledge
8. Assess business impact
9. Recommend next actions

## Evidence Contract

Every investigation response contains:

| Section | Content |
|---------|---------|
| **OBSERVATIONS** | Facts from structured data with source identification |
| **KNOWLEDGE** | Retrieved procedures and thresholds with document citations |
| **HYPOTHESIS** | Reasoning from correlating observations with knowledge |
| **BUSINESS / OPERATIONAL IMPACT** | Evidence-supported consequences |
| **RECOMMENDED ACTION** | Prioritized next steps |
| **CONFIDENCE** | LOW / MEDIUM / HIGH with justification |

## Grounding Strategy

- Structured evidence cites data sources (SENSOR_READINGS, OEE_METRICS, etc.)
- Knowledge evidence cites document titles (e.g., "Vibration Analysis and Threshold Guidelines")
- The agent does not fabricate citations or data
- When evidence is insufficient, the agent says so explicitly

## Security Boundaries

The agent has NO access to:
- GOVERNANCE tables (APPROVAL_DECISIONS, EXECUTED_ACTIONS, AUDIT_LOG)
- AI.RECOMMENDATIONS (pre-generated conclusions)
- Test contracts (m302_expected.json)
- Demo scenario documentation (used only for development)

## Validation Results

### Tool Routing

| Test | Tools Used | Result |
|------|-----------|--------|
| OEE trend for M-302 (structured-only) | OperationsAnalyst | PASS |
| CNC vibration threshold (knowledge-only) | KnowledgeSearch | PASS |

### Investigation

| Test | Tools Used | Result |
|------|-----------|--------|
| Open-ended degradation investigation | Both | PASS - identified M-302 from data |
| CNC milling fleet review (different wording) | Both | PASS - identified M-302, confirmed 4 others healthy |

### Generalization

| Test | Tools Used | Result |
|------|-----------|--------|
| Healthy machine investigation (M-301) | Both | PASS - correctly reported healthy |
| Cross-line OEE/downtime comparison | OperationsAnalyst | PASS - ranked all 5 lines, identified LINE-301 underperforming |

### Hallucination / Failure Safety

| Test | Tools Used | Result |
|------|-----------|--------|
| Nonexistent machine (M-999) | OperationsAnalyst | PASS - refused to fabricate, suggested valid IDs |
| Missing data type (oil analysis for M-201) | None (agent recognized gap) | PASS - stated oil analysis not in data model |
| Missing knowledge (hydraulic press bolt torque) | KnowledgeSearch | PASS - searched 3 docs, stated not available, refused to fabricate |

## Known Limitations

1. Conversation context requires thread_id for multi-turn (REST API or Snowsight); DATA_AGENT_RUN is single-turn
2. Agent budget (120s, 32K tokens) may limit very complex investigations
3. No approval/action execution workflow yet (future phase)
4. No chart rendering in DATA_AGENT_RUN responses (charts work in Snowsight/CoWork)

## Deployment

```sql
-- setup/sql/09_agent.sql
CREATE OR REPLACE AGENT OPSMIND.APP.OPSMIND_AGENT
  FROM SPECIFICATION $$...$$;
```

Reference specification: `agent/opsmind_agent.yaml`
