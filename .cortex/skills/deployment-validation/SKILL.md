---
name: deployment-validation
description: "Validate that the OpsMind AI deployment is operational. Triggers: validate deployment, check deployment, deployment health, smoke test, is OpsMind working, verify deployment, post-deployment check"
---

# Deployment Validation

Validates the OpsMind AI Snowflake deployment is operational after changes. Read-only — never mutates production data or demo history.

## Prerequisites

- ACCOUNTADMIN or OPSMIND_ADMIN role for object-existence checks
- Connection to the OPSMIND Snowflake database

## Workflow

### Step 1: Core Object Existence

Verify all required Snowflake objects exist:

```sql
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;

-- Database and schemas
SHOW SCHEMAS IN DATABASE OPSMIND;
-- Expect: RAW, CORE, KNOWLEDGE, AI, GOVERNANCE, APP

-- Core data tables
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM OPSMIND.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_SCHEMA IN ('RAW','CORE','KNOWLEDGE','AI','GOVERNANCE')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Views
SHOW VIEWS IN SCHEMA OPSMIND.AI;
-- Expect: FAILURE_RISK_SCORES, IMPACT_SCENARIOS
```

Report any missing objects.

### Step 2: Streamlit Deployment

```sql
SHOW STREAMLITS LIKE 'OPSMIND_COMMAND_CENTER' IN SCHEMA OPSMIND.APP;
```

Verify:
- **owner** = `OPSMIND_STREAMLIT` (NOT ACCOUNTADMIN — owner-rights execution model)
- **query_warehouse** = `OPSMIND_WH`
- Object exists and is accessible

If owner is not OPSMIND_STREAMLIT, flag as FAIL — the Streamlit runs with owner's rights, so ACCOUNTADMIN ownership is a security violation.

### Step 3: Semantic View

```sql
DESCRIBE VIEW OPSMIND.APP.OPSMIND_OPERATIONS;
```

Verify the semantic view exists and is accessible.

### Step 4: Cortex Search

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA OPSMIND.APP;
-- Expect: OPS_KNOWLEDGE_SEARCH
```

### Step 5: Cortex Agent

```sql
DESCRIBE AGENT OPSMIND.APP.OPSMIND_AGENT;
```

Verify the agent exists and references the correct semantic view and search service.

### Step 6: Warehouse and Runtime

```sql
SHOW WAREHOUSES LIKE 'OPSMIND_WH';
```

Verify OPSMIND_WH exists and is accessible.

### Step 7: Read-Only Smoke Tests

Run representative queries to verify data accessibility (all read-only):

```sql
-- Fleet risk summary
SELECT RISK_BAND, COUNT(*) AS CNT FROM OPSMIND.AI.FAILURE_RISK_SCORES GROUP BY RISK_BAND;

-- OEE data exists
SELECT COUNT(*) AS OEE_ROWS FROM OPSMIND.CORE.OEE_METRICS;

-- Sensor data exists
SELECT COUNT(*) AS SENSOR_ROWS FROM OPSMIND.CORE.SENSOR_READINGS;

-- Recommendations exist
SELECT COUNT(*) AS REC_ROWS FROM OPSMIND.AI.RECOMMENDATIONS;

-- Governance tables populated
SELECT COUNT(*) AS AUDIT_ROWS FROM OPSMIND.GOVERNANCE.AUDIT_LOG;
```

### Step 8: Phase 4A Impact Regression

```sql
SELECT COUNT(*) AS SCENARIO_COUNT FROM OPSMIND.AI.IMPACT_SCENARIOS;
-- Expect > 0 (each machine × component combination)

SELECT MACHINE_ID, FAILURE_COMPONENT,
       ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD,
       ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD
FROM OPSMIND.AI.IMPACT_SCENARIOS
LIMIT 3;
```

### Step 9: Phase 4C Risk Regression

```sql
SELECT MACHINE_ID, RISK_SCORE, RISK_BAND, DATA_QUALITY
FROM OPSMIND.AI.FAILURE_RISK_SCORES
WHERE RISK_BAND IN ('HIGH', 'CRITICAL')
ORDER BY RISK_SCORE DESC;
-- Expect at least M-302 with HIGH risk

-- Healthy machine generalization: verify LOW-risk machines exist
SELECT COUNT(*) AS LOW_RISK_COUNT
FROM OPSMIND.AI.FAILURE_RISK_SCORES
WHERE RISK_BAND = 'LOW';
-- Expect >= 9 (most of the fleet should be healthy)
```

### Step 10: Git Status

```bash
git status
git log -3 --oneline
```

Report current branch, latest commit, and any uncommitted changes.

## Output

A deployment health report:

| Check | Status | Detail |
|-------|--------|--------|
| Core objects | PASS/FAIL | ... |
| Streamlit (owner=OPSMIND_STREAMLIT) | PASS/FAIL | ... |
| Semantic View | PASS/FAIL | ... |
| Cortex Search | PASS/FAIL | ... |
| Cortex Agent | PASS/FAIL | ... |
| Warehouse | PASS/FAIL | ... |
| Smoke tests | PASS/FAIL | ... |
| Phase 4A regression | PASS/FAIL | ... |
| Phase 4C regression | PASS/FAIL | ... |
| Git status | CLEAN/DIRTY | ... |

## Notes

- This skill is read-only — it never performs DELETE, TRUNCATE, UPDATE, or INSERT
- Do not create test fixtures or demo data as part of validation
- If any check fails, report the failure clearly but do not attempt automated remediation
