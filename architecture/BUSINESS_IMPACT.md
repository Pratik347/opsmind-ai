# Business Impact Engine — Architecture

## Overview

The Business Impact Engine provides deterministic, traceable cost comparison
estimates between planned intervention and unplanned failure scenarios for any
machine and component combination. All calculations are performed in SQL (no
LLM involvement in the math), and all financial assumptions are explicitly
governed with full provenance tracking.

## Design Principles

1. **Deterministic math** — All cost calculations are SQL expressions in a
   view. The LLM reads results; it does not compute them.
2. **Assumption governance** — Every financial parameter is stored in a
   governed table with `ASSUMPTION_SOURCE`, `ASSUMPTION_BASIS`, and
   `ASSUMPTION_VERSION` tracking. Demo values are marked `SYNTHETIC_DEMO`
   with a narrative basis explaining derivation.
3. **Separation of concerns** — Assumptions (governed config) are separated
   from scenarios (calculated output). Changing an assumption automatically
   recalculates all dependent scenarios via the view.
4. **Transparency** — The agent is instructed to always disclose the
   assumption source and basis when presenting impact figures.
5. **No false precision** — All output values are described as "estimates,"
   never "predictions" or "guaranteed savings."
6. **Missing data = unavailable** — If no assumptions exist for a machine
   type/component, no scenario row is produced. No COALESCE or silent
   defaults.

## Security Boundary

```
IMPACT_ASSUMPTIONS (governed config — ACCOUNTADMIN only)
  -> deterministic SQL calculation
  -> IMPACT_SCENARIOS (read boundary — SELECT granted to OPSMIND_ANALYST)
    -> Semantic View (OPSMIND.APP.OPSMIND_OPERATIONS)
      -> Cortex Analyst (OperationsAnalyst tool)
        -> Cortex Agent (OPSMIND.APP.OPSMIND_AGENT)
```

- IMPACT_ASSUMPTIONS is NOT exposed in the semantic layer.
- OPSMIND_ANALYST does NOT have SELECT on IMPACT_ASSUMPTIONS.
- The Agent consumes calculated evidence, not mutable configuration.
- The FUTURE TABLES grant on AI schema is overridden by an explicit REVOKE
  in `10_impact_model.sql` to enforce this boundary.

## Data Model

### OPSMIND.AI.IMPACT_ASSUMPTIONS (Table — governed config)

Stores cost, downtime, and production-value parameters per machine type
and failure component. Not accessible to OPSMIND_ANALYST.

| Column | Type | Description |
|--------|------|-------------|
| ASSUMPTION_ID | VARCHAR(20) | Primary key (e.g., IMP-001) |
| MACHINE_TYPE | VARCHAR(50) | Equipment category |
| FAILURE_COMPONENT | VARCHAR(50) | Component modeled |
| PLANNED_DOWNTIME_HRS | FLOAT | Hours for planned intervention |
| PLANNED_LABOR_COST_USD | FLOAT | Labor cost, planned |
| PLANNED_PARTS_COST_USD | FLOAT | Parts cost, planned |
| UNPLANNED_DOWNTIME_HRS | FLOAT | Hours for unplanned failure |
| EMERGENCY_LABOR_COST_USD | FLOAT | Emergency labor cost |
| EXPEDITED_PARTS_COST_USD | FLOAT | Rush parts cost |
| ESTIMATED_COLLATERAL_REPAIR_COST_USD | FLOAT | Estimated collateral repair cost |
| PRODUCTION_VALUE_PER_UNIT_USD | FLOAT | Value per production unit |
| ASSUMPTION_SOURCE | VARCHAR(50) | Provenance category (SYNTHETIC_DEMO) |
| ASSUMPTION_BASIS | VARCHAR(500) | Narrative derivation explanation |
| ASSUMPTION_VERSION | VARCHAR(10) | Version identifier (v1.0) |
| LAST_UPDATED | TIMESTAMP_NTZ | Last modification timestamp |

**Seed data:** 7 rows covering 4 machine types x key components.

### OPSMIND.AI.IMPACT_SCENARIOS (View — read boundary)

Deterministic view joining assumptions with machine and production line
data. Contains all input assumption values needed to fully reconstruct
each calculation, plus provenance fields.

**Key formulas:**

```
ESTIMATED_PLANNED_PRODUCTION_LOSS = planned_downtime_hrs x design_capacity_per_hr x value_per_unit
ESTIMATED_TOTAL_PLANNED = labor + parts + estimated_planned_production_loss
ESTIMATED_UNPLANNED_PRODUCTION_LOSS = unplanned_downtime_hrs x design_capacity_per_hr x value_per_unit
ESTIMATED_TOTAL_UNPLANNED = emergency_labor + expedited_parts + collateral_repair + estimated_unplanned_production_loss
ESTIMATED_POTENTIAL_AVOIDED = estimated_total_unplanned - estimated_total_planned
```

### Known Limitation: Production Loss Proxy

Production loss is calculated using `DESIGN_CAPACITY_UNITS_HR x
PRODUCTION_VALUE_PER_UNIT_USD`. This is a synthetic production value proxy
based on line design capacity — **not actual realized throughput or
revenue**. The actual production loss may be higher or lower depending on
demand, scheduling, partial-shift impacts, and market value. This limitation
is documented in the semantic model description and the agent is instructed
to disclose it.

## Integration

### Semantic View

Only IMPACT_SCENARIOS is registered in the semantic model. IMPACT_ASSUMPTIONS
is NOT exposed to Cortex Analyst. The IMPACT_SCENARIOS table definition
includes:
- All input assumption values (for reconstruction transparency)
- ASSUMPTION_SOURCE, ASSUMPTION_BASIS, ASSUMPTION_VERSION (provenance)
- All calculated output columns prefixed with ESTIMATED_
- 4 aggregate metrics

The `module_custom_instructions` mandate provenance disclosure and note the
design-capacity proxy limitation.

### Cortex Agent

The agent's orchestration instructions include:
- Step 8: After identifying degradation, query IMPACT_SCENARIOS for cost
  estimates
- What-if routing: Impact questions go to OperationsAnalyst -> IMPACT_SCENARIOS
- Transparency mandate: Always disclose ASSUMPTION_SOURCE and ASSUMPTION_BASIS
- Language mandate: Use "estimates," never "predictions" or "guaranteed savings"
- Proxy disclosure: Note that production loss uses design capacity, not actual
  revenue

## Validation Results

### M-302 Bearing Scenario (Reference)

| Metric | Value |
|--------|-------|
| Estimated planned intervention | $13,300 |
| Estimated unplanned failure | $44,900 |
| Estimated potential avoided impact | $31,600 |
| Estimated avoided downtime | 16 hours |
| Estimated avoided production loss | 1,600 units |
| Line design capacity | 100 units/hr |
| Production value per unit | $15/unit |
| Assumption source | SYNTHETIC_DEMO |
| Assumption version | v1.0 |

### Security Properties

- OPSMIND_ANALYST cannot SELECT on IMPACT_ASSUMPTIONS (verified, revoked)
- Agent cannot modify IMPACT_ASSUMPTIONS (read-only Analyst tool)
- Agent refuses to ignore ASSUMPTION_SOURCE/BASIS labels
- Agent refuses to create work orders (no write tools)
- Agent does not fabricate values for missing assumptions
- Agent explicitly describes values as estimates, not predictions

## Files

| File | Purpose |
|------|---------|
| `setup/sql/10_impact_model.sql` | Table DDL, seed data, view DDL, RBAC (incl. REVOKE) |
| `semantic/opsmind_operations.yaml` | Semantic model (IMPACT_SCENARIOS only, 10 tables) |
| `setup/sql/07_semantic_view.sql` | Inlined YAML deployment SQL |
| `agent/opsmind_agent.yaml` | Agent spec with impact estimate instructions |
| `setup/sql/09_agent.sql` | Agent deployment SQL |
