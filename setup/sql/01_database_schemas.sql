-- ============================================================
-- OpsMind AI — 01_database_schemas.sql
-- Database, schemas, and warehouse
-- ============================================================

-- Database
CREATE DATABASE IF NOT EXISTS OPSMIND
    COMMENT = 'OpsMind AI — Enterprise Operations Intelligence';

-- Schemas
CREATE SCHEMA IF NOT EXISTS OPSMIND.RAW
    COMMENT = 'Ingestion staging for seed and source data';

CREATE SCHEMA IF NOT EXISTS OPSMIND.CORE
    COMMENT = 'Governed operational facts — investigation inputs';

CREATE SCHEMA IF NOT EXISTS OPSMIND.KNOWLEDGE
    COMMENT = 'Unstructured operational documents — Cortex Search source';

CREATE SCHEMA IF NOT EXISTS OPSMIND.AI
    COMMENT = 'AI-generated outputs: anomaly signals, recommendations';

CREATE SCHEMA IF NOT EXISTS OPSMIND.GOVERNANCE
    COMMENT = 'Human decisions, executed actions, audit trail';

CREATE SCHEMA IF NOT EXISTS OPSMIND.APP
    COMMENT = 'Application objects: Semantic Views, Agent, Streamlit';

-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS OPSMIND_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'OpsMind AI compute warehouse';
