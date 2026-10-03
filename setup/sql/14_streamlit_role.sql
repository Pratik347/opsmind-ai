-- ============================================================
-- OpsMind AI — 14_streamlit_role.sql
-- Phase 5: OPSMIND_STREAMLIT role — least-privilege owner of
-- the Streamlit Command Center application.
--
-- Execution model: Streamlit-in-Snowflake runs with OWNER'S
-- RIGHTS (get_active_session() / st.connection("snowflake")).
-- OPSMIND_STREAMLIT is the owner and effective execution role.
--
-- Effective privilege matrix:
--   READ: CORE.*, AI.ANOMALY_SIGNALS, AI.IMPACT_SCENARIOS,
--         AI.FAILURE_RISK_SCORES, AI.RECOMMENDATIONS,
--         GOVERNANCE.* (read only), APP.OPSMIND_OPERATIONS
--   WRITE: none (governance writes go through EXECUTE AS OWNER
--          procedures inherited from OPSMIND_OPERATOR)
--   AGENT: SNOWFLAKE.CORTEX.DATA_AGENT_RUN via
--          SNOWFLAKE.CORTEX_AGENT_USER database role
--   PROCEDURES: GOVERNANCE.APPROVE_RECOMMENDATION,
--               GOVERNANCE.EXECUTE_APPROVED_ACTION
--
-- Deployment: run AFTER scripts 00–12.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- ============================================================
-- 1. Create role and hierarchy
--    STREAMLIT inherits from OPERATOR (which inherits ANALYST).
--    This gives it the full read surface plus procedure USAGE.
-- ============================================================

CREATE ROLE IF NOT EXISTS OPSMIND_STREAMLIT
    COMMENT = 'OpsMind Streamlit Command Center — owner-rights execution role';

GRANT ROLE OPSMIND_OPERATOR TO ROLE OPSMIND_STREAMLIT;
GRANT ROLE OPSMIND_STREAMLIT TO ROLE ACCOUNTADMIN;

-- ============================================================
-- 2. Database and warehouse
-- ============================================================

GRANT USAGE ON DATABASE OPSMIND TO ROLE OPSMIND_STREAMLIT;
GRANT USAGE ON WAREHOUSE OPSMIND_WH TO ROLE OPSMIND_STREAMLIT;

-- ============================================================
-- 3. Cortex Agent access
--    Use CORTEX_AGENT_USER (narrow) rather than CORTEX_USER.
--    This is sufficient for DATA_AGENT_RUN.
-- ============================================================

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE OPSMIND_STREAMLIT;

-- ============================================================
-- 4. APP schema — semantic view + agent + stage
--    The Streamlit app invokes DATA_AGENT_RUN which references
--    the agent and semantic view in APP schema.
-- ============================================================

GRANT USAGE ON SCHEMA OPSMIND.APP TO ROLE OPSMIND_STREAMLIT;

-- Agent needs USAGE grant (object type is AGENT, not CORTEX AGENT)
GRANT USAGE ON AGENT OPSMIND.APP.OPSMIND_AGENT TO ROLE OPSMIND_STREAMLIT;

-- Semantic view
GRANT SELECT ON VIEW OPSMIND.APP.OPSMIND_OPERATIONS TO ROLE OPSMIND_STREAMLIT;

-- Cortex Search service — required for Agent KnowledgeSearch tool
GRANT USAGE ON CORTEX SEARCH SERVICE OPSMIND.APP.OPS_KNOWLEDGE_SEARCH TO ROLE OPSMIND_STREAMLIT;

-- Stage: owner needs READ + WRITE for the Streamlit backing stage
GRANT READ, WRITE ON STAGE OPSMIND.APP.STREAMLIT_STAGE TO ROLE OPSMIND_STREAMLIT;

-- ============================================================
-- 5. Explicit object grants beyond inheritance
--    OPERATOR inherits ANALYST which already has:
--      CORE.* (SELECT), KNOWLEDGE.* (SELECT),
--      AI.ANOMALY_SIGNALS (SELECT), AI.FAILURE_RISK_SCORES (SELECT)
--    OPERATOR directly has:
--      GOVERNANCE.* (SELECT), AI.RECOMMENDATIONS (SELECT),
--      procedure USAGE on APPROVE/EXECUTE procedures
--
--    The only additional grant STREAMLIT needs beyond OPERATOR
--    is AI.IMPACT_SCENARIOS (read-only).
-- ============================================================

GRANT SELECT ON VIEW OPSMIND.AI.IMPACT_SCENARIOS TO ROLE OPSMIND_STREAMLIT;

-- ============================================================
-- 6. Create Streamlit object AS OPSMIND_STREAMLIT
--    GRANT OWNERSHIP is not supported for STREAMLIT objects, so
--    we must CREATE the object while using the intended owner
--    role. Temporarily grant CREATE STREAMLIT, create the
--    object, then revoke the CREATE privilege.
-- ============================================================

-- Temporary: allow OPSMIND_STREAMLIT to create the Streamlit object
GRANT CREATE STREAMLIT ON SCHEMA OPSMIND.APP TO ROLE OPSMIND_STREAMLIT;

USE ROLE OPSMIND_STREAMLIT;

CREATE OR REPLACE STREAMLIT OPSMIND.APP.OPSMIND_COMMAND_CENTER
    ROOT_LOCATION = '@OPSMIND.APP.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = OPSMIND_WH
    TITLE = 'OpsMind AI Command Center'
    COMMENT = 'Enterprise operations intelligence platform — fleet risk, asset intelligence, AI investigation, governed approvals, audit trail.';

-- Revoke CREATE STREAMLIT — no longer needed after creation
USE ROLE ACCOUNTADMIN;
REVOKE CREATE STREAMLIT ON SCHEMA OPSMIND.APP FROM ROLE OPSMIND_STREAMLIT;

-- ============================================================
-- Phase 5 RBAC deployment complete.
--
-- Owner-rights execution model:
--   OPSMIND_COMMAND_CENTER is OWNED BY OPSMIND_STREAMLIT.
--   get_active_session() runs with OPSMIND_STREAMLIT privileges.
--   Viewers need USAGE on the Streamlit object to open the app,
--   but all queries execute as OPSMIND_STREAMLIT (owner-rights).
--
-- Effective privilege chain:
--   OPSMIND_STREAMLIT (owner = effective execution role)
--     → inherits OPSMIND_OPERATOR
--       → inherits OPSMIND_ANALYST
--         → CORE.* SELECT, KNOWLEDGE.* SELECT,
--           AI.ANOMALY_SIGNALS SELECT, AI.FAILURE_RISK_SCORES SELECT
--       → GOVERNANCE.* SELECT
--       → AI.RECOMMENDATIONS SELECT
--       → procedure USAGE (APPROVE_RECOMMENDATION, EXECUTE_APPROVED_ACTION)
--     → SNOWFLAKE.CORTEX_AGENT_USER (DATA_AGENT_RUN)
--     → APP.OPSMIND_AGENT USAGE
--     → APP.OPSMIND_OPERATIONS SELECT
--     → APP.OPS_KNOWLEDGE_SEARCH USAGE (Cortex Search — Agent KnowledgeSearch)
--     → AI.IMPACT_SCENARIOS SELECT
-- ============================================================
