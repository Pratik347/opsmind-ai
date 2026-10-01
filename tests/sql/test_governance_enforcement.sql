-- ============================================================
-- OpsMind AI — test_governance_enforcement.sql
-- Phase 4B: Comprehensive test suite for the approval/execution
-- state machine, RBAC isolation, idempotency, and rollback.
--
-- Prerequisites: scripts 00–11 deployed, seed data loaded.
-- Execution: run each section as ACCOUNTADMIN (or the role
-- specified in the test) using OPSMIND_WH.
--
-- Test fixture recommendations REC-T01..REC-T07 are created
-- by the test setup block. Clean up with the teardown block.
-- ============================================================

-- ============================================================
-- SETUP: Create test fixture recommendations
-- ============================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

INSERT INTO OPSMIND.AI.RECOMMENDATIONS (
    RECOMMENDATION_ID, ANOMALY_ID, MACHINE_ID, GENERATED_AT,
    ACTION_TYPE, PRIORITY, DESCRIPTION, RATIONALE, EVIDENCE_SUMMARY,
    ESTIMATED_COST_USD, ESTIMATED_DOWNTIME_HRS, RISK_IF_DEFERRED, STATUS
) VALUES
('REC-T01', 'ANM-003', 'M-302', '2026-09-26 09:00:00', 'inspect', 'high', 'Test: approve happy path', 'test', 'test', 100, 1, 'test', 'pending'),
('REC-T02', 'ANM-003', 'M-302', '2026-09-26 09:01:00', 'inspect', 'high', 'Test: reject happy path', 'test', 'test', 100, 1, 'test', 'pending'),
('REC-T03', 'ANM-003', 'M-302', '2026-09-26 09:02:00', 'inspect', 'high', 'Test: double-approve guard', 'test', 'test', 100, 1, 'test', 'pending'),
('REC-T04', 'ANM-003', 'M-302', '2026-09-26 09:03:00', 'inspect', 'high', 'Test: reject-then-execute', 'test', 'test', 100, 1, 'test', 'pending'),
('REC-T05', 'ANM-003', 'M-302', '2026-09-26 09:04:00', 'inspect', 'high', 'Test: full chain approve-execute', 'test', 'test', 100, 1, 'test', 'pending'),
('REC-T06', 'ANM-003', 'M-302', '2026-09-26 09:05:00', 'inspect', 'high', 'Test: double-execute guard', 'test', 'test', 100, 1, 'test', 'pending'),
('REC-T07', 'ANM-003', 'M-302', '2026-09-26 09:06:00', 'inspect', 'high', 'Test: rollback / no-state-change', 'test', 'test', 100, 1, 'test', 'pending');

-- ============================================================
-- POSITIVE TESTS (happy path)
-- ============================================================

-- TEST P1: Approve a pending recommendation
-- Expected: Returns APR-NNN, STATUS → 'approved', 2 audit entries
USE ROLE OPSMIND_OPERATOR;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OPSMIND_WH;
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T01', 'approved', 'Test approval');
-- Verify:
SELECT STATUS FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID = 'REC-T01';
-- Expected: approved

-- TEST P2: Reject a pending recommendation
-- Expected: Returns APR-NNN, STATUS → 'rejected', 2 audit entries
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T02', 'rejected', 'Test rejection');
SELECT STATUS FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID = 'REC-T02';
-- Expected: rejected

-- TEST P3: Full chain — approve → execute
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T05', 'approved', 'Full chain test');
-- Save the APR-NNN returned, then:
-- CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION('<returned APR-NNN>', 'work_order_created', 'Full chain WO', 'WO-TEST');
SELECT STATUS FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID = 'REC-T05';
-- Expected: approved (then executed after EXECUTE_APPROVED_ACTION)

-- TEST P4: Verify audit trail completeness for full chain
-- After P3 approve + execute, verify 4 audit entries for REC-T05:
--   recommendation approved, approval_decision created,
--   executed_action executed, recommendation executed
SELECT AUDIT_ID, ENTITY_TYPE, ENTITY_ID, EVENT_TYPE
FROM OPSMIND.GOVERNANCE.AUDIT_LOG
WHERE ENTITY_ID IN ('REC-T05')
   OR ENTITY_ID IN (SELECT APPROVAL_ID FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS WHERE RECOMMENDATION_ID = 'REC-T05')
   OR ENTITY_ID IN (SELECT ACTION_ID FROM OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
                     WHERE APPROVAL_ID IN (SELECT APPROVAL_ID FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS WHERE RECOMMENDATION_ID = 'REC-T05'))
ORDER BY EVENT_TS;

-- ============================================================
-- NEGATIVE TESTS (invariant enforcement)
-- ============================================================

-- TEST N1: Double-approve (same recommendation, already approved)
-- Expected: ERROR containing 'is not pending'
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T01', 'approved', 'Double approve');

-- TEST N2: Invalid decision value
-- Expected: ERROR containing 'Invalid decision value'
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T03', 'maybe', 'Invalid decision');

-- TEST N3: Nonexistent recommendation
-- Expected: ERROR containing 'not found'
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-NONEXISTENT', 'approved', 'Ghost rec');

-- TEST N4: Execute rejected recommendation
-- Expected: ERROR containing 'not approved'
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T04', 'rejected', 'Reject for test');
-- Then attempt execution:
-- CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION('<APR for REC-T04>', 'inspect', 'Execute rejected');
-- Expected: ERROR containing 'not approved'

-- TEST N5: Execute nonexistent approval
-- Expected: ERROR containing 'not found'
CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION('APR-NONEXISTENT', 'inspect', 'Ghost approval');

-- TEST N6: Double-execute same approval
-- (After executing REC-T05 in P3, attempt again)
-- Expected: ERROR containing 'already been executed'

-- ============================================================
-- IDEMPOTENCY / CONCURRENCY TESTS
-- ============================================================

-- TEST I1: Approve REC-T06, then attempt second approve
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T06', 'approved', 'First');
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T06', 'rejected', 'Second');
-- Expected: First returns APR-NNN. Second returns ERROR.

-- TEST I2: Execute REC-T06, then attempt double-execute
-- CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION('<APR for REC-T06>', 'inspect', 'First');
-- CALL OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION('<APR for REC-T06>', 'inspect', 'Second');
-- Expected: First returns ACT-NNN. Second returns ERROR.

-- ============================================================
-- ROLLBACK / FAILURE-PATH TESTS
-- ============================================================

-- TEST R1: Validation failure leaves no state change
-- Count rows before a failed call, then verify identical after.
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
SELECT
  (SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS) AS approvals_before,
  (SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.AUDIT_LOG) AS audit_before,
  (SELECT STATUS FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID = 'REC-T07') AS status_before;

USE ROLE OPSMIND_OPERATOR;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OPSMIND_WH;
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T07', 'maybe', 'Invalid decision');
-- Expected: ERROR return, no state change

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
SELECT
  (SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS) AS approvals_after,
  (SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.AUDIT_LOG) AS audit_after,
  (SELECT STATUS FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID = 'REC-T07') AS status_after;
-- Expected: all values identical to _before

-- TEST R2: CHECK constraint prevents invalid status via direct SQL
USE ROLE ACCOUNTADMIN;
UPDATE OPSMIND.AI.RECOMMENDATIONS SET STATUS = 'INVALID' WHERE RECOMMENDATION_ID = 'REC-T07';
-- Expected: CHECK constraint violation error

-- TEST R3: CHECK constraint prevents invalid decision via direct SQL
INSERT INTO OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
VALUES ('APR-CHK', 'REC-T07', CURRENT_TIMESTAMP(), 'tester', 'maybe', 'invalid');
-- Expected: CHECK constraint violation error

-- ============================================================
-- RBAC ABUSE-CASE TESTS
-- All tests use USE SECONDARY ROLES NONE to verify effective
-- access of the active role only, without inherited privileges
-- from secondary roles.
-- ============================================================

-- TEST A1: ANALYST cannot access GOVERNANCE schema
USE ROLE OPSMIND_ANALYST;
USE SECONDARY ROLES NONE;
SELECT CURRENT_ROLE();  -- Verify: OPSMIND_ANALYST
SELECT * FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS LIMIT 1;
-- Expected: Schema does not exist or not authorized

-- TEST A2: ANALYST cannot read AI.RECOMMENDATIONS
SELECT * FROM OPSMIND.AI.RECOMMENDATIONS LIMIT 1;
-- Expected: Object does not exist or not authorized

-- TEST A3: ANALYST cannot read AI.IMPACT_ASSUMPTIONS
SELECT * FROM OPSMIND.AI.IMPACT_ASSUMPTIONS LIMIT 1;
-- Expected: Object does not exist or not authorized

-- TEST A4: ANALYST cannot call governance procedures
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T07', 'approved', 'Analyst abuse');
-- Expected: Unknown user-defined function

-- TEST A5: ANALYST can read CORE, KNOWLEDGE, AI.ANOMALY_SIGNALS, AI.IMPACT_SCENARIOS
USE WAREHOUSE OPSMIND_WH;
SELECT COUNT(*) FROM OPSMIND.CORE.MACHINES;
SELECT COUNT(*) FROM OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS;
SELECT COUNT(*) FROM OPSMIND.AI.ANOMALY_SIGNALS;
SELECT COUNT(*) FROM OPSMIND.AI.IMPACT_SCENARIOS;
-- Expected: All succeed with positive row counts

-- TEST A6: OPERATOR cannot INSERT directly into governance tables
USE ROLE OPSMIND_OPERATOR;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OPSMIND_WH;
SELECT CURRENT_ROLE();  -- Verify: OPSMIND_OPERATOR

INSERT INTO OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
VALUES ('APR-BYPASS', 'REC-T07', CURRENT_TIMESTAMP(), 'hacker', 'approved', 'bypass');
-- Expected: Insufficient privileges (INSERT revoked)

INSERT INTO OPSMIND.GOVERNANCE.AUDIT_LOG
VALUES ('AUD-BYPASS', 'test', 'test', CURRENT_TIMESTAMP(), 'test', 'hacker', 'bypass');
-- Expected: Insufficient privileges (INSERT revoked)

UPDATE OPSMIND.AI.RECOMMENDATIONS SET STATUS = 'approved' WHERE RECOMMENDATION_ID = 'REC-T07';
-- Expected: Insufficient privileges (UPDATE revoked)

-- TEST A7: OPERATOR can call procedures via EXECUTE AS OWNER
CALL OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION('REC-T07', 'approved', 'Operator via procedure');
-- Expected: Returns APR-NNN (success)

-- TEST A8: OPERATOR cannot read AI.IMPACT_ASSUMPTIONS
SELECT * FROM OPSMIND.AI.IMPACT_ASSUMPTIONS LIMIT 1;
-- Expected: Object does not exist or not authorized

-- TEST A9: GOVERNANCE_EXECUTOR cannot TRUNCATE, DELETE, or access CORE
USE ROLE OPSMIND_GOVERNANCE_EXECUTOR;
USE SECONDARY ROLES NONE;
TRUNCATE TABLE OPSMIND.GOVERNANCE.AUDIT_LOG;
-- Expected: Insufficient privileges

DELETE FROM OPSMIND.GOVERNANCE.AUDIT_LOG WHERE AUDIT_ID = 'AUD-100';
-- Expected: Insufficient privileges

SELECT * FROM OPSMIND.CORE.MACHINES LIMIT 1;
-- Expected: Schema does not exist or not authorized

-- ============================================================
-- REGRESSION TESTS (Phase 4A security model)
-- ============================================================

-- TEST REG1: IMPACT_SCENARIOS view calculates correctly
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
SELECT MACHINE_ID, FAILURE_COMPONENT,
       ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD,
       ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD,
       ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD
FROM OPSMIND.AI.IMPACT_SCENARIOS
WHERE MACHINE_ID = 'M-302' AND FAILURE_COMPONENT = 'bearing';
-- Expected: $13,300 planned, $44,900 unplanned, $31,600 avoided

-- TEST REG2: ANALYST can read IMPACT_SCENARIOS (Phase 4A read boundary)
USE ROLE OPSMIND_ANALYST;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OPSMIND_WH;
SELECT COUNT(*) FROM OPSMIND.AI.IMPACT_SCENARIOS;
-- Expected: 23 rows (no change from Phase 4A)

-- TEST REG3: Original seed data intact
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
SELECT APPROVAL_ID, RECOMMENDATION_ID, DECISION, DECIDED_BY
FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
WHERE APPROVAL_ID = 'APR-001';
-- Expected: APR-001, REC-001, approved, Sarah Chen - Plant Manager

SELECT ACTION_ID, APPROVAL_ID, EXECUTED_BY
FROM OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
WHERE ACTION_ID = 'ACT-001';
-- Expected: ACT-001, APR-001, OpsMind AI System

SELECT COUNT(*) FROM OPSMIND.GOVERNANCE.AUDIT_LOG WHERE AUDIT_ID LIKE 'AUD-00%';
-- Expected: 9 (original seed entries)

-- ============================================================
-- TEARDOWN: Remove test fixture data
-- (Run as ACCOUNTADMIN after all tests)
-- ============================================================
-- USE ROLE ACCOUNTADMIN;
-- USE WAREHOUSE OPSMIND_WH;
-- DELETE FROM OPSMIND.GOVERNANCE.AUDIT_LOG WHERE AUDIT_ID NOT LIKE 'AUD-00%';
-- DELETE FROM OPSMIND.GOVERNANCE.EXECUTED_ACTIONS WHERE ACTION_ID != 'ACT-001';
-- DELETE FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS WHERE APPROVAL_ID != 'APR-001';
-- UPDATE OPSMIND.AI.RECOMMENDATIONS SET STATUS = 'pending' WHERE RECOMMENDATION_ID LIKE 'REC-T%';
-- DELETE FROM OPSMIND.AI.RECOMMENDATIONS WHERE RECOMMENDATION_ID LIKE 'REC-T%';
