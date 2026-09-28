# Vibration Analysis and Threshold Guidelines

**Document ID:** DOC-VIB-002
**Revision:** 2.4
**Effective Date:** 2026-05-20
**Applicable Equipment:** CNC Milling Centers, CNC Lathes, Hydraulic Presses
**Applicable Components:** Bearings, spindles, motors

## 1. Purpose

This document establishes vibration measurement standards and threshold values for manufacturing equipment. These thresholds guide condition-based maintenance decisions and anomaly detection.

## 2. Vibration Measurement Standards

All vibration measurements are taken as velocity in mm/s RMS (root mean square) at the bearing housing, perpendicular to the shaft axis, under steady-state operating conditions.

Measurements should be taken:

- At the same measurement point each time (marked on the machine)
- After at least 20 minutes of stable operation
- Under representative load conditions (not idle, not peak transient)
- Using calibrated equipment with valid certification

## 3. Threshold Values by Equipment Type

### 3.1 CNC Milling Centers

| Zone | Vibration (mm/s RMS) | Condition | Action |
|------|---------------------|-----------|--------|
| A — Good | 0.0 – 2.8 | Normal operation | Continue standard monitoring |
| B — Acceptable | 2.8 – 4.5 | Acceptable for continued operation | Increase monitoring frequency |
| C — Warning | 4.5 – 7.0 | Unsatisfactory for sustained operation | Plan corrective action within 7 days |
| D — Critical | > 7.0 | Damage likely occurring | **Immediate action required — remove from production** |

These thresholds are based on ISO 10816-3 guidelines adapted for precision CNC machining applications. The tighter thresholds in zones A and B reflect the precision requirements of CNC milling.

### 3.2 CNC Lathes

| Zone | Vibration (mm/s RMS) | Condition | Action |
|------|---------------------|-----------|--------|
| A — Good | 0.0 – 2.5 | Normal operation | Continue standard monitoring |
| B — Acceptable | 2.5 – 4.0 | Acceptable for continued operation | Increase monitoring frequency |
| C — Warning | 4.0 – 6.5 | Unsatisfactory for sustained operation | Plan corrective action within 7 days |
| D — Critical | > 6.5 | Damage likely occurring | **Immediate action required** |

### 3.3 Hydraulic Presses

| Zone | Vibration (mm/s RMS) | Condition | Action |
|------|---------------------|-----------|--------|
| A — Good | 0.0 – 4.0 | Normal operation | Continue standard monitoring |
| B — Acceptable | 4.0 – 7.0 | Acceptable for continued operation | Increase monitoring frequency |
| C — Warning | 7.0 – 11.0 | Unsatisfactory for sustained operation | Plan corrective action |
| D — Critical | > 11.0 | Damage likely occurring | **Immediate action required** |

## 4. Trend Analysis Guidelines

Individual readings should always be interpreted in context of the trend. Key trend indicators:

### 4.1 Rate of Change

- **Gradual increase** (weeks to months): Typical of normal wear progression. Schedule maintenance proactively.
- **Accelerating increase** (days to weeks): Indicates active degradation. Investigate immediately. Common causes include bearing fatigue, lubrication failure, or contamination ingress.
- **Step change** (sudden jump): May indicate a discrete event such as impact damage, sudden misalignment, or component fracture. Investigate immediately.

### 4.2 Correlation with Other Parameters

Vibration increases that correlate with one or more of the following indicate a higher probability of bearing-related root cause:

- **Bearing temperature increase** — Simultaneous vibration and temperature rise is a strong indicator of bearing degradation.
- **Power consumption increase** — Higher friction from worn bearings increases motor load.
- **Quality degradation** — Surface finish or dimensional accuracy decline can result from increased spindle runout caused by bearing wear.
- **Acoustic changes** — New or changing noise patterns from the bearing area.

When vibration increase correlates with bearing temperature increase, the probability of bearing degradation is elevated and the maintenance response should be accelerated regardless of whether the vibration threshold alone has been reached.

## 5. Bearing-Specific Vibration Signatures

| Frequency Pattern | Likely Cause |
|---|---|
| BPFO (ball pass frequency, outer race) | Outer race defect |
| BPFI (ball pass frequency, inner race) | Inner race defect |
| BSF (ball spin frequency) | Rolling element defect |
| FTF (fundamental train frequency) | Cage defect |
| Broadband increase | General wear, lubrication issues |

Frequency analysis requires specialized equipment and training. If broadband vibration increase is observed alongside temperature increase, general bearing wear or lubrication failure is the most probable cause. Detailed frequency analysis can confirm the specific defect type but should not delay maintenance action when overall vibration exceeds warning thresholds.

## 6. Temperature Thresholds

Bearing operating temperature thresholds (measured at the bearing housing):

| Equipment Type | Normal (°C) | Warning (°C) | Critical (°C) | Shutdown (°C) |
|---|---|---|---|---|
| CNC Milling Center | 35–50 | 50–65 | 65–80 | >80 |
| CNC Lathe | 35–48 | 48–62 | 62–75 | >75 |
| Hydraulic Press | 40–55 | 55–70 | 70–85 | >85 |

These thresholds assume standard ambient temperature of 20–25°C. Adjust upward by 5°C for facilities operating above 30°C ambient.

## 7. Reporting

All vibration readings exceeding Zone B thresholds must be reported to the maintenance supervisor within the same shift. Zone C and D readings require immediate notification and entry into the maintenance management system as a priority work request.
