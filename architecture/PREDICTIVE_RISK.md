# Equipment Failure Risk Index — Architecture

## What This Is

A condition-based **equipment failure risk index** (0–100) per machine,
indicating how strongly current operating evidence points toward elevated
failure risk. Uses a 7-day trailing lookback window over sensor telemetry,
OEE metrics, and maintenance status.

## What This Is NOT

- Not a failure **probability** or **likelihood**.
- Not a **time-to-failure** or remaining-useful-life estimate.
- Not a statistically **calibrated prediction**.
- Not an **ML model** output.

The risk index answers: "How strongly does current operating evidence
indicate elevated equipment failure risk?"

Phase 4A separately answers: "What is the estimated consequence if
failure occurs?" These are distinct concepts and are not combined.

## Why Risk Index, Not Probability

A calibrated failure probability requires sufficient positive/negative
training examples and historical base rates. The OpsMind synthetic
dataset has 1 bearing failure across 11 machines — grossly insufficient
for any probability model. A weighted risk index with documented,
threshold-grounded scoring is the technically honest methodology.

## Methodology

### Multi-Factor Weighted Risk Index

Five features, each scored 0–100, combined with documented weights.

### Feature Definitions

| Feature | Calculation | Lookback | Source | Justification |
|---------|-------------|----------|--------|---------------|
| F1: Vibration Level | Map 7-day avg to DOC-002 vibration zones (A→0, B→33, C→67, D→100) | 7 days | DOC-002 §3 | Primary condition indicator per ISO 10816-3 |
| F2: Vibration Trend | 7-day regression slope, normalized (≤0→0, ≥0.3→100) | 7 days | DOC-002 §4.1 | Accelerating vibration is a documented degradation indicator |
| F3: Thermal Deviation | Map 7-day avg bearing temp to DOC-002 thresholds (Normal→0, Warning→50, Critical→100) | 7 days | DOC-002 §6 | Independent bearing degradation confirmation |
| F4: OEE Degradation | Decline from first-week baseline (0%→0, 30%+→100) | 7-day recent vs first 7 days | OEE_METRICS | Operational consequence of deterioration |
| F5: Maintenance Overdue | Date-based derivation: overdue→50 + (days×2, cap 50) | Point-in-time | MAINTENANCE_HISTORY | Process risk factor |

### Weights

| Feature | Weight | Justification |
|---------|--------|---------------|
| F1 | 0.30 | Primary condition indicator per operational standards |
| F2 | 0.20 | Leading degradation indicator |
| F3 | 0.20 | Independent sensor confirmation |
| F4 | 0.15 | Operational consequence signal |
| F5 | 0.15 | Process risk factor |

**These weights are expert-defined operational heuristics, not
statistically calibrated.** There is insufficient training data to
optimize weights against historical failure outcomes.

### Risk Bands

| Band | Score | Meaning |
|------|-------|---------|
| LOW | 0–25 | Normal operating envelope |
| MEDIUM | 26–50 | Elevated — increased monitoring recommended |
| HIGH | 51–75 | Significant — plan intervention |
| CRITICAL | 76–100 | Severe — immediate action recommended |
| INCOMPLETE | NULL | Insufficient telemetry for reliable score |

**These thresholds are expert-defined operational categories, not
statistically derived boundaries.**

## Data Completeness

Missing telemetry does NOT default to zero risk. The view exposes:

| Column | Description |
|--------|-------------|
| AVAILABLE_FEATURE_COUNT | Number of features with data in the lookback window |
| EXPECTED_FEATURE_COUNT | Always 4 (vibration, bearing_temp, OEE, maintenance) |
| DATA_COMPLETENESS_PCT | Percentage of expected features available (0–100) |
| DATA_QUALITY | COMPLETE / PARTIAL / INSUFFICIENT |

If **both** critical sensor features (vibration and bearing temp) are
missing, RISK_SCORE is NULL and RISK_BAND is INCOMPLETE. Individual
missing features produce NULL feature scores and the composite is
renormalized over available features only.

## Point-in-Time Correctness

All features use data available as of AS_OF_DATE only.

**Maintenance overdue derivation:** Uses `SCHEDULED_DATE <= AS_OF_DATE
AND COMPLETED_DATE IS NULL AND STATUS NOT IN ('completed', 'cancelled')`.
The date-based check is primary; STATUS is a supplementary guard against
seed data quality issues (completed tasks with missing completion timestamps).

**Not used as features (would cause leakage):**
- FAILURE_HISTORY
- ANOMALY_SIGNALS
- RECOMMENDATIONS
- Future work orders

## Security Boundary

```
MACHINE_RISK_THRESHOLDS (governed config — not exposed to ANALYST)
  → deterministic SQL feature calculation
  → FAILURE_RISK_SCORES (read boundary — SELECT to OPSMIND_ANALYST)
    → Semantic View → Cortex Analyst → Cortex Agent
```

## Validation Results

| Machine | Score | Band | Data Quality | Key Factors |
|---------|-------|------|-------------|-------------|
| M-302 | 69.7 | HIGH | COMPLETE | Vibration 54.9, Trend 70.8, Thermal 61.1, OEE decline 94.7, Overdue 84.0 |
| M-101 | 2.3 | LOW | COMPLETE | Minor vibration trend only |
| M-303 | 0.0 | LOW | COMPLETE | No active risk factors (historical failure resolved) |
| All others | 0–0.4 | LOW | COMPLETE | Normal operating envelope |

## Limitations

1. Single degradation example — validated against M-302 only
2. Weights are expert-informed, not data-optimized
3. Composite bands are operational heuristics, not statistical thresholds
4. Static thresholds — no seasonal or load adjustment
5. Synthetic dataset — real-world performance unvalidated
6. No time-to-failure estimation

## Files

| File | Purpose |
|------|---------|
| `setup/sql/12_predictive_risk.sql` | Thresholds table, risk view, RBAC |
| `semantic/opsmind_operations.yaml` | FAILURE_RISK_SCORES in semantic model |
| `agent/opsmind_agent.yaml` | Risk assessment section in Agent response |
| `architecture/PREDICTIVE_RISK.md` | This document |
