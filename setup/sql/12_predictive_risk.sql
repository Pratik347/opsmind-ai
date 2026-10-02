-- ============================================================
-- OpsMind AI — 12_predictive_risk.sql
-- Phase 4C: Equipment Failure Risk Index
--
-- Computes a per-machine condition-based failure risk index
-- (0–100) using a multi-factor weighted model grounded in
-- operational threshold standards (DOC-002 / ISO 10816-3).
--
-- This is a RISK INDEX — not a probability, likelihood, or
-- time-to-failure estimate. It answers: "How strongly does
-- current operating evidence indicate elevated equipment
-- failure risk?" It does NOT answer: "How likely is failure?"
-- or "When will failure occur?"
--
-- Feature thresholds (vibration zones, temperature ranges) are
-- grounded in DOC-002 operational standards. Composite risk
-- bands and feature weights are expert-defined operational
-- heuristics — they are NOT statistically calibrated.
--
-- Architecture:
--   MACHINE_RISK_THRESHOLDS (governed config — not exposed)
--     → deterministic SQL feature calculation
--     → FAILURE_RISK_SCORES (read boundary — Semantic View)
--       → Cortex Analyst → Cortex Agent
--
-- Deployment: run AFTER scripts 00–11.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- ============================================================
-- 1. Machine Risk Thresholds (governed configuration)
--    Vibration zone boundaries and temperature thresholds per
--    machine type, sourced from DOC-002 (Vibration Analysis and
--    Threshold Guidelines, Rev 2.4, based on ISO 10816-3
--    adaptation for precision machining).
--
--    Not exposed to ANALYST or OPERATOR — governed internal
--    configuration following the IMPACT_ASSUMPTIONS pattern.
-- ============================================================

CREATE TABLE IF NOT EXISTS OPSMIND.AI.MACHINE_RISK_THRESHOLDS (
    THRESHOLD_ID                VARCHAR(20)  NOT NULL,
    MACHINE_TYPE                VARCHAR(50)  NOT NULL,
    COMPONENT                   VARCHAR(50)  NOT NULL DEFAULT 'bearing',

    -- Vibration zones (mm/s RMS) — DOC-002 §3
    VIB_ZONE_A_MAX              FLOAT        NOT NULL,
    VIB_ZONE_B_MAX              FLOAT        NOT NULL,
    VIB_ZONE_C_MAX              FLOAT        NOT NULL,

    -- Temperature thresholds (°C at bearing housing) — DOC-002 §6
    TEMP_NORMAL_MAX             FLOAT        NOT NULL,
    TEMP_WARNING_MAX            FLOAT        NOT NULL,
    TEMP_CRITICAL_MAX           FLOAT        NOT NULL,

    -- Provenance
    THRESHOLD_SOURCE            VARCHAR(100) NOT NULL DEFAULT 'DOC-002 Rev 2.4 / ISO 10816-3 adapted',
    THRESHOLD_VERSION           VARCHAR(10)  NOT NULL DEFAULT 'v1.0',

    CONSTRAINT PK_RISK_THRESHOLDS PRIMARY KEY (THRESHOLD_ID)
);

-- ============================================================
-- 2. Seed threshold data from DOC-002
-- ============================================================

TRUNCATE TABLE OPSMIND.AI.MACHINE_RISK_THRESHOLDS;

INSERT INTO OPSMIND.AI.MACHINE_RISK_THRESHOLDS (
    THRESHOLD_ID, MACHINE_TYPE, COMPONENT,
    VIB_ZONE_A_MAX, VIB_ZONE_B_MAX, VIB_ZONE_C_MAX,
    TEMP_NORMAL_MAX, TEMP_WARNING_MAX, TEMP_CRITICAL_MAX
) VALUES
('THR-001', 'CNC Milling Center', 'bearing', 2.8, 4.5, 7.0, 50, 65, 80),
('THR-002', 'CNC Lathe',          'bearing', 2.5, 4.0, 6.5, 48, 62, 75),
('THR-003', 'Hydraulic Press',     'bearing', 4.0, 7.0, 11.0, 55, 70, 85),
('THR-004', 'Assembly Robot',      'bearing', 1.2, 2.0, 3.0, 39, 48, 60);

-- ============================================================
-- 3. Failure Risk Scores View (read boundary)
--
-- Deterministic SQL view computing a 5-factor weighted risk
-- index for every machine as of the latest available data date.
--
-- Features (all use trailing LOOKBACK_WINDOW_DAYS = 7):
--   F1: Vibration Level Score (0–100)
--   F2: Vibration Trend Score (0–100)
--   F3: Thermal Deviation Score (0–100)
--   F4: OEE Degradation Score (0–100)
--   F5: Maintenance Overdue Score (0–100)
--
-- Weights: F1=0.30, F2=0.20, F3=0.20, F4=0.15, F5=0.15
-- These weights are expert-defined operational heuristics, not
-- statistically calibrated.
--
-- Risk bands (LOW/MEDIUM/HIGH/CRITICAL) are expert-defined
-- operational categories, not statistically derived thresholds.
--
-- Missing data: If a critical sensor feature has no data in the
-- lookback window, the score is NULL (not zero). A machine with
-- incomplete telemetry is marked INCOMPLETE and its risk score
-- should be treated as reduced-confidence.
--
-- Point-in-time: all features use data <= AS_OF_DATE only.
-- Maintenance overdue is derived from SCHEDULED_DATE and
-- COMPLETED_DATE (date-based derivation), not mutable STATUS,
-- for point-in-time correctness.
-- ============================================================

CREATE OR REPLACE VIEW OPSMIND.AI.FAILURE_RISK_SCORES AS

WITH as_of AS (
    SELECT MAX(READING_TS::DATE) AS AS_OF_DATE
    FROM OPSMIND.CORE.SENSOR_READINGS
),

-- Trailing 7-day vibration statistics per machine
vib_stats AS (
    SELECT
        S.MACHINE_ID,
        AVG(S.VALUE) AS AVG_VIBRATION,
        REGR_SLOPE(S.VALUE, DATEDIFF('day', ao.AS_OF_DATE - 6, S.READING_TS::DATE)) AS VIB_SLOPE,
        1 AS HAS_VIBRATION
    FROM OPSMIND.CORE.SENSOR_READINGS S
    CROSS JOIN as_of ao
    WHERE S.SENSOR_TYPE = 'vibration'
      AND S.READING_TS::DATE BETWEEN ao.AS_OF_DATE - 6 AND ao.AS_OF_DATE
    GROUP BY S.MACHINE_ID
),

-- Trailing 7-day bearing temperature statistics per machine
temp_stats AS (
    SELECT
        S.MACHINE_ID,
        AVG(S.VALUE) AS AVG_BEARING_TEMP,
        1 AS HAS_BEARING_TEMP
    FROM OPSMIND.CORE.SENSOR_READINGS S
    CROSS JOIN as_of ao
    WHERE S.SENSOR_TYPE = 'bearing_temp'
      AND S.READING_TS::DATE BETWEEN ao.AS_OF_DATE - 6 AND ao.AS_OF_DATE
    GROUP BY S.MACHINE_ID
),

-- Trailing 7-day OEE average per machine
oee_recent AS (
    SELECT
        O.MACHINE_ID,
        AVG(O.OEE_PCT) AS RECENT_OEE,
        1 AS HAS_OEE
    FROM OPSMIND.CORE.OEE_METRICS O
    CROSS JOIN as_of ao
    WHERE O.METRIC_DATE BETWEEN ao.AS_OF_DATE - 6 AND ao.AS_OF_DATE
    GROUP BY O.MACHINE_ID
),

-- Baseline OEE: first 7 days of data per machine
oee_baseline AS (
    SELECT
        O.MACHINE_ID,
        AVG(O.OEE_PCT) AS BASELINE_OEE
    FROM OPSMIND.CORE.OEE_METRICS O
    JOIN (SELECT MACHINE_ID, MIN(METRIC_DATE) AS FIRST_DATE
          FROM OPSMIND.CORE.OEE_METRICS GROUP BY MACHINE_ID) FD
      ON O.MACHINE_ID = FD.MACHINE_ID
    WHERE O.METRIC_DATE BETWEEN FD.FIRST_DATE AND FD.FIRST_DATE + 6
    GROUP BY O.MACHINE_ID
),

-- Maintenance overdue: point-in-time derivation from dates.
-- A task is overdue if SCHEDULED_DATE <= AS_OF_DATE AND
-- COMPLETED_DATE IS NULL AND STATUS is not already closed
-- ('completed' or 'cancelled'). The STATUS check handles the
-- edge case where COMPLETED_DATE is NULL but the task was
-- marked completed without a timestamp (seed data quality).
-- The date-based derivation is the primary control; STATUS is
-- a supplementary guard against missing completion timestamps.
maint_overdue AS (
    SELECT
        MH.MACHINE_ID,
        MAX(CASE WHEN MH.COMPLETED_DATE IS NULL
                  AND MH.STATUS NOT IN ('completed', 'cancelled')
                  AND MH.SCHEDULED_DATE::DATE <= ao.AS_OF_DATE
             THEN 1 ELSE 0 END) AS IS_OVERDUE,
        MAX(CASE WHEN MH.COMPLETED_DATE IS NULL
                  AND MH.STATUS NOT IN ('completed', 'cancelled')
                  AND MH.SCHEDULED_DATE::DATE <= ao.AS_OF_DATE
             THEN DATEDIFF('day', MH.SCHEDULED_DATE::DATE, ao.AS_OF_DATE)
             ELSE 0 END) AS DAYS_OVERDUE
    FROM OPSMIND.CORE.MAINTENANCE_HISTORY MH
    CROSS JOIN as_of ao
    GROUP BY MH.MACHINE_ID
),

-- Feature scoring with NULL propagation for missing data
scored AS (
    SELECT
        M.MACHINE_ID,
        M.MACHINE_NAME,
        M.MACHINE_TYPE,
        M.CRITICALITY_RATING,
        M.LINE_ID,
        ao.AS_OF_DATE,

        -- Data completeness metadata
        COALESCE(VS.HAS_VIBRATION, 0) AS HAS_VIBRATION,
        COALESCE(TS.HAS_BEARING_TEMP, 0) AS HAS_BEARING_TEMP,
        COALESCE(OR2.HAS_OEE, 0) AS HAS_OEE,
        -- Maintenance data is always available (0 records = not overdue)
        1 AS HAS_MAINTENANCE,

        -- Raw values for explainability (NULL if missing)
        ROUND(VS.AVG_VIBRATION, 2) AS LATEST_VIBRATION,
        ROUND(VS.VIB_SLOPE, 4) AS VIBRATION_SLOPE,
        ROUND(TS.AVG_BEARING_TEMP, 1) AS LATEST_BEARING_TEMP,
        ROUND(OR2.RECENT_OEE, 1) AS LATEST_OEE,
        ROUND(OB.BASELINE_OEE, 1) AS BASELINE_OEE,
        COALESCE(MO.IS_OVERDUE, 0) AS IS_OVERDUE,
        COALESCE(MO.DAYS_OVERDUE, 0) AS DAYS_OVERDUE,

        -- F1: Vibration Level Score (NULL if no vibration data)
        CASE WHEN VS.HAS_VIBRATION IS NULL THEN NULL
        ELSE ROUND(LEAST(100, GREATEST(0,
            CASE
                WHEN VS.AVG_VIBRATION <= T.VIB_ZONE_A_MAX THEN 0
                WHEN VS.AVG_VIBRATION <= T.VIB_ZONE_B_MAX THEN
                    33.0 * (VS.AVG_VIBRATION - T.VIB_ZONE_A_MAX)
                         / NULLIF(T.VIB_ZONE_B_MAX - T.VIB_ZONE_A_MAX, 0)
                WHEN VS.AVG_VIBRATION <= T.VIB_ZONE_C_MAX THEN
                    33.0 + 34.0 * (VS.AVG_VIBRATION - T.VIB_ZONE_B_MAX)
                                 / NULLIF(T.VIB_ZONE_C_MAX - T.VIB_ZONE_B_MAX, 0)
                ELSE 67.0 + 33.0 * LEAST(1.0,
                    (VS.AVG_VIBRATION - T.VIB_ZONE_C_MAX)
                    / NULLIF(T.VIB_ZONE_C_MAX - T.VIB_ZONE_B_MAX, 0))
            END
        )), 1) END AS VIBRATION_LEVEL_SCORE,

        -- F2: Vibration Trend Score (NULL if no vibration data)
        CASE WHEN VS.HAS_VIBRATION IS NULL THEN NULL
        ELSE ROUND(LEAST(100, GREATEST(0,
            CASE WHEN VS.VIB_SLOPE <= 0 THEN 0
                 ELSE (VS.VIB_SLOPE / 0.3) * 100 END
        )), 1) END AS VIBRATION_TREND_SCORE,

        -- F3: Thermal Deviation Score (NULL if no bearing temp data)
        CASE WHEN TS.HAS_BEARING_TEMP IS NULL THEN NULL
        ELSE ROUND(LEAST(100, GREATEST(0,
            CASE
                WHEN TS.AVG_BEARING_TEMP <= T.TEMP_NORMAL_MAX THEN 0
                WHEN TS.AVG_BEARING_TEMP <= T.TEMP_WARNING_MAX THEN
                    50.0 * (TS.AVG_BEARING_TEMP - T.TEMP_NORMAL_MAX)
                         / NULLIF(T.TEMP_WARNING_MAX - T.TEMP_NORMAL_MAX, 0)
                WHEN TS.AVG_BEARING_TEMP <= T.TEMP_CRITICAL_MAX THEN
                    50.0 + 50.0 * (TS.AVG_BEARING_TEMP - T.TEMP_WARNING_MAX)
                                 / NULLIF(T.TEMP_CRITICAL_MAX - T.TEMP_WARNING_MAX, 0)
                ELSE 100
            END
        )), 1) END AS THERMAL_DEVIATION_SCORE,

        -- F4: OEE Degradation Score (NULL if no OEE data)
        CASE WHEN OR2.HAS_OEE IS NULL THEN NULL
        ELSE ROUND(LEAST(100, GREATEST(0,
            CASE
                WHEN OB.BASELINE_OEE IS NULL OR OB.BASELINE_OEE = 0 THEN 0
                WHEN OR2.RECENT_OEE >= OB.BASELINE_OEE THEN 0
                ELSE ((OB.BASELINE_OEE - OR2.RECENT_OEE) / 30.0) * 100
            END
        )), 1) END AS OEE_DEGRADATION_SCORE,

        -- F5: Maintenance Overdue Score (always available)
        ROUND(LEAST(100, GREATEST(0,
            CASE WHEN COALESCE(MO.IS_OVERDUE, 0) = 0 THEN 0
                 ELSE 50.0 + LEAST(50.0, COALESCE(MO.DAYS_OVERDUE, 0) * 2.0) END
        )), 1) AS MAINTENANCE_OVERDUE_SCORE,

        -- Provenance
        T.THRESHOLD_SOURCE, T.THRESHOLD_VERSION

    FROM OPSMIND.CORE.MACHINES M
    CROSS JOIN as_of ao
    JOIN OPSMIND.AI.MACHINE_RISK_THRESHOLDS T ON M.MACHINE_TYPE = T.MACHINE_TYPE
    LEFT JOIN vib_stats VS ON M.MACHINE_ID = VS.MACHINE_ID
    LEFT JOIN temp_stats TS ON M.MACHINE_ID = TS.MACHINE_ID
    LEFT JOIN oee_recent OR2 ON M.MACHINE_ID = OR2.MACHINE_ID
    LEFT JOIN oee_baseline OB ON M.MACHINE_ID = OB.MACHINE_ID
    LEFT JOIN maint_overdue MO ON M.MACHINE_ID = MO.MACHINE_ID
),

-- Composite score with data-completeness-aware calculation
composited AS (
    SELECT
        *,
        -- Count available and expected features
        (HAS_VIBRATION + HAS_BEARING_TEMP + HAS_OEE + HAS_MAINTENANCE) AS AVAILABLE_FEATURE_COUNT,
        4 AS EXPECTED_FEATURE_COUNT,
        ROUND((HAS_VIBRATION + HAS_BEARING_TEMP + HAS_OEE + HAS_MAINTENANCE) / 4.0 * 100, 0) AS DATA_COMPLETENESS_PCT,

        -- Composite score: weighted average over AVAILABLE features only
        -- If vibration or bearing temp is missing, the score is NULL (incomplete)
        CASE
            -- Both critical sensor features missing → cannot produce reliable score
            WHEN HAS_VIBRATION = 0 AND HAS_BEARING_TEMP = 0 THEN NULL
            ELSE ROUND(
                -- Numerator: sum of (weight × score) for available features
                (CASE WHEN VIBRATION_LEVEL_SCORE IS NOT NULL THEN 0.30 * VIBRATION_LEVEL_SCORE ELSE 0 END)
              + (CASE WHEN VIBRATION_TREND_SCORE IS NOT NULL THEN 0.20 * VIBRATION_TREND_SCORE ELSE 0 END)
              + (CASE WHEN THERMAL_DEVIATION_SCORE IS NOT NULL THEN 0.20 * THERMAL_DEVIATION_SCORE ELSE 0 END)
              + (CASE WHEN OEE_DEGRADATION_SCORE IS NOT NULL THEN 0.15 * OEE_DEGRADATION_SCORE ELSE 0 END)
              + 0.15 * MAINTENANCE_OVERDUE_SCORE
            ) / (
                -- Denominator: sum of weights for available features (renormalize)
                (CASE WHEN VIBRATION_LEVEL_SCORE IS NOT NULL THEN 0.30 ELSE 0 END)
              + (CASE WHEN VIBRATION_TREND_SCORE IS NOT NULL THEN 0.20 ELSE 0 END)
              + (CASE WHEN THERMAL_DEVIATION_SCORE IS NOT NULL THEN 0.20 ELSE 0 END)
              + (CASE WHEN OEE_DEGRADATION_SCORE IS NOT NULL THEN 0.15 ELSE 0 END)
              + 0.15
            ), 1)
        END AS RISK_SCORE

    FROM scored
)

SELECT
    MACHINE_ID, MACHINE_NAME, MACHINE_TYPE, CRITICALITY_RATING, LINE_ID,
    AS_OF_DATE,
    7 AS LOOKBACK_WINDOW_DAYS,

    RISK_SCORE,

    -- Risk band (NULL score → INCOMPLETE)
    CASE
        WHEN RISK_SCORE IS NULL THEN 'INCOMPLETE'
        WHEN RISK_SCORE >= 76 THEN 'CRITICAL'
        WHEN RISK_SCORE >= 51 THEN 'HIGH'
        WHEN RISK_SCORE >= 26 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS RISK_BAND,

    -- Data completeness metadata
    AVAILABLE_FEATURE_COUNT,
    EXPECTED_FEATURE_COUNT,
    DATA_COMPLETENESS_PCT,
    CASE
        WHEN HAS_VIBRATION = 0 AND HAS_BEARING_TEMP = 0 THEN 'INSUFFICIENT'
        WHEN DATA_COMPLETENESS_PCT < 100 THEN 'PARTIAL'
        ELSE 'COMPLETE'
    END AS DATA_QUALITY,

    -- Individual feature scores (NULL if data unavailable)
    VIBRATION_LEVEL_SCORE, VIBRATION_TREND_SCORE,
    THERMAL_DEVIATION_SCORE, OEE_DEGRADATION_SCORE,
    MAINTENANCE_OVERDUE_SCORE,

    -- Raw values for context (NULL if data unavailable)
    LATEST_VIBRATION, VIBRATION_SLOPE,
    LATEST_BEARING_TEMP, LATEST_OEE, BASELINE_OEE,
    IS_OVERDUE, DAYS_OVERDUE,

    -- Provenance
    'v1.0' AS METHOD_VERSION,
    THRESHOLD_SOURCE

FROM composited;

-- ============================================================
-- 4. RBAC
-- ============================================================
GRANT SELECT ON VIEW OPSMIND.AI.FAILURE_RISK_SCORES TO ROLE OPSMIND_ANALYST;

-- ============================================================
-- Phase 4C deployment complete.
-- ============================================================
