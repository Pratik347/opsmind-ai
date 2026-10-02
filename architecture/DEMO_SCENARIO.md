# OpsMind AI — Demo Scenario: M-302 Bearing Degradation

## Scenario Overview

Machine M-302 is a CNC Milling Center on Production Line 3 at the Midwest Manufacturing plant. Over a 30-day period, it exhibits progressive bearing degradation that the OpsMind AI system detects, investigates, and recommends action on.

The scenario is deterministic: the same seed data always produces the same investigation path. The degradation is designed so that no single data point is conclusive — the agent must correlate structured telemetry, OEE trends, maintenance records, failure history, and unstructured SOP documents to reach the correct conclusion.

## Timeline

All dates are relative to a base date of **2026-09-01**.

| Period | Dates | Phase | M-302 Condition |
|--------|-------|-------|-----------------|
| Week 1 | Sep 01–07 | NORMAL | All metrics within baseline |
| Week 2 | Sep 08–14 | EARLY DEGRADATION | Subtle vibration increase, bearing temp rising slightly |
| Week 3 | Sep 15–21 | ANOMALY | Vibration exceeds warning threshold, OEE begins declining |
| Week 4 | Sep 22–27 | OEE IMPACT | Clear OEE drop, anomaly signals generated, investigation triggered |

## Comparison Assets

These machines provide the baseline context that makes M-302's degradation detectable:

| Machine | Line | Type | Behavior |
|---------|------|------|----------|
| M-301 | LINE-301 | CNC Milling Center | Normal — steady metrics throughout |
| M-302 | LINE-301 | CNC Milling Center | **Degrading — bearing issue** |
| M-303 | LINE-301 | CNC Milling Center | Normal — steady metrics throughout |
| M-201 | LINE-201 | Hydraulic Press | Normal — different machine type |
| M-401 | LINE-401 | Assembly Robot | Normal — different machine type |
| M-501 | LINE-501 | CNC Lathe | Normal with minor variation |

## Detailed Phase Progression

### Phase 1: NORMAL (Sep 01–07)

M-302 operates within established baselines, indistinguishable from peer machines.

| Metric | M-302 Value | Fleet Baseline |
|--------|-------------|----------------|
| Vibration (mm/s) | 2.0–2.8 | 1.8–3.0 |
| Bearing temperature (°C) | 42–48 | 40–50 |
| OEE (%) | 85–89 | 83–90 |
| Downtime (min/shift) | 0–15 | 0–20 |
| Quality (%) | 98.5–99.5 | 98.0–99.5 |

### Phase 2: EARLY DEGRADATION (Sep 08–14)

Bearing wear begins. Changes are within noise range individually but form a trend when viewed together.

| Metric | M-302 Trend | Change |
|--------|-------------|--------|
| Vibration (mm/s) | 2.8 → 3.8 | +35% from baseline mean |
| Bearing temperature (°C) | 48 → 55 | +15% from baseline mean |
| OEE (%) | 85 → 82 | Slight decline, within normal variation |
| Power consumption (kW) | Stable | No significant change yet |

**Key evidence planted:**
- A preventive maintenance task for M-302 bearing inspection was **scheduled for Sep 10 but is overdue** (status: overdue, not completed).
- M-302 had a bearing replacement 14 months ago (July 2025) — approaching typical bearing lifecycle for this machine type.

### Phase 3: ANOMALY (Sep 15–21)

Degradation accelerates. Individual metrics now clearly deviate from peers.

| Metric | M-302 Value | Fleet Baseline | Deviation |
|--------|-------------|----------------|-----------|
| Vibration (mm/s) | 4.0 → 5.5 | 1.8–3.0 | >80% above mean |
| Bearing temperature (°C) | 56 → 65 | 40–50 | >40% above mean |
| OEE (%) | 80 → 74 | 83–90 | Below fleet minimum |
| Quality (%) | 97.5 → 96.0 | 98.0–99.5 | Below fleet minimum |
| Downtime (min/shift) | 20 → 45 | 0–20 | 2× fleet maximum |

**Key evidence planted:**
- Anomaly signal generated on Sep 18: vibration_anomaly, severity: warning
- Anomaly signal generated on Sep 19: thermal_anomaly, severity: warning
- A similar CNC machine (M-303) had a bearing failure 8 months ago with similar vibration precursors

### Phase 4: OEE IMPACT (Sep 22–27)

Clear business impact. The system generates investigation-grade anomaly signals.

| Metric | M-302 Value | Fleet Baseline | Business Impact |
|--------|-------------|----------------|-----------------|
| Vibration (mm/s) | 5.8 → 7.2 | 1.8–3.0 | Exceeds SOP critical threshold (7.0) |
| Bearing temperature (°C) | 66 → 75 | 40–50 | Approaching SOP shutdown threshold (80) |
| OEE (%) | 72 → 65 | 83–90 | 20+ points below fleet average |
| Quality (%) | 95.5 → 93.0 | 98.0–99.5 | Defect rate tripled |
| Downtime (min/shift) | 50 → 80 | 0–20 | 4× fleet average |

**Key evidence planted:**
- Anomaly signal generated on Sep 23: oee_decline, severity: critical
- Anomaly signal generated on Sep 24: vibration_anomaly, severity: critical (threshold exceeded)
- Recommendation generated on Sep 25: bearing inspection and likely replacement

## Evidence the Agent Must Discover

The investigation should correlate these evidence sources:

### Structured Data Evidence (Cortex Analyst)

1. **Vibration trend** — SENSOR_READINGS where machine_id = 'M-302' and sensor_type = 'vibration', showing progressive increase over 4 weeks
2. **Bearing temperature trend** — SENSOR_READINGS where sensor_type = 'bearing_temp', showing correlated temperature rise
3. **OEE decline** — OEE_METRICS showing M-302's OEE dropping from ~87% to ~65% while peers remain stable at 83-90%
4. **Overdue maintenance** — MAINTENANCE_HISTORY showing the Sep 10 bearing inspection is overdue
5. **Previous bearing work** — MAINTENANCE_HISTORY showing bearing replacement in July 2025 (~14 months ago)
6. **Similar historical failure** — FAILURE_HISTORY showing M-303 bearing failure with similar vibration precursors
7. **Anomaly signals** — ANOMALY_SIGNALS showing escalating vibration and thermal warnings
8. **Comparison to peers** — M-301, M-303 running normally on the same line, ruling out line-level issues

### Unstructured Evidence (Cortex Search)

9. **Vibration threshold SOP** — Document defining vibration warning (4.5 mm/s) and critical (7.0 mm/s) thresholds for CNC milling equipment
10. **Bearing inspection procedure** — Document describing bearing inspection steps and indicators of wear
11. **Preventive maintenance schedule** — Document noting recommended bearing inspection interval (every 6 months) and replacement interval (12–18 months)
12. **Troubleshooting guide** — Document correlating vibration + temperature rise pattern with bearing degradation

## Expected Investigation Outcome

### Root Cause
Bearing degradation on Machine M-302, CNC Milling Center, Production Line 3.

### Evidence Chain
1. Vibration has increased 150%+ from baseline over 3 weeks (2.4 → 7.2 mm/s)
2. Bearing temperature has increased 55%+ from baseline (45 → 75°C)
3. OEE has declined from ~87% to ~65% (25% relative decline)
4. Scheduled bearing inspection on Sep 10 was not completed (overdue)
5. Previous bearing replacement was 14 months ago (approaching end of 12–18 month service life)
6. Similar machine M-303 experienced bearing failure with same precursor pattern
7. Current vibration exceeds SOP critical threshold of 7.0 mm/s
8. Bearing temperature approaching SOP shutdown threshold of 80°C

### Failure Risk
- **Direction**: Increasing — imminent unplanned failure if not addressed
- **Failure Risk Index**: HIGH — elevated vibration, thermal deviation, OEE degradation, and overdue maintenance all contribute (condition-based risk index, not a time-to-failure estimate)
- **Failure mode**: Bearing seizure or catastrophic bearing failure

### Business Impact
- **Current OEE loss**: ~22 percentage points (87% → 65%)
- **Production impact**: Reduced throughput on Line 3 (~25% capacity loss)
- **Quality impact**: Defect rate increased from ~1% to ~7%
- **Cost trajectory**: Planned bearing replacement (~$2,500 parts + labor) vs. catastrophic failure repair (~$15,000-25,000 + extended downtime)

### Recommended Action
1. **Immediate**: Schedule emergency bearing inspection on M-302 within 24 hours
2. **Likely follow-up**: Bearing replacement during planned maintenance window
3. **Preventive**: Review and enforce bearing inspection schedule compliance for all CNC milling equipment

### Governance
- Recommendation requires human approval (ADR-007)
- Emergency inspection work order created only after approval
- Full audit trail from anomaly detection through work order execution

## Test Assertions

The expected outcome contract (`tests/scenarios/m302_expected.json`) encodes semantic assertions rather than exact wording. The agent's response is correct if:

1. It identifies M-302 as the anomalous asset
2. It identifies bearing degradation (or bearing wear/bearing failure risk) as the root cause category
3. It cites vibration data as evidence
4. It cites temperature data as evidence
5. It cites OEE decline as evidence
6. It references the overdue maintenance or maintenance history
7. It references the SOP threshold or operational document
8. It indicates increasing/worsening risk direction
9. It indicates negative business impact (production loss, cost)
10. It recommends inspection and/or bearing replacement
11. It indicates human approval is required
