-- ============================================================
-- OpsMind AI — 05b_load_document_content.sql
-- Populate OPERATIONAL_DOCUMENTS.CONTENT from inline Markdown.
--
-- The CSV seed file (operational_documents.csv) contains
-- placeholder content references. This script replaces them
-- with the full document text for reproducible deployment.
-- Run AFTER 05_load_seed_data.sql.
--
-- Source of truth: setup/data/documents/*.md
-- This SQL version ensures the database content matches
-- the version-controlled Markdown files exactly.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- DOC-001: Bearing Inspection Standard Operating Procedure
UPDATE OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS
SET CONTENT = $$# Bearing Inspection Standard Operating Procedure

**Document ID:** SOP-BRG-001
**Revision:** 3.1
**Effective Date:** 2026-06-15
**Applicable Equipment:** CNC Milling Centers, CNC Lathes
**Applicable Components:** Spindle bearings, support bearings

## 1. Purpose

This procedure defines the standard process for inspecting bearings on CNC machining equipment. Regular bearing inspection is critical to preventing unplanned downtime and ensuring machining precision.

## 2. Inspection Frequency

| Bearing Type | Inspection Interval | Replacement Interval |
|---|---|---|
| Spindle bearing (angular contact) | Every 6 months | 12-18 months depending on operating conditions |
| Support bearing (deep groove) | Every 12 months | 24-36 months |
| Linear guide bearing | Every 6 months | 18-24 months |

Inspection intervals may be shortened if the machine operates in heavy-duty cycles (>16 hours/day) or in environments with elevated particulate levels.

## 3. Pre-Inspection Checks

Before beginning a physical inspection, review the following data:

1. **Vibration trend data** - Compare current readings against the machine's baseline. A sustained increase of 25% or more above the 30-day rolling average warrants immediate inspection regardless of the scheduled interval.
2. **Bearing temperature trend** - Operating temperatures consistently above 60C for spindle bearings on CNC milling equipment indicate potential lubrication breakdown or mechanical wear.
3. **Maintenance history** - Verify the date of the last bearing service. Bearings approaching the upper end of their replacement interval (e.g., 14+ months for spindle bearings) should be inspected with replacement readiness.
4. **Production quality data** - Increasing surface finish defects or dimensional variation can indicate bearing-related spindle runout.

## 4. Inspection Procedure

### 4.1 Visual Inspection

- Remove access covers and inspect for visible contamination, discoloration, or lubricant leakage around bearing housings.
- Check seal integrity. Damaged seals accelerate bearing degradation.

### 4.2 Vibration Measurement

Using a calibrated vibration analyzer:

1. Mount the accelerometer on the bearing housing at the measurement point marked on the machine.
2. Record vibration velocity (mm/s RMS) at each measurement point.
3. Compare against thresholds defined in the Vibration Analysis Guidelines (DOC-VIB-002).
4. Record measurements in the maintenance management system.

### 4.3 Temperature Measurement

1. Measure bearing housing temperature at steady-state operating conditions (minimum 20 minutes after startup).
2. Record the ambient temperature for reference.
3. Bearing housing temperature should not exceed 40C above ambient for standard operation.

## 5. Disposition Criteria

| Finding | Action |
|---|---|
| All measurements within baseline | Return to service, schedule next inspection per interval |
| Vibration 25-75% above baseline, temperature normal | Increase monitoring frequency to weekly; schedule replacement within 30 days |
| Vibration >75% above baseline OR temperature >60C | Schedule replacement within 7 days; reduce machine load if possible |
| Vibration >150% above baseline OR temperature >70C | **Remove from production immediately**; emergency replacement required |
| Visible damage, contamination, or seal failure | Replace bearing; investigate contamination source |

## 6. Documentation

Record all inspection results in the maintenance management system.

## 7. Safety

- Lock out / tag out (LOTO) the machine before any physical inspection.
- Wear appropriate PPE including safety glasses and hearing protection.
- Allow bearings to cool to <50C before direct contact inspection.$$
WHERE DOC_ID = 'DOC-001';

-- DOC-002: Vibration Analysis and Threshold Guidelines
UPDATE OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS
SET CONTENT = $$# Vibration Analysis and Threshold Guidelines

**Document ID:** DOC-VIB-002
**Revision:** 2.4
**Effective Date:** 2026-05-20
**Applicable Equipment:** CNC Milling Centers, CNC Lathes, Hydraulic Presses

## 2. Vibration Measurement Standards

All vibration measurements are taken as velocity in mm/s RMS at the bearing housing, perpendicular to the shaft axis, under steady-state operating conditions.

## 3. Threshold Values by Equipment Type

### 3.1 CNC Milling Centers

| Zone | Vibration (mm/s RMS) | Condition | Action |
|------|---------------------|-----------|--------|
| A - Good | 0.0 - 2.8 | Normal operation | Continue standard monitoring |
| B - Acceptable | 2.8 - 4.5 | Acceptable for continued operation | Increase monitoring frequency |
| C - Warning | 4.5 - 7.0 | Unsatisfactory for sustained operation | Plan corrective action within 7 days |
| D - Critical | > 7.0 | Damage likely occurring | **Immediate action required - remove from production** |

These thresholds are based on ISO 10816-3 guidelines adapted for precision CNC machining applications.

### 3.2 CNC Lathes

| Zone | Vibration (mm/s RMS) | Condition | Action |
|------|---------------------|-----------|--------|
| A - Good | 0.0 - 2.5 | Normal operation | Continue standard monitoring |
| B - Acceptable | 2.5 - 4.0 | Acceptable for continued operation | Increase monitoring frequency |
| C - Warning | 4.0 - 6.5 | Unsatisfactory for sustained operation | Plan corrective action within 7 days |
| D - Critical | > 6.5 | Damage likely occurring | **Immediate action required** |

## 4. Trend Analysis Guidelines

### 4.1 Rate of Change

- **Gradual increase** (weeks to months): Typical of normal wear progression. Schedule maintenance proactively.
- **Accelerating increase** (days to weeks): Indicates active degradation. Investigate immediately. Common causes include bearing fatigue, lubrication failure, or contamination ingress.
- **Step change** (sudden jump): May indicate impact damage, sudden misalignment, or component fracture.

### 4.2 Correlation with Other Parameters

Vibration increases that correlate with one or more of the following indicate a higher probability of bearing-related root cause:

- **Bearing temperature increase** - Simultaneous vibration and temperature rise is a strong indicator of bearing degradation.
- **Power consumption increase** - Higher friction from worn bearings increases motor load.
- **Quality degradation** - Surface finish or dimensional accuracy decline can result from increased spindle runout caused by bearing wear.

When vibration increase correlates with bearing temperature increase, the probability of bearing degradation is elevated and the maintenance response should be accelerated regardless of whether the vibration threshold alone has been reached.

## 6. Temperature Thresholds

Bearing operating temperature thresholds (measured at the bearing housing):

| Equipment Type | Normal (C) | Warning (C) | Critical (C) | Shutdown (C) |
|---|---|---|---|---|
| CNC Milling Center | 35-50 | 50-65 | 65-80 | >80 |
| CNC Lathe | 35-48 | 48-62 | 62-75 | >75 |
| Hydraulic Press | 40-55 | 55-70 | 70-85 | >85 |

## 7. Reporting

All vibration readings exceeding Zone B thresholds must be reported to the maintenance supervisor within the same shift. Zone C and D readings require immediate notification.$$
WHERE DOC_ID = 'DOC-002';

-- DOC-003: Preventive Maintenance Schedule and Procedures
UPDATE OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS
SET CONTENT = $$# Preventive Maintenance Schedule and Procedures

**Document ID:** SOP-PM-003
**Revision:** 4.0
**Effective Date:** 2026-07-01
**Applicable Equipment:** All manufacturing equipment

## 2. Maintenance Philosophy

Our preventive maintenance program follows a tiered approach:

1. **Time-based PM** - Scheduled at fixed intervals based on calendar time or operating hours.
2. **Condition-based PM** - Triggered by monitored parameter trends (vibration, temperature, oil analysis).
3. **Predictive maintenance** - Uses trend analysis and AI-driven anomaly detection to anticipate failures.

## 3. CNC Milling Center Maintenance Schedule

### 3.5 Semi-Annual Checks

- **Bearing inspection and lubrication** - Inspect all spindle and support bearings per SOP-BRG-001. This is the most critical semi-annual task for CNC milling equipment. Failure to complete bearing inspections on schedule has historically been the leading cause of unplanned bearing failures.
- Spindle motor insulation resistance test
- Complete lubrication system service
- Geometric accuracy verification

### 3.6 Annual Checks

- Comprehensive spindle assembly inspection
- Bearing replacement assessment (replace if approaching 18-month service life or if condition monitoring indicates wear)
- Full geometric accuracy certification

## 7. Overdue Maintenance Policy

Maintenance tasks that are not completed within 7 calendar days of their scheduled date are classified as **overdue** and trigger the following escalation:

| Days Overdue | Escalation Level |
|---|---|
| 1-7 days | Maintenance Supervisor notified; reason documented |
| 8-14 days | Maintenance Manager notified; risk assessment required |
| 15-30 days | Plant Manager notified; formal deviation report |
| >30 days | Machine placed on restricted operation pending completion |

**Note:** Overdue bearing inspections are a known risk factor for unplanned failures. Equipment with overdue bearing inspections operating with elevated vibration or temperature should be treated as priority maintenance regardless of the overdue duration.

## 9. Spare Parts Policy

Critical spare parts, including bearings for all CNC spindles, must be maintained in stock. Current minimum stock levels:

| Part | Minimum Quantity |
|---|---|
| CNC Milling spindle bearing set (angular contact) | 2 sets |
| CNC Lathe spindle bearing set | 2 sets |
| Hydraulic press seal kit | 3 kits |
| Coolant pump motor | 1 unit per machine type |$$
WHERE DOC_ID = 'DOC-003';

-- DOC-004: CNC Milling Center Troubleshooting Guide
UPDATE OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS
SET CONTENT = $$# CNC Milling Center Troubleshooting Guide

**Document ID:** TSG-CNC-004
**Revision:** 2.2
**Effective Date:** 2026-04-10
**Applicable Equipment:** CNC Milling Centers (all models)

## 2. Symptom-Based Troubleshooting

### 2.1 Excessive Vibration

**Symptom:** Vibration readings above normal baseline; may be accompanied by audible noise changes or surface finish degradation.

#### Diagnostic Decision Tree

1. **Is vibration present at idle (no cutting)?**
   - Yes: Likely mechanical issue (bearing, spindle, unbalance). Proceed to step 2.
   - No: Likely process-related (tool condition, cutting parameters).

2. **Is vibration correlated with temperature increase at the bearing housing?**
   - Yes: **High probability of bearing degradation.** This is the most common correlation pattern for progressive bearing wear. The combined vibration and temperature increase indicates increasing friction and mechanical looseness. Proceed to Bearing Degradation Assessment.
   - No: Check for spindle unbalance, misalignment, or loose mounting.

3. **Is the vibration level increasing over days/weeks (trending upward)?**
   - Yes: **Progressive mechanical degradation.** Most commonly bearing wear. Review maintenance history for bearing age and last inspection date.
   - No: May be intermittent or event-driven.

#### Bearing Degradation Assessment

When vibration and temperature are both trending upward:

1. **Review bearing age:** Check maintenance history for the last bearing replacement date. Bearings approaching or exceeding 12-18 months of service are candidates for replacement.
2. **Check maintenance compliance:** Verify that the most recent scheduled bearing inspection was completed on time. Overdue inspections combined with rising vibration/temperature significantly increase the probability of bearing-related root cause.
3. **Review fleet comparison:** Compare the machine against identical machines on the same line. If peer machines are normal, the issue is machine-specific.
4. **Review historical failures:** Check whether similar machines have experienced bearing failures with similar precursor symptoms.

5. **Decision matrix:**

| Vibration Trend | Temp Trend | Bearing Age | Last Inspection | Action |
|---|---|---|---|---|
| Rising + in Zone B | Rising but <60C | <12 months | Recent and normal | Monitor weekly |
| Rising + in Zone C | Rising, 60-70C | 12-18 months | Recent and normal | Schedule replacement within 7 days |
| Rising + in Zone C | Rising, 60-70C | Any age | Overdue | Schedule replacement within 48 hours |
| Rising + in Zone D | Rising, >70C | Any age | Any status | Remove from production. Emergency replacement. |
| Any increase | Any increase | >18 months | Overdue | Immediate inspection required |

### 2.2 Elevated Bearing Temperature

Common Causes:
1. Insufficient lubrication - Most common cause.
2. Bearing wear - Progressive temperature increase over weeks usually indicates wear. If both vibration and temperature are rising, bearing replacement is likely needed.
3. Excessive preload
4. Contamination
5. Overloading

| Temperature Range | Condition | Action |
|---|---|---|
| 35-50C | Normal | Continue operation |
| 50-65C | Elevated | Investigate cause; check lubrication and vibration |
| 65-80C | Critical | Reduce load; schedule emergency maintenance |
| >80C | Shutdown | Stop machine immediately to prevent catastrophic damage |

### 2.3 OEE Decline

When all three OEE components decline simultaneously, the root cause is typically mechanical degradation affecting the core machine function (e.g., spindle/bearing system). Investigate the mechanical condition before looking at process or material causes.

## 3. Escalation Criteria

Immediately escalate to the Maintenance Manager if:
- Vibration readings enter Zone D (critical threshold exceeded)
- Bearing temperature exceeds 75C
- Multiple correlated symptoms present (vibration + temperature + OEE decline)
- Machine has overdue critical maintenance and symptoms are worsening
- Similar failure pattern matches a recent failure on fleet equipment$$
WHERE DOC_ID = 'DOC-004';
