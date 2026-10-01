-- ============================================================
-- OpsMind AI — 10_impact_model.sql
-- Business Impact / What-If Engine
--
-- Creates governed assumption table (internal configuration)
-- and deterministic scenario calculation view (the read
-- boundary for Cortex Analyst and the Agent).
--
-- IMPORTANT: All financial values in IMPACT_ASSUMPTIONS are
-- SYNTHETIC DEMO ASSUMPTIONS — not real enterprise financial
-- data. They exist solely to demonstrate the what-if workflow.
--
-- Security boundary:
--   IMPACT_ASSUMPTIONS  (governed config — ACCOUNTADMIN only)
--     -> deterministic SQL calculation
--     -> IMPACT_SCENARIOS (read boundary — exposed via Semantic View)
--       -> Cortex Analyst -> Agent
--
-- OPSMIND_ANALYST does NOT get direct SELECT on IMPACT_ASSUMPTIONS.
-- OPSMIND_ANALYST gets SELECT only on IMPACT_SCENARIOS.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- ============================================================
-- 1. Business-Impact Assumptions Table (governed config)
-- ============================================================

CREATE TABLE IF NOT EXISTS OPSMIND.AI.IMPACT_ASSUMPTIONS (
    ASSUMPTION_ID                    VARCHAR(20)  NOT NULL,
    MACHINE_TYPE                     VARCHAR(50)  NOT NULL,
    FAILURE_COMPONENT                VARCHAR(50)  NOT NULL,

    -- Planned intervention parameters
    PLANNED_DOWNTIME_HRS             FLOAT        NOT NULL,
    PLANNED_LABOR_COST_USD           FLOAT        NOT NULL,
    PLANNED_PARTS_COST_USD           FLOAT        NOT NULL,

    -- Unplanned failure parameters
    UNPLANNED_DOWNTIME_HRS           FLOAT        NOT NULL,
    EMERGENCY_LABOR_COST_USD         FLOAT        NOT NULL,
    EXPEDITED_PARTS_COST_USD         FLOAT        NOT NULL,
    ESTIMATED_COLLATERAL_REPAIR_COST_USD FLOAT    NOT NULL,

    -- Production value
    PRODUCTION_VALUE_PER_UNIT_USD    FLOAT        NOT NULL,

    -- Assumption governance
    ASSUMPTION_SOURCE                VARCHAR(50)  NOT NULL DEFAULT 'SYNTHETIC_DEMO',
    ASSUMPTION_BASIS                 VARCHAR(500) NOT NULL,
    ASSUMPTION_VERSION               VARCHAR(10)  NOT NULL DEFAULT 'v1.0',
    LAST_UPDATED                     TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_IMPACT_ASSUMPTIONS PRIMARY KEY (ASSUMPTION_ID)
);

-- ============================================================
-- 2. Seed Assumption Data
-- ============================================================

TRUNCATE TABLE OPSMIND.AI.IMPACT_ASSUMPTIONS;

INSERT INTO OPSMIND.AI.IMPACT_ASSUMPTIONS (
    ASSUMPTION_ID, MACHINE_TYPE, FAILURE_COMPONENT,
    PLANNED_DOWNTIME_HRS, PLANNED_LABOR_COST_USD, PLANNED_PARTS_COST_USD,
    UNPLANNED_DOWNTIME_HRS, EMERGENCY_LABOR_COST_USD, EXPEDITED_PARTS_COST_USD,
    ESTIMATED_COLLATERAL_REPAIR_COST_USD, PRODUCTION_VALUE_PER_UNIT_USD,
    ASSUMPTION_SOURCE, ASSUMPTION_BASIS, ASSUMPTION_VERSION
) VALUES
-- CNC Milling Center — bearing (primary demo scenario component)
('IMP-001', 'CNC Milling Center', 'bearing',
  8, 500, 800, 24, 1500, 2400, 5000, 15,
  'SYNTHETIC_DEMO',
  'Informed by historical maintenance costs ($280-$320 preventive, $4800 emergency bearing replacement) and failure downtime (960 min) from plant operational records. Rounded and simplified for demonstration.',
  'v1.0'),
-- CNC Milling Center — spindle
('IMP-002', 'CNC Milling Center', 'spindle',
  12, 800, 2000, 36, 2400, 6000, 8000, 15,
  'SYNTHETIC_DEMO',
  'Synthetic estimate based on spindle complexity relative to bearing work. No direct historical spindle failure in dataset. Proportioned from bearing assumptions.',
  'v1.0'),
-- CNC Milling Center — coolant_system
('IMP-003', 'CNC Milling Center', 'coolant_system',
  4, 300, 400, 8, 600, 800, 500, 15,
  'SYNTHETIC_DEMO',
  'Informed by historical coolant pump failure ($420 repair, 180 min downtime). Scaled for demonstration with typical coolant system scope.',
  'v1.0'),
-- CNC Lathe — bearing
('IMP-004', 'CNC Lathe', 'bearing',
  6, 400, 600, 18, 1200, 1800, 3500, 12,
  'SYNTHETIC_DEMO',
  'Adapted from CNC Milling Center bearing assumptions, adjusted for smaller lathe bearing assemblies and lower production value per unit.',
  'v1.0'),
-- Hydraulic Press — seals
('IMP-005', 'Hydraulic Press', 'seals',
  4, 350, 500, 12, 1000, 1500, 2000, 10,
  'SYNTHETIC_DEMO',
  'Informed by historical seal replacement ($520 preventive, $1200 corrective). Scaled for demonstration.',
  'v1.0'),
-- Hydraulic Press — hydraulic_system
('IMP-006', 'Hydraulic Press', 'hydraulic_system',
  8, 600, 1200, 24, 1800, 3600, 6000, 10,
  'SYNTHETIC_DEMO',
  'Synthetic estimate for full hydraulic system failure. No direct historical event. Based on seal assumption proportions and hydraulic complexity.',
  'v1.0'),
-- Assembly Robot — joints
('IMP-007', 'Assembly Robot', 'joints',
  6, 500, 1500, 16, 1500, 4500, 4000, 8,
  'SYNTHETIC_DEMO',
  'Synthetic estimate for robotic joint failure. No historical joint failure in dataset. Based on manufacturer typical service intervals and parts cost ratios.',
  'v1.0');

-- ============================================================
-- 3. Deterministic Impact Scenarios View
-- ============================================================
-- Joins assumptions with machine/line data to produce
-- per-machine, per-component scenario estimates.
-- All calculations are deterministic SQL — no LLM involvement.
--
-- LIMITATION: Production loss is calculated using line
-- DESIGN_CAPACITY_UNITS_HR as a proxy — not actual realized
-- throughput or revenue. This is a synthetic production value
-- proxy suitable for demonstration and directional analysis.
--
-- Missing assumptions result in no scenario row (INNER JOIN
-- on MACHINE_TYPE). No COALESCE or default substitution.
-- ============================================================

CREATE OR REPLACE VIEW OPSMIND.AI.IMPACT_SCENARIOS AS
SELECT
    -- Machine context
    m.MACHINE_ID,
    m.MACHINE_NAME,
    m.MACHINE_TYPE,
    m.CRITICALITY_RATING,
    pl.LINE_ID,
    pl.LINE_NAME,
    pl.DESIGN_CAPACITY_UNITS_HR,

    -- Assumption identity and provenance
    a.ASSUMPTION_ID,
    a.FAILURE_COMPONENT,
    a.ASSUMPTION_SOURCE,
    a.ASSUMPTION_BASIS,
    a.ASSUMPTION_VERSION,

    -- Input assumptions (included for full reconstruction transparency)
    a.PLANNED_DOWNTIME_HRS,
    a.PLANNED_LABOR_COST_USD,
    a.PLANNED_PARTS_COST_USD,
    a.UNPLANNED_DOWNTIME_HRS,
    a.EMERGENCY_LABOR_COST_USD,
    a.EXPEDITED_PARTS_COST_USD,
    a.ESTIMATED_COLLATERAL_REPAIR_COST_USD,
    a.PRODUCTION_VALUE_PER_UNIT_USD,

    -- Planned intervention scenario (deterministic calculation)
    ROUND(a.PLANNED_DOWNTIME_HRS * pl.DESIGN_CAPACITY_UNITS_HR * a.PRODUCTION_VALUE_PER_UNIT_USD, 2)
        AS ESTIMATED_PLANNED_PRODUCTION_LOSS_USD,
    ROUND(a.PLANNED_LABOR_COST_USD + a.PLANNED_PARTS_COST_USD
        + (a.PLANNED_DOWNTIME_HRS * pl.DESIGN_CAPACITY_UNITS_HR * a.PRODUCTION_VALUE_PER_UNIT_USD), 2)
        AS ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD,

    -- Unplanned failure scenario (deterministic calculation)
    ROUND(a.UNPLANNED_DOWNTIME_HRS * pl.DESIGN_CAPACITY_UNITS_HR * a.PRODUCTION_VALUE_PER_UNIT_USD, 2)
        AS ESTIMATED_UNPLANNED_PRODUCTION_LOSS_USD,
    ROUND(a.EMERGENCY_LABOR_COST_USD + a.EXPEDITED_PARTS_COST_USD + a.ESTIMATED_COLLATERAL_REPAIR_COST_USD
        + (a.UNPLANNED_DOWNTIME_HRS * pl.DESIGN_CAPACITY_UNITS_HR * a.PRODUCTION_VALUE_PER_UNIT_USD), 2)
        AS ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD,

    -- Derived: potential avoided impact (estimate, not guaranteed savings)
    ROUND(
        (a.EMERGENCY_LABOR_COST_USD + a.EXPEDITED_PARTS_COST_USD + a.ESTIMATED_COLLATERAL_REPAIR_COST_USD
         + (a.UNPLANNED_DOWNTIME_HRS * pl.DESIGN_CAPACITY_UNITS_HR * a.PRODUCTION_VALUE_PER_UNIT_USD))
        -
        (a.PLANNED_LABOR_COST_USD + a.PLANNED_PARTS_COST_USD
         + (a.PLANNED_DOWNTIME_HRS * pl.DESIGN_CAPACITY_UNITS_HR * a.PRODUCTION_VALUE_PER_UNIT_USD))
    , 2) AS ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD,

    -- Operational deltas
    ROUND(a.UNPLANNED_DOWNTIME_HRS - a.PLANNED_DOWNTIME_HRS, 1)
        AS ESTIMATED_AVOIDED_DOWNTIME_HRS,
    ROUND((a.UNPLANNED_DOWNTIME_HRS - a.PLANNED_DOWNTIME_HRS) * pl.DESIGN_CAPACITY_UNITS_HR, 0)
        AS ESTIMATED_AVOIDED_PRODUCTION_LOSS_UNITS

FROM OPSMIND.AI.IMPACT_ASSUMPTIONS a
CROSS JOIN OPSMIND.CORE.MACHINES m
JOIN OPSMIND.CORE.PRODUCTION_LINES pl ON m.LINE_ID = pl.LINE_ID
WHERE m.MACHINE_TYPE = a.MACHINE_TYPE;

-- ============================================================
-- 4. RBAC
-- ============================================================
-- IMPACT_ASSUMPTIONS: NO grant to OPSMIND_ANALYST.
--   This is governed internal configuration, readable only
--   by ACCOUNTADMIN (and OPSMIND_ADMIN via future-table grant).
--   The base RBAC script (02_roles_grants.sql) does not grant
--   ANALYST any future-table access on OPSMIND.AI, so no
--   workaround REVOKE is needed.
--
-- IMPACT_SCENARIOS: Grant SELECT to OPSMIND_ANALYST.
--   This is the intended read boundary for the investigation role.
-- ============================================================
GRANT SELECT ON VIEW OPSMIND.AI.IMPACT_SCENARIOS TO ROLE OPSMIND_ANALYST;
