"""
OpsMind AI - Deterministic Seed Data Generator
Generates all CSV seed data for the manufacturing operations demo.
This script is run once to produce the seed data files.
"""
import csv
import os
import random
import math
from datetime import datetime, timedelta, date

# Deterministic seed
random.seed(42)

OUTPUT_DIR = r"C:\workspace\opsmind-ai\setup\data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

BASE_DATE = date(2026, 9, 1)

def ts(d, h=8, m=0):
    """Create timestamp string."""
    return datetime(d.year, d.month, d.day, h, m, 0).strftime("%Y-%m-%d %H:%M:%S")

def write_csv(filename, headers, rows):
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(headers)
        w.writerows(rows)
    print(f"  {filename}: {len(rows)} rows")

# ============================================================
# PLANTS
# ============================================================
plants = [
    ("PLT-001", "Midwest Manufacturing", "US-Central", "America/Chicago", "Assembly & Machining"),
    ("PLT-002", "Southeast Assembly", "US-Southeast", "America/New_York", "Assembly"),
    ("PLT-003", "Pacific Components", "US-West", "America/Los_Angeles", "Components"),
]
write_csv("plants.csv",
    ["plant_id","plant_name","region","timezone","plant_type"],
    plants)

# ============================================================
# PRODUCTION_LINES
# ============================================================
lines = [
    ("LINE-101", "PLT-001", "Precision Machining Line A", "Machined Components", 120),
    ("LINE-201", "PLT-001", "Hydraulic Press Line", "Formed Parts", 80),
    ("LINE-301", "PLT-001", "CNC Finishing Line", "Finished Assemblies", 100),
    ("LINE-401", "PLT-002", "Assembly Line Alpha", "Electronic Assemblies", 200),
    ("LINE-501", "PLT-003", "CNC Turning Line", "Turned Components", 90),
]
write_csv("production_lines.csv",
    ["line_id","plant_id","line_name","product_type","design_capacity_units_hr"],
    lines)

# ============================================================
# MACHINES
# ============================================================
machines = [
    ("M-101", "LINE-101", "CNC Mill #1", "CNC Milling Center", "Haas Automation", "VF-4SS", "2020-03-15", "2024-06-10", "operational", 4),
    ("M-102", "LINE-101", "CNC Mill #2", "CNC Milling Center", "Haas Automation", "VF-4SS", "2020-03-15", "2024-06-10", "operational", 4),
    ("M-201", "LINE-201", "Hydraulic Press A", "Hydraulic Press", "Schuler Group", "MSD-400", "2019-07-22", "2023-11-05", "operational", 5),
    ("M-202", "LINE-201", "Hydraulic Press B", "Hydraulic Press", "Schuler Group", "MSD-400", "2019-07-22", "2023-11-05", "operational", 5),
    ("M-301", "LINE-301", "CNC Finishing Mill #1", "CNC Milling Center", "DMG Mori", "CMX-70U", "2021-01-10", "2025-02-20", "operational", 4),
    ("M-302", "LINE-301", "CNC Finishing Mill #2", "CNC Milling Center", "DMG Mori", "CMX-70U", "2021-01-10", "2025-07-15", "operational", 4),
    ("M-303", "LINE-301", "CNC Finishing Mill #3", "CNC Milling Center", "DMG Mori", "CMX-70U", "2021-06-01", "2025-02-20", "operational", 4),
    ("M-401", "LINE-401", "Assembly Robot #1", "Assembly Robot", "FANUC", "M-20iD/25", "2022-04-01", "2025-04-01", "operational", 3),
    ("M-402", "LINE-401", "Assembly Robot #2", "Assembly Robot", "FANUC", "M-20iD/25", "2022-04-01", "2025-04-01", "operational", 3),
    ("M-501", "LINE-501", "CNC Lathe #1", "CNC Lathe", "Mazak", "QT-250MSY", "2021-09-15", "2025-01-10", "operational", 4),
    ("M-502", "LINE-501", "CNC Lathe #2", "CNC Lathe", "Mazak", "QT-250MSY", "2021-09-15", "2025-01-10", "operational", 4),
]
write_csv("machines.csv",
    ["machine_id","line_id","machine_name","machine_type","manufacturer","model",
     "install_date","last_overhaul_date","status","criticality_rating"],
    machines)

# ============================================================
# SENSOR_READINGS - the core time-series data
# ============================================================
sensor_rows = []
reading_counter = [0]

def next_reading_id():
    reading_counter[0] += 1
    return f"SR-{reading_counter[0]:06d}"

# Define sensor profiles per machine type
SENSOR_PROFILES = {
    "CNC Milling Center": {
        "vibration":        {"unit": "mm/s",  "base": 2.4, "noise": 0.4},
        "bearing_temp":     {"unit": "°C",    "base": 45.0, "noise": 3.0},
        "spindle_speed":    {"unit": "RPM",   "base": 8000, "noise": 200},
        "power_consumption":{"unit": "kW",    "base": 18.0, "noise": 1.5},
        "coolant_pressure": {"unit": "bar",   "base": 5.5, "noise": 0.3},
    },
    "Hydraulic Press": {
        "vibration":        {"unit": "mm/s",  "base": 3.0, "noise": 0.5},
        "bearing_temp":     {"unit": "°C",    "base": 50.0, "noise": 4.0},
        "power_consumption":{"unit": "kW",    "base": 45.0, "noise": 3.0},
        "coolant_pressure": {"unit": "bar",   "base": 180.0,"noise": 5.0},
    },
    "Assembly Robot": {
        "vibration":        {"unit": "mm/s",  "base": 0.8, "noise": 0.15},
        "bearing_temp":     {"unit": "°C",    "base": 35.0, "noise": 2.0},
        "power_consumption":{"unit": "kW",    "base": 5.0, "noise": 0.5},
    },
    "CNC Lathe": {
        "vibration":        {"unit": "mm/s",  "base": 2.2, "noise": 0.35},
        "bearing_temp":     {"unit": "°C",    "base": 43.0, "noise": 2.5},
        "spindle_speed":    {"unit": "RPM",   "base": 4000, "noise": 150},
        "power_consumption":{"unit": "kW",    "base": 15.0, "noise": 1.2},
        "coolant_pressure": {"unit": "bar",   "base": 5.0, "noise": 0.25},
    },
}

machine_type_map = {m[0]: m[3] for m in machines}

# Generate 27 days of readings (Sep 1 - Sep 27), 3 readings per day per sensor
for day_offset in range(27):
    current_date = BASE_DATE + timedelta(days=day_offset)
    for machine in machines:
        mid = machine[0]
        mtype = machine[3]
        profile = SENSOR_PROFILES[mtype]

        for sensor_type, cfg in profile.items():
            for hour in [6, 14, 22]:  # 3 shifts
                base = cfg["base"]
                noise = cfg["noise"]

                # M-302 degradation profile
                if mid == "M-302":
                    if sensor_type == "vibration":
                        if day_offset <= 6:
                            val = base + random.gauss(0, noise)
                        elif day_offset <= 13:
                            progress = (day_offset - 7) / 7.0
                            val = base + progress * 1.4 + random.gauss(0, noise)
                        elif day_offset <= 20:
                            progress = (day_offset - 14) / 7.0
                            val = 3.8 + progress * 1.7 + random.gauss(0, noise * 0.8)
                        else:
                            progress = (day_offset - 21) / 6.0
                            val = 5.5 + progress * 1.7 + random.gauss(0, noise * 0.6)
                    elif sensor_type == "bearing_temp":
                        if day_offset <= 6:
                            val = base + random.gauss(0, noise)
                        elif day_offset <= 13:
                            progress = (day_offset - 7) / 7.0
                            val = base + progress * 10.0 + random.gauss(0, noise)
                        elif day_offset <= 20:
                            progress = (day_offset - 14) / 7.0
                            val = 55.0 + progress * 10.0 + random.gauss(0, noise * 0.8)
                        else:
                            progress = (day_offset - 21) / 6.0
                            val = 65.0 + progress * 10.0 + random.gauss(0, noise * 0.6)
                    elif sensor_type == "power_consumption":
                        if day_offset <= 13:
                            val = base + random.gauss(0, noise)
                        else:
                            progress = (day_offset - 14) / 13.0
                            val = base + progress * 3.0 + random.gauss(0, noise)
                    else:
                        val = base + random.gauss(0, noise)
                # M-501: minor normal variation (not anomalous)
                elif mid == "M-501":
                    val = base + random.gauss(0, noise * 1.1)
                else:
                    val = base + random.gauss(0, noise)

                val = round(max(0.1, val), 2)
                sensor_rows.append([
                    next_reading_id(), mid,
                    ts(current_date, hour, random.randint(0, 5)),
                    sensor_type, val, cfg["unit"]
                ])

write_csv("sensor_readings.csv",
    ["reading_id","machine_id","reading_ts","sensor_type","value","unit"],
    sensor_rows)

# ============================================================
# OEE_METRICS
# ============================================================
oee_rows = []
oee_counter = [0]
SHIFTS = ["day", "swing", "night"]

def next_oee_id():
    oee_counter[0] += 1
    return f"OEE-{oee_counter[0]:05d}"

for day_offset in range(27):
    current_date = BASE_DATE + timedelta(days=day_offset)
    for machine in machines:
        mid = machine[0]
        mtype = machine[3]

        for shift in SHIFTS:
            planned_hrs = 8.0

            if mid == "M-302":
                if day_offset <= 6:
                    avail = random.uniform(94, 98)
                    perf = random.uniform(91, 96)
                    qual = random.uniform(98.5, 99.5)
                    dt = random.randint(0, 15)
                elif day_offset <= 13:
                    progress = (day_offset - 7) / 7.0
                    avail = random.uniform(91 - progress*4, 96 - progress*2)
                    perf = random.uniform(89 - progress*3, 94 - progress*2)
                    qual = random.uniform(97.5 - progress*1, 99.0 - progress*0.5)
                    dt = random.randint(5 + int(progress*10), 20 + int(progress*10))
                elif day_offset <= 20:
                    progress = (day_offset - 14) / 7.0
                    avail = random.uniform(85 - progress*6, 92 - progress*4)
                    perf = random.uniform(84 - progress*5, 90 - progress*4)
                    qual = random.uniform(96.0 - progress*1.5, 98.0 - progress*1)
                    dt = random.randint(20 + int(progress*15), 35 + int(progress*15))
                else:
                    progress = (day_offset - 21) / 6.0
                    avail = random.uniform(78 - progress*7, 85 - progress*5)
                    perf = random.uniform(78 - progress*6, 84 - progress*4)
                    qual = random.uniform(93.0 - progress*2, 96.0 - progress*1.5)
                    dt = random.randint(40 + int(progress*20), 60 + int(progress*20))
            elif mid == "M-501":
                avail = random.uniform(92, 97)
                perf = random.uniform(90, 95)
                qual = random.uniform(97.5, 99.5)
                dt = random.randint(0, 20)
            elif mtype == "Hydraulic Press":
                avail = random.uniform(93, 98)
                perf = random.uniform(90, 96)
                qual = random.uniform(98.0, 99.8)
                dt = random.randint(0, 18)
            elif mtype == "Assembly Robot":
                avail = random.uniform(96, 99.5)
                perf = random.uniform(94, 98)
                qual = random.uniform(99.0, 99.8)
                dt = random.randint(0, 10)
            else:
                avail = random.uniform(93, 98)
                perf = random.uniform(91, 96)
                qual = random.uniform(98.0, 99.5)
                dt = random.randint(0, 18)

            avail = round(max(50, min(100, avail)), 1)
            perf = round(max(50, min(100, perf)), 1)
            qual = round(max(85, min(100, qual)), 1)
            oee = round(avail * perf * qual / 10000, 1)
            dt = max(0, dt)

            actual_hrs = round(planned_hrs * avail / 100, 2)
            design_cap = int([l for l in lines if l[0] == machine[1]][0][4])
            units = int(actual_hrs * design_cap * perf / 100)
            defective = max(0, int(units * (100 - qual) / 100))

            oee_rows.append([
                next_oee_id(), mid,
                current_date.strftime("%Y-%m-%d"), shift,
                avail, perf, qual, oee,
                planned_hrs, actual_hrs, units, defective, dt
            ])

write_csv("oee_metrics.csv",
    ["oee_id","machine_id","metric_date","shift",
     "availability_pct","performance_pct","quality_pct","oee_pct",
     "planned_production_hrs","actual_production_hrs",
     "units_produced","units_defective","downtime_minutes"],
    oee_rows)

# ============================================================
# MAINTENANCE_HISTORY
# ============================================================
maint_rows = [
    # M-302 key records
    ("MNT-001","M-302","2025-07-15 08:00:00","2025-07-15 16:00:00","corrective","Spindle bearing replacement - scheduled replacement due to age","bearing","J. Martinez","completed",2450.00),
    ("MNT-002","M-302","2026-03-10 08:00:00","2026-03-10 12:00:00","preventive","Bearing inspection and lubrication","bearing","J. Martinez","completed",320.00),
    ("MNT-003","M-302","2026-09-10 08:00:00","","preventive","Bearing inspection - 6-month scheduled check","bearing","","overdue",None),
    ("MNT-004","M-302","2026-08-15 08:00:00","2026-08-15 10:00:00","preventive","Coolant system flush and filter replacement","coolant_system","A. Singh","completed",180.00),
    ("MNT-005","M-302","2026-06-20 08:00:00","2026-06-20 14:00:00","preventive","Annual spindle alignment check","spindle","J. Martinez","completed",450.00),

    # M-301 (normal peer)
    ("MNT-010","M-301","2025-08-20 08:00:00","2025-08-20 14:00:00","preventive","Bearing inspection and lubrication","bearing","K. Thompson","completed",300.00),
    ("MNT-011","M-301","2026-02-15 08:00:00","2026-02-15 12:00:00","preventive","Bearing inspection and lubrication","bearing","K. Thompson","completed",310.00),
    ("MNT-012","M-301","2026-08-18 08:00:00","2026-08-18 12:00:00","preventive","Bearing inspection and lubrication","bearing","K. Thompson","completed",305.00),
    ("MNT-013","M-301","2026-07-10 08:00:00","2026-07-10 10:00:00","preventive","Coolant system flush","coolant_system","A. Singh","completed",175.00),

    # M-303 (had historical bearing failure)
    ("MNT-020","M-303","2026-01-08 08:00:00","2026-01-10 16:00:00","corrective","Emergency bearing replacement after failure","bearing","J. Martinez","completed",4800.00),
    ("MNT-021","M-303","2026-01-06 08:00:00","","inspection","Vibration check requested - elevated readings","bearing","","completed",150.00),
    ("MNT-022","M-303","2026-07-10 08:00:00","2026-07-10 12:00:00","preventive","Bearing inspection post-replacement","bearing","K. Thompson","completed",280.00),

    # Other machines
    ("MNT-030","M-201","2026-08-01 08:00:00","2026-08-01 12:00:00","preventive","Hydraulic seal inspection","seals","R. Chen","completed",520.00),
    ("MNT-031","M-201","2026-06-15 08:00:00","2026-06-15 10:00:00","preventive","Hydraulic fluid replacement","hydraulic_system","R. Chen","completed",380.00),
    ("MNT-032","M-401","2026-07-20 08:00:00","2026-07-20 10:00:00","preventive","Joint calibration and lubrication","joints","T. Nakamura","completed",210.00),
    ("MNT-033","M-501","2026-08-05 08:00:00","2026-08-05 14:00:00","preventive","Spindle bearing inspection","bearing","K. Thompson","completed",290.00),
    ("MNT-034","M-102","2026-07-25 08:00:00","2026-07-25 12:00:00","preventive","Bearing inspection and lubrication","bearing","J. Martinez","completed",310.00),
    ("MNT-035","M-502","2026-06-30 08:00:00","2026-06-30 10:00:00","preventive","Tool turret alignment","turret","A. Singh","completed",190.00),
]

write_csv("maintenance_history.csv",
    ["maintenance_id","machine_id","scheduled_date","completed_date",
     "maintenance_type","description","component","technician","status","cost_usd"],
    maint_rows)

# ============================================================
# FAILURE_HISTORY
# ============================================================
failure_rows = [
    # M-303 bearing failure (key evidence for M-302 investigation)
    ("FLR-001","M-303","2026-01-08 06:30:00","2026-01-10 16:00:00","bearing_failure",
     "Bearing seizure - spindle bearing","critical",960,4800.00,
     "Emergency bearing replacement and spindle inspection"),
    # M-303 pre-failure vibration noted
    ("FLR-002","M-303","2026-01-05 14:00:00","2026-01-05 14:30:00","vibration_exceedance",
     "Elevated vibration detected during routine monitoring","minor",30,150.00,
     "Vibration check scheduled, machine kept running"),
    # M-201 historical minor
    ("FLR-003","M-201","2025-11-12 10:00:00","2025-11-12 14:00:00","seal_leak",
     "Hydraulic seal degradation","major",240,1200.00,
     "Seal replacement and hydraulic line inspection"),
    # M-101 minor historical
    ("FLR-004","M-101","2025-09-05 22:00:00","2025-09-06 06:00:00","tool_breakage",
     "Tool holder failure during night shift","minor",480,650.00,
     "Tool holder replaced, root cause: material defect"),
    # M-501 minor
    ("FLR-005","M-501","2026-04-18 08:00:00","2026-04-18 11:00:00","coolant_failure",
     "Coolant pump failure","minor",180,420.00,
     "Pump motor replacement"),
]

write_csv("failure_history.csv",
    ["failure_id","machine_id","failure_start","failure_end","failure_mode",
     "root_cause","severity","downtime_minutes","repair_cost_usd","corrective_action"],
    failure_rows)

# ============================================================
# WORK_ORDERS
# ============================================================
wo_rows = [
    # Historical completed work orders
    ("WO-001","M-302","2025-07-10 08:00:00","2025-07-15 17:00:00","2025-07-15 16:00:00",
     "corrective","high","completed","Bearing replacement - age-based replacement","J. Martinez",2200.00,2450.00),
    ("WO-002","M-303","2026-01-08 07:00:00","2026-01-09 17:00:00","2026-01-10 16:00:00",
     "emergency","critical","completed","Emergency bearing replacement after seizure","J. Martinez",3500.00,4800.00),
    ("WO-003","M-201","2025-11-12 10:30:00","2025-11-13 17:00:00","2025-11-12 14:00:00",
     "corrective","high","completed","Hydraulic seal replacement","R. Chen",1000.00,1200.00),

    # Currently open work orders (unrelated to M-302, for realism)
    ("WO-004","M-401","2026-09-20 08:00:00","2026-10-01 17:00:00","",
     "preventive","medium","open","Scheduled joint recalibration Q4","T. Nakamura",350.00,None),
    ("WO-005","M-502","2026-09-22 08:00:00","2026-10-05 17:00:00","",
     "preventive","low","open","Turret alignment - routine","A. Singh",200.00,None),
]

write_csv("work_orders.csv",
    ["wo_id","machine_id","created_date","due_date","completed_date",
     "wo_type","priority","status","description","assigned_to",
     "estimated_cost_usd","actual_cost_usd"],
    wo_rows)

# ============================================================
# ANOMALY_SIGNALS
# ============================================================
anomaly_rows = [
    ("ANM-001","M-302","2026-09-18 14:15:00","vibration_anomaly","warning",
     "Vibration readings trending above baseline for M-302 over past 10 days",
     0.72,"vibration",2.4,4.2,75.0),
    ("ANM-002","M-302","2026-09-19 06:30:00","thermal_anomaly","warning",
     "Bearing temperature elevated above fleet baseline for M-302",
     0.68,"bearing_temp",45.0,60.0,33.3),
    ("ANM-003","M-302","2026-09-23 08:00:00","oee_decline","critical",
     "M-302 OEE has declined 15+ percentage points below 30-day rolling average",
     0.89,"oee_pct",87.0,72.0,17.2),
    ("ANM-004","M-302","2026-09-24 14:30:00","vibration_anomaly","critical",
     "M-302 vibration readings exceeding critical threshold (7.0 mm/s)",
     0.94,"vibration",2.4,7.1,195.8),
    ("ANM-005","M-302","2026-09-25 06:00:00","thermal_anomaly","critical",
     "M-302 bearing temperature approaching shutdown threshold (80°C)",
     0.91,"bearing_temp",45.0,73.0,62.2),
]

write_csv("anomaly_signals.csv",
    ["anomaly_id","machine_id","detected_at","signal_type","severity",
     "description","confidence_score","source_metric",
     "baseline_value","observed_value","deviation_pct"],
    anomaly_rows)

# ============================================================
# RECOMMENDATIONS
# ============================================================
rec_rows = [
    ("REC-001","ANM-003","M-302","2026-09-25 09:00:00","inspect","critical",
     "Schedule emergency bearing inspection on M-302 within 24 hours",
     "Vibration and bearing temperature trends indicate progressive bearing degradation. OEE has declined from 87% to 72%. Scheduled bearing inspection (Sep 10) is overdue. Similar pattern preceded M-303 bearing failure in January 2026.",
     "Vibration 195% above baseline; bearing temp 62% above baseline; OEE declined 17%; overdue bearing inspection; similar historical failure on M-303",
     2800.00,4.0,"Bearing seizure risk within 1-2 weeks. Unplanned failure cost estimated at $15,000-25,000 plus 2-3 days production loss.",
     "pending"),
]

write_csv("recommendations.csv",
    ["recommendation_id","anomaly_id","machine_id","generated_at",
     "action_type","priority","description","rationale","evidence_summary",
     "estimated_cost_usd","estimated_downtime_hrs","risk_if_deferred","status"],
    rec_rows)

# ============================================================
# APPROVAL_DECISIONS
# ============================================================
approval_rows = [
    ("APR-001","REC-001","2026-09-25 11:30:00","Sarah Chen - Plant Manager","approved",
     "Approved. Schedule inspection for tomorrow morning first shift. Pull M-302 from production rotation after current batch completes."),
]

write_csv("approval_decisions.csv",
    ["approval_id","recommendation_id","decision_at","decided_by","decision","comments"],
    approval_rows)

# ============================================================
# EXECUTED_ACTIONS
# ============================================================
action_rows = [
    ("ACT-001","APR-001","WO-006","2026-09-25 12:00:00","work_order_created",
     "Emergency bearing inspection work order created for M-302, scheduled Sep 26 day shift",
     "OpsMind AI System","Work order WO-006 created and assigned to J. Martinez"),
]

write_csv("executed_actions.csv",
    ["action_id","approval_id","wo_id","executed_at","action_type",
     "description","executed_by","result"],
    action_rows)

# Add the generated work order to work_orders
wo_rows.append(
    ("WO-006","M-302","2026-09-25 12:00:00","2026-09-26 17:00:00","",
     "emergency","critical","in_progress",
     "Emergency bearing inspection - OpsMind AI recommendation approved",
     "J. Martinez",2800.00,None)
)
# Rewrite work_orders with the added row
write_csv("work_orders.csv",
    ["wo_id","machine_id","created_date","due_date","completed_date",
     "wo_type","priority","status","description","assigned_to",
     "estimated_cost_usd","actual_cost_usd"],
    wo_rows)

# ============================================================
# AUDIT_LOG
# ============================================================
audit_rows = [
    ("AUD-001","anomaly_signal","ANM-001","2026-09-18 14:15:00","created","OpsMind AI System","Vibration anomaly detected on M-302, severity: warning"),
    ("AUD-002","anomaly_signal","ANM-002","2026-09-19 06:30:00","created","OpsMind AI System","Thermal anomaly detected on M-302, severity: warning"),
    ("AUD-003","anomaly_signal","ANM-003","2026-09-23 08:00:00","created","OpsMind AI System","OEE decline anomaly detected on M-302, severity: critical"),
    ("AUD-004","anomaly_signal","ANM-004","2026-09-24 14:30:00","created","OpsMind AI System","Critical vibration threshold exceeded on M-302"),
    ("AUD-005","anomaly_signal","ANM-005","2026-09-25 06:00:00","created","OpsMind AI System","Critical bearing temperature on M-302 approaching shutdown threshold"),
    ("AUD-006","recommendation","REC-001","2026-09-25 09:00:00","created","OpsMind AI System","Emergency bearing inspection recommended for M-302"),
    ("AUD-007","recommendation","REC-001","2026-09-25 11:30:00","approved","Sarah Chen - Plant Manager","Recommendation approved for immediate action"),
    ("AUD-008","work_order","WO-006","2026-09-25 12:00:00","created","OpsMind AI System","Emergency work order created for M-302 bearing inspection"),
    ("AUD-009","executed_action","ACT-001","2026-09-25 12:00:00","executed","OpsMind AI System","Work order WO-006 created and assigned to J. Martinez"),
]

write_csv("audit_log.csv",
    ["audit_id","entity_type","entity_id","event_ts","event_type","actor","details"],
    audit_rows)

# ============================================================
# OPERATIONAL_DOCUMENTS (metadata only - content in markdown files)
# ============================================================
doc_rows = [
    ("DOC-001","PLT-001","sop","Bearing Inspection Standard Operating Procedure",
     "See setup/data/documents/bearing_inspection_sop.md",
     "CNC Milling Center,CNC Lathe","bearing,spindle_bearing",
     "2026-06-15 00:00:00","3.1"),
    ("DOC-002","PLT-001","manual","Vibration Analysis and Threshold Guidelines",
     "See setup/data/documents/vibration_threshold_guide.md",
     "CNC Milling Center,CNC Lathe,Hydraulic Press","bearing,spindle,motor",
     "2026-05-20 00:00:00","2.4"),
    ("DOC-003","PLT-001","sop","Preventive Maintenance Schedule and Procedures",
     "See setup/data/documents/preventive_maintenance_procedure.md",
     "CNC Milling Center,CNC Lathe,Hydraulic Press,Assembly Robot","bearing,spindle,seals,motor,coolant_system",
     "2026-07-01 00:00:00","4.0"),
    ("DOC-004","PLT-001","troubleshooting_guide","CNC Milling Center Troubleshooting Guide",
     "See setup/data/documents/cnc_troubleshooting_guide.md",
     "CNC Milling Center","bearing,spindle,coolant_system,tool_holder,motor",
     "2026-04-10 00:00:00","2.2"),
]

write_csv("operational_documents.csv",
    ["doc_id","plant_id","doc_type","title","content",
     "applicable_machine_types","applicable_components",
     "last_updated","version"],
    doc_rows)

print("\nSeed data generation complete.")
