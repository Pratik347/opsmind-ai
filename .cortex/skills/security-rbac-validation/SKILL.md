---
name: security-rbac-validation
description: "Validate OpsMind AI least-privilege RBAC and security boundaries. Triggers: security validation, RBAC check, privilege audit, security scan, least privilege, verify permissions, access control test"
---

# Security & RBAC Validation

Repeatable least-privilege validation for OpsMind AI. Tests both positive access (required privileges work) and negative access (unauthorized operations are denied), plus source-level security scans.

## Prerequisites

- ACCOUNTADMIN role (for grant inspection)
- OPSMIND_STREAMLIT role exists
- Connection to the OPSMIND Snowflake database

## Workflow

### Step 1: Role Context Setup

Every authorization test MUST begin with explicit role isolation:

```sql
USE ROLE OPSMIND_STREAMLIT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OPSMIND_WH;
SELECT CURRENT_ROLE() AS ACTIVE_ROLE;
-- MUST return OPSMIND_STREAMLIT before any assertion
```

If CURRENT_ROLE() does not return OPSMIND_STREAMLIT, STOP — the test environment is misconfigured.

### Step 2: Positive Access Tests

All of these MUST succeed under OPSMIND_STREAMLIT with SECONDARY ROLES NONE:

```sql
-- CORE reads
SELECT COUNT(*) FROM OPSMIND.CORE.MACHINES;
SELECT COUNT(*) FROM OPSMIND.CORE.SENSOR_READINGS;
SELECT COUNT(*) FROM OPSMIND.CORE.OEE_METRICS;
SELECT COUNT(*) FROM OPSMIND.CORE.MAINTENANCE_HISTORY;

-- AI analytical outputs
SELECT COUNT(*) FROM OPSMIND.AI.FAILURE_RISK_SCORES;
SELECT COUNT(*) FROM OPSMIND.AI.IMPACT_SCENARIOS;
SELECT COUNT(*) FROM OPSMIND.AI.RECOMMENDATIONS;
SELECT COUNT(*) FROM OPSMIND.CORE.ANOMALY_SIGNALS;

-- GOVERNANCE reads
SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.AUDIT_LOG;
SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS;
SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.EXECUTED_ACTIONS;

-- Cortex Agent invocation
SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'OPSMIND.APP.OPSMIND_AGENT',
        '{"messages":[{"role":"user","content":[{"type":"text","text":"How many machines are there?"}]}]}',
        TRUE
    )
):role::VARCHAR AS AGENT_ROLE;
-- Expect: 'assistant'
```

### Step 3: Governed Procedure Access

Test that OPSMIND_STREAMLIT can call the EXECUTE AS OWNER governance procedures. Use an existing pending recommendation if available, or just verify USAGE is granted:

```sql
-- Verify procedure USAGE grants exist (inherited from OPSMIND_OPERATOR)
SHOW GRANTS TO ROLE OPSMIND_OPERATOR;
-- Look for USAGE on APPROVE_RECOMMENDATION and EXECUTE_APPROVED_ACTION
```

### Step 4: Negative Access Tests — Governed Configuration

All of these MUST fail with access denied under OPSMIND_STREAMLIT + SECONDARY ROLES NONE:

```sql
-- Governed config tables must be inaccessible
SELECT * FROM OPSMIND.AI.IMPACT_ASSUMPTIONS LIMIT 1;
-- Expect: not authorized

SELECT * FROM OPSMIND.AI.MACHINE_RISK_THRESHOLDS LIMIT 1;
-- Expect: not authorized
```

### Step 5: Negative Access Tests — Direct DML

All of these MUST fail with access denied:

```sql
-- Direct INSERT into governance tables
INSERT INTO OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    (APPROVAL_ID, RECOMMENDATION_ID, DECISION_AT, DECIDED_BY, DECISION, COMMENTS)
VALUES ('HACK-1', 'REC-001', CURRENT_TIMESTAMP(), 'attacker', 'approved', 'bypass');
-- Expect: Insufficient privileges INSERT

INSERT INTO OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
    (ACTION_ID, APPROVAL_ID, EXECUTED_AT, ACTION_TYPE, DESCRIPTION, EXECUTED_BY, RESULT)
VALUES ('HACK-1', 'APR-001', CURRENT_TIMESTAMP(), 'hack', 'bypass', 'attacker', 'pwned');
-- Expect: Insufficient privileges INSERT

INSERT INTO OPSMIND.GOVERNANCE.AUDIT_LOG
    (AUDIT_ID, EVENT_TYPE, ENTITY_TYPE, ENTITY_ID, ACTOR, EVENT_TS, DETAILS)
VALUES ('HACK-1', 'hack', 'hack', 'hack', 'attacker', CURRENT_TIMESTAMP(), 'bypass');
-- Expect: Insufficient privileges INSERT

-- Direct UPDATE/DELETE on recommendations
UPDATE OPSMIND.AI.RECOMMENDATIONS SET STATUS = 'hacked' WHERE RECOMMENDATION_ID = 'REC-001';
-- Expect: Insufficient privileges UPDATE

DELETE FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID = 'REC-001';
-- Expect: Insufficient privileges DELETE

-- Destructive operations
DELETE FROM OPSMIND.GOVERNANCE.AUDIT_LOG WHERE AUDIT_ID = 'AUD-001';
-- Expect: Insufficient privileges DELETE

TRUNCATE TABLE OPSMIND.GOVERNANCE.AUDIT_LOG;
-- Expect: Insufficient privileges TRUNCATE
```

### Step 6: Grant Surface Verification

```sql
USE ROLE ACCOUNTADMIN;

-- Direct grants to OPSMIND_STREAMLIT
SHOW GRANTS TO ROLE OPSMIND_STREAMLIT;

-- Verify: CORTEX_AGENT_USER (narrow), NOT CORTEX_USER (broad)
-- Verify: no FUTURE TABLE grants on AI or GOVERNANCE
-- Verify: no CREATE privileges (except those temporarily granted and revoked during deployment)
-- Verify: no ALL grants on any schema
```

### Step 7: Source-Level Security Scans

Run these scans against the `streamlit/` directory:

**Secrets scan:**
```
grep -r "password|secret|token|api_key|credential" streamlit/
```
Expect: zero matches.

**Direct DML scan:**
```
grep -r "INSERT INTO|UPDATE |DELETE FROM|TRUNCATE" streamlit/
```
Expect: zero matches (all mutations go through CALL to procedures).

**Governed config reference scan:**
```
grep -r "IMPACT_ASSUMPTIONS|MACHINE_RISK_THRESHOLDS" streamlit/
```
Expect: zero matches.

**Unsupported predictive claim scan:**
```
grep -ri "probability|likelihood|time.to.failure|RUL|remaining useful|calibrat" streamlit/
```
Expect: zero matches or only negative disclaimers ("not predictions").

**Thinking/chain-of-thought rendering scan:**
```
grep -r "thinking|chain.of.thought" streamlit/
```
Expect: only the silencing logic in agent.py (skip thinking blocks), never rendering them.

## Output

A security validation report:

| Category | Test | Result |
|----------|------|--------|
| **Positive** | CORE reads | PASS/FAIL |
| **Positive** | FAILURE_RISK_SCORES | PASS/FAIL |
| **Positive** | IMPACT_SCENARIOS | PASS/FAIL |
| **Positive** | RECOMMENDATIONS | PASS/FAIL |
| **Positive** | Governance history reads | PASS/FAIL |
| **Positive** | Agent invocation | PASS/FAIL |
| **Positive** | Procedure USAGE | PASS/FAIL |
| **Negative** | IMPACT_ASSUMPTIONS blocked | PASS/FAIL |
| **Negative** | MACHINE_RISK_THRESHOLDS blocked | PASS/FAIL |
| **Negative** | Direct governance INSERT blocked | PASS/FAIL |
| **Negative** | Recommendations UPDATE blocked | PASS/FAIL |
| **Negative** | Recommendations DELETE blocked | PASS/FAIL |
| **Negative** | Audit log DELETE blocked | PASS/FAIL |
| **Negative** | Audit log TRUNCATE blocked | PASS/FAIL |
| **Grants** | CORTEX_AGENT_USER (not CORTEX_USER) | PASS/FAIL |
| **Grants** | No FUTURE/ALL grants | PASS/FAIL |
| **Source** | Secrets scan | PASS/FAIL |
| **Source** | Direct DML scan | PASS/FAIL |
| **Source** | Governed config scan | PASS/FAIL |
| **Source** | Predictive claim scan | PASS/FAIL |
| **Source** | Thinking rendering scan | PASS/FAIL |

## Notes

- This skill is read-only except for the DML tests that are expected to FAIL
- The negative DML tests attempt writes that MUST be denied — they verify the boundary, not bypass it
- Always use `USE SECONDARY ROLES NONE` — without it, secondary roles may leak ACCOUNTADMIN privileges and mask real access control gaps
