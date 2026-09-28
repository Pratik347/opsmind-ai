# Bearing Inspection Standard Operating Procedure

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
| Spindle bearing (angular contact) | Every 6 months | 12–18 months depending on operating conditions |
| Support bearing (deep groove) | Every 12 months | 24–36 months |
| Linear guide bearing | Every 6 months | 18–24 months |

Inspection intervals may be shortened if the machine operates in heavy-duty cycles (>16 hours/day) or in environments with elevated particulate levels.

## 3. Pre-Inspection Checks

Before beginning a physical inspection, review the following data:

1. **Vibration trend data** — Compare current readings against the machine's baseline. A sustained increase of 25% or more above the 30-day rolling average warrants immediate inspection regardless of the scheduled interval.
2. **Bearing temperature trend** — Operating temperatures consistently above 60°C for spindle bearings on CNC milling equipment indicate potential lubrication breakdown or mechanical wear.
3. **Maintenance history** — Verify the date of the last bearing service. Bearings approaching the upper end of their replacement interval (e.g., 14+ months for spindle bearings) should be inspected with replacement readiness.
4. **Production quality data** — Increasing surface finish defects or dimensional variation can indicate bearing-related spindle runout.

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

Using an infrared thermometer or contact thermocouple:

1. Measure bearing housing temperature at steady-state operating conditions (minimum 20 minutes after startup).
2. Record the ambient temperature for reference.
3. Bearing housing temperature should not exceed 40°C above ambient for standard operation.

### 4.4 Acoustic Assessment

Using a stethoscope or ultrasonic detector:

1. Listen for irregular sounds: grinding, clicking, or intermittent high-frequency noise.
2. Compare left-side and right-side bearings for asymmetry.
3. Any new acoustic signature warrants further investigation.

## 5. Disposition Criteria

| Finding | Action |
|---|---|
| All measurements within baseline | Return to service, schedule next inspection per interval |
| Vibration 25–75% above baseline, temperature normal | Increase monitoring frequency to weekly; schedule replacement within 30 days |
| Vibration >75% above baseline OR temperature >60°C | Schedule replacement within 7 days; reduce machine load if possible |
| Vibration >150% above baseline OR temperature >70°C | **Remove from production immediately**; emergency replacement required |
| Visible damage, contamination, or seal failure | Replace bearing; investigate contamination source |

## 6. Documentation

Record all inspection results in the maintenance management system, including:

- Date and time of inspection
- Vibration readings (mm/s) at each measurement point
- Temperature readings (°C)
- Visual and acoustic findings
- Disposition decision and rationale
- Next scheduled inspection date

## 7. Safety

- Lock out / tag out (LOTO) the machine before any physical inspection.
- Wear appropriate PPE including safety glasses and hearing protection.
- Allow bearings to cool to <50°C before direct contact inspection.
