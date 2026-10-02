-- ============================================================
-- OpsMind AI — 13_demo_prepare.sql
-- Phase 5: Append-only demo fixture preparation.
--
-- Inserts a fresh demo recommendation (pending) for the live
-- approval workflow demonstration. Uses sequence-based unique
-- IDs to avoid collisions with seed data or test artifacts.
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
-- ============================================================

-- ID format: REC-D + MMDDHH24MISS = 16 chars (fits VARCHAR(20))
SET demo_rec_id = 'REC-D' || TO_CHAR(CURRENT_TIMESTAMP(), 'MMDDHH24MISS');

INSERT INTO OPSMIND.AI.RECOMMENDATIONS (
    RECOMMENDATION_ID, ANOMALY_ID, MACHINE_ID, GENERATED_AT,
    ACTION_TYPE, PRIORITY, DESCRIPTION, RATIONALE,
    EVIDENCE_SUMMARY, ESTIMATED_COST_USD, ESTIMATED_DOWNTIME_HRS,
    RISK_IF_DEFERRED, STATUS
) VALUES (
    $demo_rec_id,
    'ANM-003',
    'M-302',
    CURRENT_TIMESTAMP(),
    'inspect',
    'critical',
    'Schedule emergency bearing inspection on M-302 — elevated vibration and thermal readings detected in trailing 7-day window',
    'Failure risk index is HIGH (69.7/100). Vibration level score and thermal deviation score are both elevated. OEE has declined relative to baseline. Overdue bearing inspection compounds risk. Evidence from DOC-002 vibration thresholds and ISO 10816-3 adapted zones.',
    'Risk index: 69.7 HIGH | Vibration: 5.65 mm/s (Zone C) | Bearing temp: 63.2°C (above warning) | OEE: 72% vs 87% baseline | Bearing inspection overdue 15 days',
    2800,
    4,
    'Continued operation without inspection risks bearing seizure. Unplanned failure estimated cost $15,000-25,000 plus 2-3 days production loss per governed impact assumptions.',
    'pending'
);

-- ============================================================
-- 2. Verify the demo recommendation exists
-- ============================================================

SELECT RECOMMENDATION_ID, MACHINE_ID, PRIORITY, STATUS
FROM OPSMIND.AI.RECOMMENDATIONS
WHERE RECOMMENDATION_ID = $demo_rec_id;

-- ============================================================
-- Demo preparation complete.
-- The recommendation ID is printed above for use in the demo.
-- ============================================================
