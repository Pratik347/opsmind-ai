"""
OpsMind AI - Seed Data Validation Script
Validates all CSV seed data for integrity, consistency, and scenario correctness.
"""
import csv
import os
import sys
from datetime import datetime
from collections import defaultdict

DATA_DIR = r"C:\workspace\opsmind-ai\setup\data"
errors = []
warnings = []

def load_csv(filename):
    path = os.path.join(DATA_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)

def err(msg):
    errors.append(msg)
    print(f"  ERROR: {msg}")

def warn(msg):
    warnings.append(msg)
    print(f"  WARN:  {msg}")

def ok(msg):
    print(f"  OK:    {msg}")

# ============================================================
print("=" * 60)
print("LOADING DATA")
print("=" * 60)

plants = load_csv("plants.csv")
lines = load_csv("production_lines.csv")
machines = load_csv("machines.csv")
sensors = load_csv("sensor_readings.csv")
oee = load_csv("oee_metrics.csv")
maint = load_csv("maintenance_history.csv")
failures = load_csv("failure_history.csv")
work_orders = load_csv("work_orders.csv")
anomalies = load_csv("anomaly_signals.csv")
recs = load_csv("recommendations.csv")
approvals = load_csv("approval_decisions.csv")
actions = load_csv("executed_actions.csv")
audit = load_csv("audit_log.csv")
docs = load_csv("operational_documents.csv")

all_files = {
    "plants": plants, "production_lines": lines, "machines": machines,
    "sensor_readings": sensors, "oee_metrics": oee,
    "maintenance_history": maint, "failure_history": failures,
    "work_orders": work_orders, "anomaly_signals": anomalies,
    "recommendations": recs, "approval_decisions": approvals,
    "executed_actions": actions, "audit_log": audit,
    "operational_documents": docs,
}

for name, data in all_files.items():
    print(f"  {name}: {len(data)} rows")

# ============================================================
print("\n" + "=" * 60)
print("1. PRIMARY KEY UNIQUENESS")
print("=" * 60)

pk_map = {
    "plants": "plant_id",
    "production_lines": "line_id",
    "machines": "machine_id",
    "sensor_readings": "reading_id",
    "oee_metrics": "oee_id",
    "maintenance_history": "maintenance_id",
    "failure_history": "failure_id",
    "work_orders": "wo_id",
    "anomaly_signals": "anomaly_id",
    "recommendations": "recommendation_id",
    "approval_decisions": "approval_id",
    "executed_actions": "action_id",
    "audit_log": "audit_id",
    "operational_documents": "doc_id",
}

for table_name, pk_col in pk_map.items():
    data = all_files[table_name]
    pks = [row[pk_col] for row in data]
    dupes = [pk for pk in pks if pks.count(pk) > 1]
    if dupes:
        err(f"{table_name}: Duplicate PKs: {set(dupes)}")
    else:
        ok(f"{table_name}: {len(pks)} unique PKs")

# ============================================================
print("\n" + "=" * 60)
print("2. FOREIGN KEY INTEGRITY")
print("=" * 60)

plant_ids = {r["plant_id"] for r in plants}
line_ids = {r["line_id"] for r in lines}
machine_ids = {r["machine_id"] for r in machines}
anomaly_ids = {r["anomaly_id"] for r in anomalies}
rec_ids = {r["recommendation_id"] for r in recs}
approval_ids = {r["approval_id"] for r in approvals}
wo_ids = {r["wo_id"] for r in work_orders}

# Lines â†’ Plants
for r in lines:
    if r["plant_id"] not in plant_ids:
        err(f"production_lines: {r['line_id']} references invalid plant {r['plant_id']}")
ok("production_lines -> plants: checked")

# Machines â†’ Lines
for r in machines:
    if r["line_id"] not in line_ids:
        err(f"machines: {r['machine_id']} references invalid line {r['line_id']}")
ok("machines â†’ production_lines: checked")

# Sensors â†’ Machines
sensor_machine_ids = {r["machine_id"] for r in sensors}
for mid in sensor_machine_ids:
    if mid not in machine_ids:
        err(f"sensor_readings: references invalid machine {mid}")
ok(f"sensor_readings â†’ machines: {len(sensor_machine_ids)} machines checked")

# OEE â†’ Machines
oee_machine_ids = {r["machine_id"] for r in oee}
for mid in oee_machine_ids:
    if mid not in machine_ids:
        err(f"oee_metrics: references invalid machine {mid}")
ok(f"oee_metrics â†’ machines: {len(oee_machine_ids)} machines checked")

# Maintenance â†’ Machines
for r in maint:
    if r["machine_id"] not in machine_ids:
        err(f"maintenance_history: {r['maintenance_id']} references invalid machine {r['machine_id']}")
ok("maintenance_history â†’ machines: checked")

# Failures â†’ Machines
for r in failures:
    if r["machine_id"] not in machine_ids:
        err(f"failure_history: {r['failure_id']} references invalid machine {r['machine_id']}")
ok("failure_history â†’ machines: checked")

# Work Orders â†’ Machines
for r in work_orders:
    if r["machine_id"] not in machine_ids:
        err(f"work_orders: {r['wo_id']} references invalid machine {r['machine_id']}")
ok("work_orders â†’ machines: checked")

# Anomalies â†’ Machines
for r in anomalies:
    if r["machine_id"] not in machine_ids:
        err(f"anomaly_signals: {r['anomaly_id']} references invalid machine {r['machine_id']}")
ok("anomaly_signals â†’ machines: checked")

# Recommendations â†’ Anomalies and Machines
for r in recs:
    if r["anomaly_id"] not in anomaly_ids:
        err(f"recommendations: {r['recommendation_id']} references invalid anomaly {r['anomaly_id']}")
    if r["machine_id"] not in machine_ids:
        err(f"recommendations: {r['recommendation_id']} references invalid machine {r['machine_id']}")
ok("recommendations â†’ anomaly_signals, machines: checked")

# Approvals â†’ Recommendations
for r in approvals:
    if r["recommendation_id"] not in rec_ids:
        err(f"approval_decisions: {r['approval_id']} references invalid recommendation {r['recommendation_id']}")
ok("approval_decisions â†’ recommendations: checked")

# Actions â†’ Approvals
for r in actions:
    if r["approval_id"] not in approval_ids:
        err(f"executed_actions: {r['action_id']} references invalid approval {r['approval_id']}")
    if r["wo_id"] and r["wo_id"] not in wo_ids:
        err(f"executed_actions: {r['action_id']} references invalid work order {r['wo_id']}")
ok("executed_actions â†’ approval_decisions, work_orders: checked")

# ============================================================
print("\n" + "=" * 60)
print("3. NULL CHECKS ON MANDATORY FIELDS")
print("=" * 60)

mandatory_fields = {
    "plants": ["plant_id", "plant_name", "region", "timezone", "plant_type"],
    "production_lines": ["line_id", "plant_id", "line_name", "product_type"],
    "machines": ["machine_id", "line_id", "machine_name", "machine_type", "status"],
    "sensor_readings": ["reading_id", "machine_id", "reading_ts", "sensor_type", "value", "unit"],
    "oee_metrics": ["oee_id", "machine_id", "metric_date", "shift"],
    "anomaly_signals": ["anomaly_id", "machine_id", "detected_at", "signal_type", "severity"],
    "recommendations": ["recommendation_id", "anomaly_id", "machine_id", "generated_at", "action_type"],
    "approval_decisions": ["approval_id", "recommendation_id", "decision_at", "decided_by", "decision"],
    "audit_log": ["audit_id", "entity_type", "entity_id", "event_ts", "event_type", "actor"],
}

for table_name, fields in mandatory_fields.items():
    data = all_files[table_name]
    for field in fields:
        nulls = sum(1 for r in data if not r.get(field, "").strip())
        if nulls:
            err(f"{table_name}.{field}: {nulls} null/empty values")
    ok(f"{table_name}: mandatory fields checked")

# ============================================================
print("\n" + "=" * 60)
print("4. NUMERIC RANGE CHECKS")
print("=" * 60)

# OEE percentages
for r in oee:
    for pct_field in ["availability_pct", "performance_pct", "quality_pct", "oee_pct"]:
        val = float(r[pct_field])
        if val < 0 or val > 100:
            err(f"oee_metrics {r['oee_id']}: {pct_field}={val} out of range [0,100]")
    if int(r["downtime_minutes"]) < 0:
        err(f"oee_metrics {r['oee_id']}: negative downtime")
    if int(r["units_defective"]) < 0:
        err(f"oee_metrics {r['oee_id']}: negative defectives")
    if int(r["units_defective"]) > int(r["units_produced"]):
        err(f"oee_metrics {r['oee_id']}: defective ({r['units_defective']}) > produced ({r['units_produced']})")

ok(f"oee_metrics: {len(oee)} rows numeric ranges validated")

# Sensor values positive
neg_sensors = sum(1 for r in sensors if float(r["value"]) <= 0)
if neg_sensors:
    err(f"sensor_readings: {neg_sensors} non-positive values")
else:
    ok(f"sensor_readings: all {len(sensors)} values positive")

# Confidence scores
for r in anomalies:
    cs = float(r["confidence_score"])
    if cs < 0 or cs > 1:
        err(f"anomaly_signals {r['anomaly_id']}: confidence {cs} out of [0,1]")
ok("anomaly_signals: confidence scores in range")

# Costs non-negative
for r in failures:
    if float(r["repair_cost_usd"]) < 0:
        err(f"failure_history {r['failure_id']}: negative repair cost")
ok("failure_history: costs non-negative")

# ============================================================
print("\n" + "=" * 60)
print("5. TIMESTAMP ORDERING")
print("=" * 60)

def parse_ts(s):
    if not s.strip():
        return None
    for fmt in ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d"]:
        try:
            return datetime.strptime(s.strip(), fmt)
        except ValueError:
            continue
    return None

# Sensor readings should be chronologically ordered per machine
machine_sensor_ts = defaultdict(list)
for r in sensors:
    machine_sensor_ts[r["machine_id"]].append(parse_ts(r["reading_ts"]))
for mid, ts_list in machine_sensor_ts.items():
    sorted_ts = sorted(ts_list)
    if ts_list != sorted_ts:
        warn(f"sensor_readings for {mid}: not in strict chronological order (OK for batch insert)")
ok("sensor_readings: timestamps parsed successfully")

# Failure start < end
for r in failures:
    start = parse_ts(r["failure_start"])
    end = parse_ts(r["failure_end"])
    if end and start and end < start:
        err(f"failure_history {r['failure_id']}: end before start")
ok("failure_history: start < end validated")

# Work order: created < due, created < completed
for r in work_orders:
    created = parse_ts(r["created_date"])
    due = parse_ts(r["due_date"])
    completed = parse_ts(r["completed_date"])
    if due and created and due < created:
        err(f"work_orders {r['wo_id']}: due before created")
    if completed and created and completed < created:
        err(f"work_orders {r['wo_id']}: completed before created")
ok("work_orders: timestamp ordering validated")

# Audit log chronological
audit_ts_list = [parse_ts(r["event_ts"]) for r in audit]
if audit_ts_list != sorted(audit_ts_list):
    warn("audit_log: not in strict chronological order")
else:
    ok("audit_log: chronologically ordered")

# ============================================================
print("\n" + "=" * 60)
print("6. M-302 DEGRADATION VERIFICATION")
print("=" * 60)

# Verify vibration trend
m302_vib = [(parse_ts(r["reading_ts"]), float(r["value"]))
            for r in sensors
            if r["machine_id"] == "M-302" and r["sensor_type"] == "vibration"]
m302_vib.sort()

week1_vib = [v for ts, v in m302_vib if ts.day <= 7]
week4_vib = [v for ts, v in m302_vib if ts.day >= 22]

w1_mean = sum(week1_vib) / len(week1_vib) if week1_vib else 0
w4_mean = sum(week4_vib) / len(week4_vib) if week4_vib else 0

if w4_mean > w1_mean * 1.5:
    ok(f"M-302 vibration: Week 1 mean={w1_mean:.2f}, Week 4 mean={w4_mean:.2f} (+{((w4_mean/w1_mean)-1)*100:.0f}%)")
else:
    err(f"M-302 vibration trend insufficient: Week 1={w1_mean:.2f}, Week 4={w4_mean:.2f}")

# Verify bearing temp trend
m302_temp = [(parse_ts(r["reading_ts"]), float(r["value"]))
             for r in sensors
             if r["machine_id"] == "M-302" and r["sensor_type"] == "bearing_temp"]
m302_temp.sort()

week1_temp = [v for ts, v in m302_temp if ts.day <= 7]
week4_temp = [v for ts, v in m302_temp if ts.day >= 22]

w1t_mean = sum(week1_temp) / len(week1_temp) if week1_temp else 0
w4t_mean = sum(week4_temp) / len(week4_temp) if week4_temp else 0

if w4t_mean > w1t_mean * 1.3:
    ok(f"M-302 bearing temp: Week 1 mean={w1t_mean:.2f}Â°C, Week 4 mean={w4t_mean:.2f}Â°C (+{((w4t_mean/w1t_mean)-1)*100:.0f}%)")
else:
    err(f"M-302 bearing temp trend insufficient: Week 1={w1t_mean:.2f}, Week 4={w4t_mean:.2f}")

# Verify OEE decline
m302_oee = [(r["metric_date"], float(r["oee_pct"]))
            for r in oee if r["machine_id"] == "M-302"]
m302_oee.sort()

week1_oee = [v for d, v in m302_oee if d <= "2026-09-07"]
week4_oee = [v for d, v in m302_oee if d >= "2026-09-22"]

w1o_mean = sum(week1_oee) / len(week1_oee) if week1_oee else 0
w4o_mean = sum(week4_oee) / len(week4_oee) if week4_oee else 0

if w1o_mean - w4o_mean > 15:
    ok(f"M-302 OEE: Week 1 mean={w1o_mean:.1f}%, Week 4 mean={w4o_mean:.1f}% (decline of {w1o_mean-w4o_mean:.1f} pts)")
else:
    err(f"M-302 OEE decline insufficient: Week 1={w1o_mean:.1f}, Week 4={w4o_mean:.1f}")

# Verify comparison machines are normal
for peer in ["M-301", "M-303"]:
    peer_vib = [float(r["value"]) for r in sensors
                if r["machine_id"] == peer and r["sensor_type"] == "vibration"]
    peer_mean = sum(peer_vib) / len(peer_vib) if peer_vib else 0
    peer_max = max(peer_vib) if peer_vib else 0
    if peer_max < 4.0:
        ok(f"{peer} vibration: mean={peer_mean:.2f}, max={peer_max:.2f} (normal)")
    else:
        warn(f"{peer} vibration: max={peer_max:.2f} may appear anomalous")

# Verify overdue maintenance exists
overdue = [r for r in maint if r["machine_id"] == "M-302" and r["status"] == "overdue"]
if overdue:
    ok(f"M-302 overdue maintenance: {len(overdue)} record(s) â€” {overdue[0]['description']}")
else:
    err("M-302 has no overdue maintenance record")

# Verify M-303 historical failure exists
m303_failures = [r for r in failures if r["machine_id"] == "M-303" and "bearing" in r["failure_mode"].lower()]
if m303_failures:
    ok(f"M-303 bearing failure history: {m303_failures[0]['failure_mode']} on {m303_failures[0]['failure_start'][:10]}")
else:
    err("M-303 has no bearing failure history for comparison")

# ============================================================
print("\n" + "=" * 60)
print("7. GOVERNANCE CHAIN VALIDATION")
print("=" * 60)

# Verify: anomaly â†’ recommendation â†’ approval â†’ action â†’ audit
if anomalies and recs and approvals and actions and audit:
    rec = recs[0]
    apr = approvals[0]
    act = actions[0]
    
    anomaly_ts = parse_ts([a for a in anomalies if a["anomaly_id"] == rec["anomaly_id"]][0]["detected_at"])
    rec_ts = parse_ts(rec["generated_at"])
    apr_ts = parse_ts(apr["decision_at"])
    act_ts = parse_ts(act["executed_at"])
    
    if anomaly_ts < rec_ts < apr_ts <= act_ts:
        ok(f"Governance chain: anomaly({anomaly_ts.strftime('%m/%d')}) â†’ rec({rec_ts.strftime('%m/%d')}) â†’ approval({apr_ts.strftime('%m/%d')}) â†’ action({act_ts.strftime('%m/%d')})")
    else:
        err(f"Governance chain ordering broken: {anomaly_ts} â†’ {rec_ts} â†’ {apr_ts} â†’ {act_ts}")
else:
    err("Governance chain incomplete: missing data")

# ============================================================
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"  Errors:   {len(errors)}")
print(f"  Warnings: {len(warnings)}")
if errors:
    print("\nFAILED - errors found:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
else:
    print("\nPASSED - all validations OK")
    sys.exit(0)

