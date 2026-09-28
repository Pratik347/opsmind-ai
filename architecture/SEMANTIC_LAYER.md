# OpsMind AI — Semantic Intelligence Layer

## Architecture

The semantic layer uses a single Snowflake Semantic View (`OPSMIND.APP.OPSMIND_OPERATIONS`) to expose manufacturing operational data to Cortex Analyst for natural-language querying.

```
User Question (natural language)
        |
        v
  Cortex Analyst
        |
        v
  Semantic View: OPSMIND.APP.OPSMIND_OPERATIONS
        |
        v
  Physical Tables: OPSMIND.CORE.* + OPSMIND.AI.ANOMALY_SIGNALS
```

The semantic view covers operational facts only. It does not expose GOVERNANCE tables, AI.RECOMMENDATIONS, or any pre-generated conclusions. The future Cortex Agent performs reasoning over evidence retrieved through this layer.

## Entities and Relationships

```
PLANTS (3 rows)
  |-- 1:N --> PRODUCTION_LINES (5 rows)
                |-- 1:N --> MACHINES (11 rows)
                              |-- 1:N --> SENSOR_READINGS (3,969 rows)
                              |-- 1:N --> OEE_METRICS (891 rows)
                              |-- 1:N --> MAINTENANCE_HISTORY (18 rows)
                              |-- 1:N --> FAILURE_HISTORY (5 rows)
                              |-- 1:N --> WORK_ORDERS (6 rows)
                              |-- 1:N --> ANOMALY_SIGNALS (5 rows)
```

All relationships use machine_id or line_id/plant_id foreign keys. Relationship types are inferred automatically by Snowflake.

## Tables Exposed

| Table | Schema | Role | Key Concepts |
|-------|--------|------|-------------|
| PLANTS | CORE | Master | Region, plant type |
| PRODUCTION_LINES | CORE | Master | Product type, capacity |
| MACHINES | CORE | Master | Machine type, status, criticality |
| SENSOR_READINGS | CORE | Time-series | Vibration, bearing temp, spindle speed, power, coolant |
| OEE_METRICS | CORE | Time-series | OEE, availability, performance, quality, downtime |
| MAINTENANCE_HISTORY | CORE | Transactional | Preventive/corrective, component, status, overdue |
| FAILURE_HISTORY | CORE | Transactional | Failure mode, root cause, severity, repair cost |
| WORK_ORDERS | CORE | Transactional | Priority, status, assignment, cost |
| ANOMALY_SIGNALS | AI | Investigation | Signal type, severity, deviation from baseline |

## Tables NOT Exposed (by design)

| Table | Schema | Reason |
|-------|--------|--------|
| RECOMMENDATIONS | AI | Pre-generated conclusions; agent must reason independently |
| APPROVAL_DECISIONS | GOVERNANCE | Governance boundary; operator-only |
| EXECUTED_ACTIONS | GOVERNANCE | Governance boundary; operator-only |
| AUDIT_LOG | GOVERNANCE | Governance boundary; operator-only |
| OPERATIONAL_DOCUMENTS | KNOWLEDGE | Unstructured; served by Cortex Search (Phase 3B) |

## Metrics

### Per-Table Metrics

| Metric | Table | Expression |
|--------|-------|-----------|
| PLANT_COUNT | PLANTS | COUNT(DISTINCT PLANT_ID) |
| LINE_COUNT | PRODUCTION_LINES | COUNT(DISTINCT LINE_ID) |
| MACHINE_COUNT | MACHINES | COUNT(DISTINCT MACHINE_ID) |
| AVG_SENSOR_VALUE | SENSOR_READINGS | AVG(VALUE) |
| MAX_SENSOR_VALUE | SENSOR_READINGS | MAX(VALUE) |
| MIN_SENSOR_VALUE | SENSOR_READINGS | MIN(VALUE) |
| AVG_OEE | OEE_METRICS | AVG(OEE_PCT) |
| AVG_AVAILABILITY | OEE_METRICS | AVG(AVAILABILITY_PCT) |
| AVG_PERFORMANCE | OEE_METRICS | AVG(PERFORMANCE_PCT) |
| AVG_QUALITY | OEE_METRICS | AVG(QUALITY_PCT) |
| TOTAL_DOWNTIME_MINUTES | OEE_METRICS | SUM(DOWNTIME_MINUTES) |
| MAINTENANCE_COUNT | MAINTENANCE_HISTORY | COUNT(MAINTENANCE_ID) |
| TOTAL_MAINTENANCE_COST | MAINTENANCE_HISTORY | SUM(COST_USD) |
| FAILURE_COUNT | FAILURE_HISTORY | COUNT(FAILURE_ID) |
| TOTAL_REPAIR_COST | FAILURE_HISTORY | SUM(REPAIR_COST_USD) |
| WORK_ORDER_COUNT | WORK_ORDERS | COUNT(WO_ID) |
| ANOMALY_COUNT | ANOMALY_SIGNALS | COUNT(ANOMALY_ID) |
| MAX_DEVIATION | ANOMALY_SIGNALS | MAX(DEVIATION_PCT) |

## Business Terminology

The semantic model includes synonyms for business-friendly querying:

- "equipment" / "assets" -> MACHINES
- "telemetry" / "sensor data" -> SENSOR_READINGS
- "OEE" / "equipment effectiveness" -> OEE_METRICS
- "maintenance" / "service history" -> MAINTENANCE_HISTORY
- "failures" / "breakdowns" -> FAILURE_HISTORY
- "work orders" / "WOs" -> WORK_ORDERS
- "anomalies" / "alerts" -> ANOMALY_SIGNALS
- "vibration" / "bearing_temp" -> SENSOR_TYPE filter values
- "availability" / "quality" / "performance" -> OEE component facts

## Cortex Analyst Validation

Tested with 11 natural-language questions. All generated valid SQL.

### Investigation Questions (7/7 PASS)

| # | Question | SQL Generated | Correct |
|---|----------|:---:|:---:|
| Q1 | Which machines show strongest signs of degradation? | Yes | Yes |
| Q2 | How has vibration changed over time for degraded machines? | Yes | Yes |
| Q3 | Vibration correlated with bearing temperature? | Yes | Yes |
| Q4 | How has OEE changed for affected equipment? | Yes | Partial |
| Q5 | Overdue or missing preventive maintenance? | Yes | Yes |
| Q6 | Peer machines on same line showing similar behavior? | Yes | Yes |
| Q7 | Similar machines with historical failures? | Yes | Yes |

Q4 note: Cortex Analyst filtered on machine status='degraded', but all machines have status='operational' (degradation is in the metrics, not status field). The agent will provide context that lets Analyst identify the correct machines. This is expected behavior.

### Generalization Questions (4/4 PASS)

| # | Question | SQL Generated | Correct |
|---|----------|:---:|:---:|
| G1 | Total downtime by plant this month? | Yes | Yes |
| G2 | Which production lines have highest defect rates? | Yes | Yes |
| G3 | Most common failure modes across all machines? | Yes | Yes |
| G4 | Average OEE by machine type? | Yes | Yes |

## Known Limitations

1. **Ambiguous "affected" queries**: Without explicit machine context, Cortex Analyst may filter on status field rather than metric patterns. The future Cortex Agent provides this context.
2. **Sensor readings are long-format**: Questions must filter on sensor_type. Custom instructions guide this but complex multi-sensor correlations may need the agent to issue multiple queries.
3. **No Cortex Search integration yet**: Operational documents (SOPs, threshold guides) are not accessible through this semantic layer. Phase 3B adds Cortex Search.
4. **FUTURE TABLES grants**: ANALYST has SELECT on FUTURE TABLES for CORE, KNOWLEDGE, AI schemas — new tables added to these schemas will be automatically accessible.

## Deployment

```sql
-- Deploy from version-controlled YAML
-- setup/sql/07_semantic_view.sql
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('OPSMIND.APP', $$...$$);
```

Source of truth: `semantic/opsmind_operations.yaml`
