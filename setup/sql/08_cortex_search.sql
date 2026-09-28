-- ============================================================
-- OpsMind AI — 08_cortex_search.sql
-- Create Cortex Search service over operational documents
-- Target schema: OPSMIND.APP
-- Source: OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

CREATE OR REPLACE CORTEX SEARCH SERVICE OPSMIND.APP.OPS_KNOWLEDGE_SEARCH
  ON CONTENT
  PRIMARY KEY (DOC_ID)
  ATTRIBUTES DOC_TYPE, TITLE, APPLICABLE_MACHINE_TYPES, APPLICABLE_COMPONENTS
  WAREHOUSE = OPSMIND_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'OpsMind operational knowledge retrieval — SOPs, thresholds, troubleshooting guides'
AS (
  SELECT
    DOC_ID,
    DOC_TYPE,
    TITLE,
    CONTENT,
    APPLICABLE_MACHINE_TYPES,
    APPLICABLE_COMPONENTS
  FROM OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS
);
