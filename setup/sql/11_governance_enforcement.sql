-- ============================================================
-- OpsMind AI — 11_governance_enforcement.sql
-- Phase 4B: Approval / Execution State Machine
--
-- Enforces the governance chain:
--   Agent investigates → produces recommendation →
--   human explicitly approves or rejects →
--   only approved action may execute →
--   execution is idempotent →
--   all decisions and events are audited.
--
-- Deployment: run AFTER all scripts 00–10.
-- Idempotent: sequences use IF NOT EXISTS; procedures use
-- CREATE OR REPLACE. CHECK/UNIQUE constraints must not already
-- exist (Snowflake does not support DROP CONSTRAINT IF EXISTS);
-- on a fresh deploy they will not.
--
-- Security model:
--   OPSMIND_GOVERNANCE_EXECUTOR — least-privilege role that owns
--     the state-machine procedures and has only the DML needed
--     to transition state and write audit entries.
--   OPSMIND_OPERATOR — USAGE on procedures only; direct DML on
--     governance tables is revoked.
--   OPSMIND_ANALYST / Agent — no GOVERNANCE access, no procedure
--     USAGE. This is the primary enforcement against agent
--     self-approval (RBAC boundary). CURRENT_USER() checks in
--     procedures are defense-in-depth only.
--
-- Concurrency model:
--   Procedures use a conditional UPDATE as the first DML inside
--   the transaction (UPDATE ... WHERE STATUS = 'pending'). This
--   serves as the concurrency serialization point: Snowflake
--   serializes concurrent UPDATEs to the same row, so a second
--   concurrent caller will wait, then find the status already
--   changed, match 0 rows, and bail out safely.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- ============================================================
-- 1. CHECK constraints (enforced database controls)
--    Snowflake enforces CHECK constraints on new DML. Added with
--    ENABLE NOVALIDATE: the constraint is enforced for all future
--    INSERT/UPDATE but does not scan existing rows (which are
--    known-valid from seed data loading).
-- ============================================================

ALTER TABLE OPSMIND.AI.RECOMMENDATIONS
    ADD CONSTRAINT CHK_REC_STATUS
    CHECK (STATUS IN ('pending', 'approved', 'rejected', 'executed'))
    ENABLE NOVALIDATE;

ALTER TABLE OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    ADD CONSTRAINT CHK_APPROVAL_DECISION
    CHECK (DECISION IN ('approved', 'rejected', 'deferred'))
    ENABLE NOVALIDATE;

-- ============================================================
-- 2. UNIQUE constraints (metadata / documentation)
--    Snowflake does NOT enforce UNIQUE constraints on standard
--    tables. These are retained as schema documentation of the
--    intended cardinality invariants. Procedure pre-condition
--    checks are the authoritative idempotency control.
-- ============================================================

ALTER TABLE OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    ADD CONSTRAINT UQ_APPROVAL_REC UNIQUE (RECOMMENDATION_ID);

ALTER TABLE OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
    ADD CONSTRAINT UQ_EXECUTION_APPROVAL UNIQUE (APPROVAL_ID);

-- ============================================================
-- 3. OPSMIND_GOVERNANCE_EXECUTOR role
--    Least-privilege owner of governance state-machine procedures.
--    Has only the DML privileges needed to:
--      - Read and insert approval decisions
--      - Read and insert executed actions
--      - Read and insert audit log entries
--      - Read and update recommendation status
--    Does NOT have: DROP, TRUNCATE, DELETE, or any privileges
--    beyond what the procedures require.
-- ============================================================

CREATE ROLE IF NOT EXISTS OPSMIND_GOVERNANCE_EXECUTOR
    COMMENT = 'Least-privilege owner of governance state-machine procedures';

GRANT ROLE OPSMIND_GOVERNANCE_EXECUTOR TO ROLE ACCOUNTADMIN;

GRANT USAGE ON DATABASE OPSMIND TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT USAGE ON SCHEMA OPSMIND.GOVERNANCE TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT USAGE ON SCHEMA OPSMIND.AI TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT USAGE ON WAREHOUSE OPSMIND_WH TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;

GRANT SELECT, INSERT ON TABLE OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT SELECT, INSERT ON TABLE OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
    TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT SELECT, INSERT ON TABLE OPSMIND.GOVERNANCE.AUDIT_LOG
    TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT SELECT, UPDATE ON TABLE OPSMIND.AI.RECOMMENDATIONS
    TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;

GRANT CREATE PROCEDURE ON SCHEMA OPSMIND.GOVERNANCE
    TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;
GRANT CREATE SEQUENCE ON SCHEMA OPSMIND.GOVERNANCE
    TO ROLE OPSMIND_GOVERNANCE_EXECUTOR;

-- ============================================================
-- 4. Switch to GOVERNANCE_EXECUTOR to create owned objects
--    Procedures created here will be owned by this role.
--    EXECUTE AS OWNER means they run with GOVERNANCE_EXECUTOR
--    privileges — the minimum DML needed for state transitions.
-- ============================================================

USE ROLE OPSMIND_GOVERNANCE_EXECUTOR;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;
USE SCHEMA GOVERNANCE;

-- ============================================================
-- 5. Sequences for unique ID generation
--    Snowflake sequences are NOT gap-free. They provide unique,
--    monotonically increasing values suitable for ID generation
--    but may skip values under concurrency or restart.
--    Start at 100 to avoid collision with existing seed data
--    (APR-001, ACT-001, AUD-001 through AUD-009).
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS OPSMIND.GOVERNANCE.APPROVAL_SEQ
    START = 100 INCREMENT = 1
    COMMENT = 'Unique ID generator for approval decisions. Not gap-free.';

CREATE SEQUENCE IF NOT EXISTS OPSMIND.GOVERNANCE.ACTION_SEQ
    START = 100 INCREMENT = 1
    COMMENT = 'Unique ID generator for executed actions. Not gap-free.';

CREATE SEQUENCE IF NOT EXISTS OPSMIND.GOVERNANCE.AUDIT_SEQ
    START = 100 INCREMENT = 1
    COMMENT = 'Unique ID generator for audit log entries. Not gap-free.';

-- ============================================================
-- 6. Procedure: APPROVE_RECOMMENDATION
--
-- Transitions a recommendation from 'pending' to 'approved' or
-- 'rejected'. Atomically creates the approval decision, updates
-- recommendation status, and writes audit entries.
--
-- Pre-conditions (fast-fail, before transaction):
--   - Recommendation exists and STATUS = 'pending'
--   - No existing approval decision for this recommendation
--   - Decision value is 'approved' or 'rejected'
--   - Caller is not a known system/agent actor (defense-in-depth)
--
-- Concurrency guard (inside transaction):
--   Conditional UPDATE ... WHERE STATUS = 'pending' is the first
--   DML. Snowflake serializes concurrent UPDATEs to the same
--   row, closing the TOCTOU window.
--
-- Atomicity: BEGIN TRANSACTION … COMMIT with EXCEPTION → ROLLBACK.
-- Identity: P_ACTOR must be supplied by the caller. In Streamlit
--   owner-rights mode, CURRENT_USER() returns the owner role (not the
--   viewer), resolving to NULL. The Streamlit app uses st.user.user_name
--   — a Snowflake-authenticated viewer identity — and passes it here.
--   The procedure rejects NULL, empty, whitespace-only, and literal
--   'None' values (Python None stringification defense).
--
-- Returns: APPROVAL_ID on success, 'ERROR: …' string on failure.
-- ============================================================

CREATE OR REPLACE PROCEDURE GOVERNANCE.APPROVE_RECOMMENDATION(
    P_RECOMMENDATION_ID VARCHAR,
    P_DECISION VARCHAR,
    P_COMMENTS VARCHAR,
    P_ACTOR VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_REC_COUNT INTEGER;
    V_CURRENT_STATUS VARCHAR;
    V_EXISTING_APPROVAL_COUNT INTEGER;
    V_APPROVAL_ID VARCHAR;
    V_AUDIT_ID_1 VARCHAR;
    V_AUDIT_ID_2 VARCHAR;
    V_SEQ_APR INTEGER;
    V_SEQ_AUD1 INTEGER;
    V_SEQ_AUD2 INTEGER;
    V_ROWS_UPDATED INTEGER;
    V_CALLER VARCHAR DEFAULT :P_ACTOR;
    V_NOW TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
BEGIN
    -- ── Fast-fail validation (before transaction) ────────────
    -- These pre-checks catch most errors without transaction
    -- overhead. They are NOT the concurrency-safety mechanism.

    IF (V_CALLER IS NULL OR TRIM(V_CALLER) = '' OR V_CALLER = 'None') THEN
        RETURN 'ERROR: Actor identity (P_ACTOR) is required. Cannot record approval without auditable human identity.';
    END IF;

    IF (:P_DECISION NOT IN ('approved', 'rejected')) THEN
        RETURN 'ERROR: Invalid decision value. Must be ''approved'' or ''rejected''.';
    END IF;

    SELECT COUNT(*), MAX(STATUS)
        INTO :V_REC_COUNT, :V_CURRENT_STATUS
    FROM OPSMIND.AI.RECOMMENDATIONS
    WHERE RECOMMENDATION_ID = :P_RECOMMENDATION_ID;

    IF (V_REC_COUNT = 0) THEN
        RETURN 'ERROR: Recommendation ' || :P_RECOMMENDATION_ID || ' not found.';
    END IF;

    IF (V_CURRENT_STATUS != 'pending') THEN
        RETURN 'ERROR: Recommendation ' || :P_RECOMMENDATION_ID
            || ' is not pending (current status: ' || V_CURRENT_STATUS || ').';
    END IF;

    -- Idempotency pre-check (authoritative control — UNIQUE constraint
    -- on RECOMMENDATION_ID is metadata only, not enforced by Snowflake)
    SELECT COUNT(*) INTO :V_EXISTING_APPROVAL_COUNT
    FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    WHERE RECOMMENDATION_ID = :P_RECOMMENDATION_ID;

    IF (V_EXISTING_APPROVAL_COUNT > 0) THEN
        RETURN 'ERROR: Recommendation ' || :P_RECOMMENDATION_ID
            || ' already has an approval decision.';
    END IF;

    -- Defense-in-depth: deny known system/agent actors.
    -- Primary enforcement is RBAC (Agent has no procedure USAGE).
    IF (V_CALLER ILIKE '%agent%' OR V_CALLER ILIKE 'OPSMIND_AI%') THEN
        RETURN 'ERROR: System or agent actors cannot approve recommendations.';
    END IF;

    -- ── Generate unique IDs (sequences are not gap-free) ─────

    SELECT APPROVAL_SEQ.NEXTVAL INTO :V_SEQ_APR FROM TABLE(GENERATOR(ROWCOUNT => 1));
    SELECT AUDIT_SEQ.NEXTVAL INTO :V_SEQ_AUD1 FROM TABLE(GENERATOR(ROWCOUNT => 1));
    SELECT AUDIT_SEQ.NEXTVAL INTO :V_SEQ_AUD2 FROM TABLE(GENERATOR(ROWCOUNT => 1));

    V_APPROVAL_ID := 'APR-' || TO_VARCHAR(:V_SEQ_APR);
    V_AUDIT_ID_1  := 'AUD-' || TO_VARCHAR(:V_SEQ_AUD1);
    V_AUDIT_ID_2  := 'AUD-' || TO_VARCHAR(:V_SEQ_AUD2);

    -- ── Atomic transition ────────────────────────────────────
    -- Conditional UPDATE is the FIRST DML inside the transaction.
    -- It is the concurrency serialization point: Snowflake
    -- serializes concurrent UPDATEs to the same row, so a
    -- second concurrent caller will wait for the first to
    -- commit, then find STATUS != 'pending', match 0 rows,
    -- and bail out. This closes the TOCTOU window between the
    -- pre-check SELECT and the write.

    BEGIN TRANSACTION;

    UPDATE OPSMIND.AI.RECOMMENDATIONS
    SET STATUS = :P_DECISION
    WHERE RECOMMENDATION_ID = :P_RECOMMENDATION_ID
      AND STATUS = 'pending';

    -- Verify the update took effect (concurrency guard)
    SELECT COUNT(*) INTO :V_ROWS_UPDATED
    FROM OPSMIND.AI.RECOMMENDATIONS
    WHERE RECOMMENDATION_ID = :P_RECOMMENDATION_ID
      AND STATUS = :P_DECISION;

    IF (V_ROWS_UPDATED = 0) THEN
        ROLLBACK;
        RETURN 'ERROR: Concurrent modification detected — recommendation '
            || :P_RECOMMENDATION_ID || ' is no longer pending.';
    END IF;

    INSERT INTO OPSMIND.GOVERNANCE.APPROVAL_DECISIONS (
        APPROVAL_ID, RECOMMENDATION_ID, DECISION_AT, DECIDED_BY, DECISION, COMMENTS
    ) VALUES (
        :V_APPROVAL_ID, :P_RECOMMENDATION_ID, :V_NOW,
        :V_CALLER, :P_DECISION, :P_COMMENTS
    );

    INSERT INTO OPSMIND.GOVERNANCE.AUDIT_LOG (
        AUDIT_ID, ENTITY_TYPE, ENTITY_ID, EVENT_TS,
        EVENT_TYPE, ACTOR, DETAILS
    ) VALUES (
        :V_AUDIT_ID_1, 'recommendation', :P_RECOMMENDATION_ID, :V_NOW,
        :P_DECISION, :V_CALLER,
        'Recommendation ' || :P_DECISION || ' by ' || :V_CALLER
    );

    INSERT INTO OPSMIND.GOVERNANCE.AUDIT_LOG (
        AUDIT_ID, ENTITY_TYPE, ENTITY_ID, EVENT_TS,
        EVENT_TYPE, ACTOR, DETAILS
    ) VALUES (
        :V_AUDIT_ID_2, 'approval_decision', :V_APPROVAL_ID, :V_NOW,
        'created', :V_CALLER,
        'Approval decision ' || :V_APPROVAL_ID
            || ' created for recommendation ' || :P_RECOMMENDATION_ID
    );

    COMMIT;

    RETURN V_APPROVAL_ID;

EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;

-- ============================================================
-- 7. Procedure: EXECUTE_APPROVED_ACTION
--
-- Transitions an approved recommendation to 'executed'.
-- Atomically creates the executed action record, updates
-- recommendation status, and writes audit entries.
--
-- Pre-conditions (fast-fail, before transaction):
--   - Approval exists and DECISION = 'approved'
--   - Linked recommendation STATUS = 'approved' (belt-and-suspenders)
--   - No existing execution for this approval
--
-- Concurrency guard (inside transaction):
--   Conditional UPDATE ... WHERE STATUS = 'approved' is the first
--   DML. Same serialization mechanism as APPROVE_RECOMMENDATION.
--
-- Atomicity: BEGIN TRANSACTION … COMMIT with EXCEPTION → ROLLBACK.
-- Identity: P_ACTOR must be supplied by the caller (same rationale
--   as APPROVE_RECOMMENDATION — see above).
--
-- Returns: ACTION_ID on success, 'ERROR: …' string on failure.
-- ============================================================

CREATE OR REPLACE PROCEDURE GOVERNANCE.EXECUTE_APPROVED_ACTION(
    P_APPROVAL_ID VARCHAR,
    P_ACTION_TYPE VARCHAR,
    P_DESCRIPTION VARCHAR,
    P_ACTOR VARCHAR,
    P_WO_ID VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_APPROVAL_COUNT INTEGER;
    V_DECISION VARCHAR;
    V_RECOMMENDATION_ID VARCHAR;
    V_REC_STATUS VARCHAR;
    V_EXISTING_EXECUTION_COUNT INTEGER;
    V_ACTION_ID VARCHAR;
    V_AUDIT_ID_1 VARCHAR;
    V_AUDIT_ID_2 VARCHAR;
    V_SEQ_ACT INTEGER;
    V_SEQ_AUD1 INTEGER;
    V_SEQ_AUD2 INTEGER;
    V_ROWS_UPDATED INTEGER;
    V_CALLER VARCHAR DEFAULT :P_ACTOR;
    V_NOW TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
BEGIN
    -- ── Fast-fail validation (before transaction) ────────────

    IF (V_CALLER IS NULL OR TRIM(V_CALLER) = '' OR V_CALLER = 'None') THEN
        RETURN 'ERROR: Actor identity (P_ACTOR) is required. Cannot record execution without auditable human identity.';
    END IF;

    SELECT COUNT(*), MAX(DECISION), MAX(RECOMMENDATION_ID)
        INTO :V_APPROVAL_COUNT, :V_DECISION, :V_RECOMMENDATION_ID
    FROM OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    WHERE APPROVAL_ID = :P_APPROVAL_ID;

    IF (V_APPROVAL_COUNT = 0) THEN
        RETURN 'ERROR: Approval ' || :P_APPROVAL_ID || ' not found.';
    END IF;

    IF (V_DECISION != 'approved') THEN
        RETURN 'ERROR: Approval ' || :P_APPROVAL_ID
            || ' decision is ''' || V_DECISION || ''', not ''approved''.';
    END IF;

    SELECT STATUS INTO :V_REC_STATUS
    FROM OPSMIND.AI.RECOMMENDATIONS
    WHERE RECOMMENDATION_ID = :V_RECOMMENDATION_ID;

    IF (V_REC_STATUS != 'approved') THEN
        RETURN 'ERROR: Recommendation ' || V_RECOMMENDATION_ID
            || ' status is ''' || V_REC_STATUS
            || ''', expected ''approved''. State inconsistency detected.';
    END IF;

    SELECT COUNT(*) INTO :V_EXISTING_EXECUTION_COUNT
    FROM OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
    WHERE APPROVAL_ID = :P_APPROVAL_ID;

    IF (V_EXISTING_EXECUTION_COUNT > 0) THEN
        RETURN 'ERROR: Approval ' || :P_APPROVAL_ID
            || ' has already been executed.';
    END IF;

    -- ── Generate unique IDs (sequences are not gap-free) ─────

    SELECT ACTION_SEQ.NEXTVAL INTO :V_SEQ_ACT FROM TABLE(GENERATOR(ROWCOUNT => 1));
    SELECT AUDIT_SEQ.NEXTVAL INTO :V_SEQ_AUD1 FROM TABLE(GENERATOR(ROWCOUNT => 1));
    SELECT AUDIT_SEQ.NEXTVAL INTO :V_SEQ_AUD2 FROM TABLE(GENERATOR(ROWCOUNT => 1));

    V_ACTION_ID  := 'ACT-' || TO_VARCHAR(:V_SEQ_ACT);
    V_AUDIT_ID_1 := 'AUD-' || TO_VARCHAR(:V_SEQ_AUD1);
    V_AUDIT_ID_2 := 'AUD-' || TO_VARCHAR(:V_SEQ_AUD2);

    -- ── Atomic transition ────────────────────────────────────
    -- Conditional UPDATE is FIRST DML: concurrency serialization
    -- point. Second concurrent caller's UPDATE finds STATUS !=
    -- 'approved', matches 0 rows, and bails out.

    BEGIN TRANSACTION;

    UPDATE OPSMIND.AI.RECOMMENDATIONS
    SET STATUS = 'executed'
    WHERE RECOMMENDATION_ID = :V_RECOMMENDATION_ID
      AND STATUS = 'approved';

    SELECT COUNT(*) INTO :V_ROWS_UPDATED
    FROM OPSMIND.AI.RECOMMENDATIONS
    WHERE RECOMMENDATION_ID = :V_RECOMMENDATION_ID
      AND STATUS = 'executed';

    IF (V_ROWS_UPDATED = 0) THEN
        ROLLBACK;
        RETURN 'ERROR: Concurrent modification detected — recommendation '
            || V_RECOMMENDATION_ID || ' is no longer in approved state.';
    END IF;

    INSERT INTO OPSMIND.GOVERNANCE.EXECUTED_ACTIONS (
        ACTION_ID, APPROVAL_ID, WO_ID, EXECUTED_AT,
        ACTION_TYPE, DESCRIPTION, EXECUTED_BY, RESULT
    ) VALUES (
        :V_ACTION_ID, :P_APPROVAL_ID, :P_WO_ID, :V_NOW,
        :P_ACTION_TYPE, :P_DESCRIPTION, :V_CALLER,
        'Action executed via governed procedure'
    );

    INSERT INTO OPSMIND.GOVERNANCE.AUDIT_LOG (
        AUDIT_ID, ENTITY_TYPE, ENTITY_ID, EVENT_TS,
        EVENT_TYPE, ACTOR, DETAILS
    ) VALUES (
        :V_AUDIT_ID_1, 'executed_action', :V_ACTION_ID, :V_NOW,
        'executed', :V_CALLER,
        'Action ' || :V_ACTION_ID || ' executed for approval ' || :P_APPROVAL_ID
    );

    INSERT INTO OPSMIND.GOVERNANCE.AUDIT_LOG (
        AUDIT_ID, ENTITY_TYPE, ENTITY_ID, EVENT_TS,
        EVENT_TYPE, ACTOR, DETAILS
    ) VALUES (
        :V_AUDIT_ID_2, 'recommendation', :V_RECOMMENDATION_ID, :V_NOW,
        'executed', :V_CALLER,
        'Recommendation ' || :V_RECOMMENDATION_ID
            || ' marked executed after action ' || :V_ACTION_ID
    );

    COMMIT;

    RETURN V_ACTION_ID;

EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;

-- ============================================================
-- 8. Switch back to ACCOUNTADMIN for RBAC changes
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- 9. Revoke direct DML from OPERATOR on governance tables
--    After this, OPERATOR can only modify governance data
--    through the stored procedures, which enforce all invariants.
--
--    Note: The original INSERT/UPDATE grants in 02_roles_grants.sql
--    are kept for deployment ordering (procedures don't exist at
--    step 02). This script (step 11) tightens the grants.
-- ============================================================

REVOKE INSERT ON TABLE OPSMIND.GOVERNANCE.APPROVAL_DECISIONS
    FROM ROLE OPSMIND_OPERATOR;
REVOKE INSERT ON TABLE OPSMIND.GOVERNANCE.EXECUTED_ACTIONS
    FROM ROLE OPSMIND_OPERATOR;
REVOKE INSERT ON TABLE OPSMIND.GOVERNANCE.AUDIT_LOG
    FROM ROLE OPSMIND_OPERATOR;
REVOKE UPDATE ON TABLE OPSMIND.AI.RECOMMENDATIONS
    FROM ROLE OPSMIND_OPERATOR;

-- ============================================================
-- 10. Grant procedure USAGE to OPERATOR
--     OPERATOR can call procedures but not bypass them.
-- ============================================================

GRANT USAGE ON PROCEDURE OPSMIND.GOVERNANCE.APPROVE_RECOMMENDATION(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR
) TO ROLE OPSMIND_OPERATOR;

GRANT USAGE ON PROCEDURE OPSMIND.GOVERNANCE.EXECUTE_APPROVED_ACTION(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR
) TO ROLE OPSMIND_OPERATOR;

-- ============================================================
-- Phase 4B deployment complete.
--
-- State machine enforced:
--   pending → approved  (APPROVE_RECOMMENDATION with 'approved')
--   pending → rejected  (APPROVE_RECOMMENDATION with 'rejected')
--   approved → executed (EXECUTE_APPROVED_ACTION)
--   rejected → terminal
--   executed → terminal
--
-- Validate with: tests/sql/test_governance_enforcement.sql
-- ============================================================
