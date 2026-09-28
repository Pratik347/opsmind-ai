# CNC Milling Center Troubleshooting Guide

**Document ID:** TSG-CNC-004
**Revision:** 2.2
**Effective Date:** 2026-04-10
**Applicable Equipment:** CNC Milling Centers (all models)
**Applicable Components:** Bearing, spindle, coolant system, tool holder, motor

## 1. Purpose

This guide provides systematic troubleshooting procedures for common CNC milling center issues. Use this guide alongside machine-specific documentation and vibration/temperature threshold guidelines.

## 2. Symptom-Based Troubleshooting

### 2.1 Excessive Vibration

**Symptom:** Vibration readings above normal baseline; may be accompanied by audible noise changes or surface finish degradation on workpieces.

#### Diagnostic Decision Tree

1. **Is vibration present at idle (no cutting)?**
   - Yes → Likely mechanical issue (bearing, spindle, unbalance). Proceed to step 2.
   - No → Likely process-related (tool condition, cutting parameters, workholding). Check tool wear and cutting parameters first.

2. **Is vibration correlated with temperature increase at the bearing housing?**
   - Yes → **High probability of bearing degradation.** This is the most common correlation pattern for progressive bearing wear. The combined vibration and temperature increase indicates increasing friction and mechanical looseness. Proceed to Bearing Degradation Assessment (Section 2.1.1).
   - No → Check for spindle unbalance, misalignment, or loose mounting. Proceed to Section 2.1.2.

3. **Is the vibration level increasing over days/weeks (trending upward)?**
   - Yes → **Progressive mechanical degradation.** Most commonly bearing wear. Review maintenance history for bearing age and last inspection date. Cross-reference with bearing inspection SOP (SOP-BRG-001).
   - No → May be intermittent or event-driven. Check for tool holder issues, workpiece fixturing, or environmental factors (nearby equipment vibration transfer).

#### 2.1.1 Bearing Degradation Assessment

When vibration and temperature are both trending upward, perform the following assessment:

1. **Review bearing age:** Check maintenance history for the last bearing replacement date. Bearings approaching or exceeding 12–18 months of service on CNC milling equipment are candidates for replacement even if only in the warning zone.

2. **Check maintenance compliance:** Verify that the most recent scheduled bearing inspection was completed on time. Overdue inspections combined with rising vibration/temperature significantly increase the probability of bearing-related root cause.

3. **Review fleet comparison:** Compare the machine's vibration and temperature trends against identical machines on the same line. If peer machines are normal, the issue is machine-specific rather than environmental or process-related.

4. **Review historical failures:** Check whether similar machines have experienced bearing failures. If a same-model machine had a bearing failure with similar precursor symptoms, the probability assessment should be raised.

5. **Decision matrix:**

| Vibration Trend | Temp Trend | Bearing Age | Last Inspection | Action |
|---|---|---|---|---|
| Rising + in Zone B | Rising but <60°C | <12 months | Recent & normal | Monitor weekly |
| Rising + in Zone C | Rising, 60-70°C | 12-18 months | Recent & normal | Schedule replacement within 7 days |
| Rising + in Zone C | Rising, 60-70°C | Any age | **Overdue** | **Schedule replacement within 48 hours** |
| Rising + in Zone D | Rising, >70°C | Any age | Any status | **Remove from production. Emergency replacement.** |
| Any increase | Any increase | >18 months | Overdue | **Immediate inspection required** |

#### 2.1.2 Non-Bearing Vibration Causes

- **Spindle unbalance:** Usually constant amplitude, speed-dependent. Perform dynamic balance check.
- **Misalignment:** Often produces 2× running speed vibration. Check coupling alignment.
- **Loose mounting:** Often intermittent, may produce subharmonic frequencies. Check foundation bolts and mounting pads.
- **Resonance:** Amplitude changes significantly with speed. Identify and avoid resonant speed ranges.

### 2.2 Elevated Bearing Temperature

**Symptom:** Bearing housing temperature above normal operating range (>50°C for CNC milling equipment).

#### Common Causes

1. **Insufficient lubrication** — Most common cause. Verify lubrication system is functioning and lubricant grade is correct.
2. **Bearing wear** — Progressive temperature increase over weeks usually indicates wear. Cross-check with vibration data. If both vibration and temperature are rising, bearing replacement is likely needed.
3. **Excessive preload** — Can occur after improper bearing installation. Temperature will be elevated from startup.
4. **Contamination** — Foreign particles in lubricant. Check lubricant condition and filtration.
5. **Overloading** — Sustained heavy cuts beyond machine rating. Review cutting parameters.

#### Temperature Response Actions

| Temperature Range | Condition | Action |
|---|---|---|
| 35–50°C | Normal | Continue operation |
| 50–65°C | Elevated | Investigate cause; check lubrication and vibration |
| 65–80°C | Critical | Reduce load; schedule emergency maintenance |
| >80°C | **Shutdown** | **Stop machine immediately to prevent catastrophic damage** |

### 2.3 OEE Decline

**Symptom:** Overall Equipment Effectiveness trending downward relative to baseline and fleet peers.

#### Diagnostic Approach

OEE has three components. Determine which is declining:

1. **Availability declining** — Increased unplanned stops. Check for recurring faults, increasing downtime events.
2. **Performance declining** — Running slower than rated speed. Check for speed reductions due to quality issues, operator overrides, or mechanical limitations.
3. **Quality declining** — Increased defects or rework. Check for dimensional drift (possible spindle bearing issue), surface finish degradation, or material issues.

**When all three components decline simultaneously**, the root cause is typically mechanical degradation affecting the core machine function (e.g., spindle/bearing system). Investigate the mechanical condition before looking at process or material causes.

### 2.4 Increased Power Consumption

**Symptom:** Machine drawing more power than baseline for similar operations.

#### Common Causes

1. Bearing friction increase (correlates with bearing temperature)
2. Drive system degradation
3. Cutting tool wear (process-related)
4. Coolant system restriction

## 3. Escalation Criteria

Immediately escalate to the Maintenance Manager if:

- Vibration readings enter Zone D (critical threshold exceeded)
- Bearing temperature exceeds 75°C
- Multiple correlated symptoms present (vibration + temperature + OEE decline)
- Machine has overdue critical maintenance and symptoms are worsening
- Similar failure pattern matches a recent failure on fleet equipment

## 4. Documentation

Document all troubleshooting activities including:
- Symptoms observed and measurements taken
- Diagnostic steps performed
- Root cause determination
- Actions taken or recommended
- Reference to related maintenance or failure records
