-- ============================================================
-- OpsMind AI — 13_demo_prepare.sql
-- Phase 5: Append-only demo fixture preparation.
--
-- Inserts a fresh demo recommendation (pending) for the live
-- approval workflow demonstration. Uses sequence-based unique
-- IDs to avoid collisions with seed data or test artifacts.
--
-- Cost, downtime, and risk-if-deferred values are derived from
-- the authoritative governed impact engine (AI.IMPACT_SCENARIOS)
-- rather than manually authored constants.
--
-- This script is APPEND-ONLY: no DELETE, TRUNCATE, or UPDATE.
-- Safe to run multiple times (each run creates a new unique
-- recommendation).
--
-- Deployment: run AFTER scripts 00–12 and 14.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- ============================================================
-- 1. Insert a fresh pending recommendation for M-302
--    Uses a timestamp-based ID to guarantee uniqueness.
--    Cost/downtime derived from IMPACT_SCENARIOS (IMP-001).
-- ============================================================

-- ID format: REC-D + MMDDHH24MISS = 16 chars (fits VARCHAR(20))
SET demo_rec_id = 'REC-D' || TO_CHAR(CURRENT_TIMESTAMP(), 'MMDDHH24MISS');

INSERT INTO OPSMIND.AI.RECOMMENDATIONS (
    RECOMMENDATION_ID, ANOMALY_ID, MACHINE_ID, GENERATED_AT,
    ACTION_TYPE, PRIORITY, DESCRIPTION, RATIONALE,
    EVIDENCE_SUMMARY, ESTIMATED_COST_USD, ESTIMATED_DOWNTIME_HRS,
    RISK_IF_DEFERRED, STATUS
)
SELECT
    $demo_rec_id,
    'ANM-003',
    'M-302',
    CURRENT_TIMESTAMP(),
    'inspect',
    'critical',
    'Schedule expedited spindle-bearing inspection on M-302 during next planned maintenance window — correlated vibration, thermal, and OEE evidence indicates progressive bearing degradation',
    'Equipment Failure Risk Index is 69.7 (HIGH band). Five contributing risk factors are elevated: vibration level score 54.9 (Zone C per DOC-002 / ISO 10816-3 adapted thresholds), vibration trend score 70.8 (actively rising), thermal deviation score 61.1 (bearing temperature above warning threshold per DOC-002), OEE degradation score 94.7 (sharp decline from baseline), maintenance overdue score 84.0 (bearing inspection overdue). The risk index is a condition-based composite, not a calibrated failure probability or time-to-failure estimate.',
    'Risk index: 69.7 HIGH | Vibration: 5.65 mm/s Zone C | Trend slope: +0.18 mm/s/day rising | Bearing temp: 68.3C (critical band per DOC-002) | OEE: 60.3% vs 88.7% baseline | Bearing inspection overdue | Peer failure pattern match (M-301)',
    -- Direct maintenance cost: labor + parts from governed impact assumptions
    SC.PLANNED_LABOR_COST_USD + SC.PLANNED_PARTS_COST_USD,
    SC.PLANNED_DOWNTIME_HRS,
    -- Risk-if-deferred references authoritative unplanned failure scenario
    'Unplanned failure scenario: $' || TO_CHAR(SC.ESTIMATED_TOTAL_UNPLANNED_FAILURE_USD, '999,999')
        || ' total impact (' || SC.UNPLANNED_DOWNTIME_HRS || 'h downtime)'
        || ' vs planned intervention: $' || TO_CHAR(SC.ESTIMATED_TOTAL_PLANNED_INTERVENTION_USD, '999,999')
        || ' (' || SC.PLANNED_DOWNTIME_HRS || 'h downtime).'
        || ' Potential avoided impact: $' || TO_CHAR(SC.ESTIMATED_POTENTIAL_AVOIDED_IMPACT_USD, '999,999')
        || '. Per DOC-002: Zone C vibration with correlated temperature rise requires corrective action within 7 days.'
        || ' Values from governed impact engine (' || SC.ASSUMPTION_ID || ').',
    'pending'
FROM OPSMIND.AI.IMPACT_SCENARIOS SC
WHERE SC.MACHINE_ID = 'M-302'
  AND SC.FAILURE_COMPONENT = 'bearing';

-- ============================================================
-- 2. Verify the demo recommendation exists
-- ============================================================

SELECT RECOMMENDATION_ID, MACHINE_ID, PRIORITY, STATUS,
    ESTIMATED_COST_USD, ESTIMATED_DOWNTIME_HRS
FROM OPSMIND.AI.RECOMMENDATIONS
WHERE RECOMMENDATION_ID = $demo_rec_id;

-- ============================================================
-- Demo preparation complete.
-- The recommendation ID is printed above for use in the demo.
-- ============================================================
