# OpsMind AI

**Enterprise Operations Intelligence Platform — powered by Snowflake Cortex**

An AI operations engineer that continuously understands equipment health, explains operational degradation using evidence from multiple enterprise systems, quantifies operational impact, and coordinates corrective action under human governance.

---

## The Problem

Manufacturing operations teams manage complex fleets of equipment where telemetry, OEE metrics, maintenance records, failure history, and standard operating procedures are fragmented across systems. When degradation begins:

- Traditional dashboards show symptoms but require humans to manually correlate evidence across data sources
- Root causes hide at the intersection of sensor trends, maintenance gaps, and historical failure patterns
- Operational knowledge captured in SOPs and threshold guidelines is disconnected from live data
- AI systems that generate recommendations cannot be trusted to execute consequential actions without human oversight
- The cost difference between planned intervention and unplanned failure can be 3-4x, but teams lack the tools to quantify this in real time

OpsMind AI closes this gap by orchestrating an evidence-grounded investigation loop — from detection through governed action — entirely within Snowflake.

## The Solution

OpsMind AI implements a complete operational intelligence loop:

```
DETECT → INVESTIGATE → EXPLAIN → QUANTIFY IMPACT → RECOMMEND → HUMAN APPROVE → EXECUTE → AUDIT
```

| Phase | What Happens |
|-------|-------------|
| **Detect** | Condition-based failure risk index surfaces elevated-risk equipment from fleet telemetry |
| **Investigate** | Cortex Agent queries structured operational data and retrieves relevant SOPs/guidelines |
| **Explain** | Evidence from independent sources is correlated into a hypothesis with cited sources |
| **Quantify Impact** | Governed business impact engine compares planned intervention vs unplanned failure costs |
| **Recommend** | Prioritized action recommendations grounded in converging evidence |
| **Human Approve** | Recommendations require explicit human approval — the Agent cannot self-approve |
| **Execute** | Approved actions are executed through governed stored procedures (EXECUTE AS OWNER) |
| **Audit** | Every lifecycle event is recorded in an immutable audit trail |

This is not a chatbot or a dashboard. It is a governed intelligence system where AI explains and humans decide.

## Key Capabilities

- **Fleet-wide condition-based failure risk** — 5-factor Equipment Failure Risk Index (0–100) computed from vibration, thermal, OEE, and maintenance signals
- **Explainable risk factors** — individual feature scores exposed for every machine, grounded in documented operational thresholds (ISO 10816-3 adapted)
- **OEE and telemetry degradation analysis** — trend detection across availability, performance, and quality metrics
- **AI evidence-grounded investigation** — Cortex Agent orchestrates structured data queries and knowledge retrieval into structured investigation reports
- **Operational knowledge retrieval** — Cortex Search over SOPs, vibration thresholds, inspection procedures, and troubleshooting guides
- **Governed business impact scenarios** — deterministic planned-vs-unplanned cost comparison with full assumption provenance
- **Human-in-the-loop governance** — recommendations require explicit approval; execution uses least-privilege stored procedures
- **Complete audit trail** — every approval, rejection, and execution is recorded with actor, timestamp, and justification
- **Least-privilege security** — dedicated OPSMIND_STREAMLIT role with narrow CORTEX_AGENT_USER access; governed configuration tables are not exposed to the application layer
- **Generalized behavior** — the system works for any machine in the fleet, correctly reporting healthy equipment as LOW risk without inventing problems

## Demo Scenario

The validated demo scenario demonstrates the complete OpsMind loop using synthetic manufacturing data for a fleet of 11 machines across 2 plants.

### Detection

The Operations Overview surfaces **M-302 (CNC Finishing Mill #2)** with an Equipment Failure Risk Index of **69.7 HIGH** — a 30x separation from the next-highest machine (M-101 at 2.3 LOW). No M-302-specific logic drives this; the risk index computation is identical for all machines.

### Evidence

| Risk Factor | Score | Weight | Raw Value | Context |
|------------|-------|--------|-----------|---------|
| Vibration Level | 54.9 | 30% | 6.11 mm/s | ISO 10816-3 Zone C |
| Vibration Trend | 70.8 | 20% | slope +0.2123 | Increasing over 7-day window |
| Thermal Deviation | 61.1 | 20% | 68.3°C | Above warning threshold (65°C) |
| OEE Degradation | 94.7 | 15% | 60.3% vs 88.7% baseline | 28+ point decline |
| Maintenance Overdue | 84.0 | 15% | 17 days overdue | Bearing inspection past due |

**Composite: 69.7 HIGH** | Data quality: COMPLETE (100% telemetry) | 7-day lookback window | As-of: 2026-09-27

> The Equipment Failure Risk Index is a condition-based composite score using expert-defined operational heuristic weights and thresholds. It is **not** a calibrated probability of failure and does **not** predict exact time-to-failure or Remaining Useful Life.

### AI Investigation

The Cortex Agent synthesizes the evidence into a structured investigation:

> *"Multiple independent evidence streams converge: a rising vibration trend plus elevated thermal and vibration-level scores point to a developing mechanical/bearing issue, while the overdue-maintenance signal suggests preventive upkeep has lapsed — consistent with the sharp OEE decline."*

The Agent identifies the top contributing factors, retrieves relevant SOPs from the knowledge base, and recommends priority bearing/spindle inspection — all with cited data sources and a MEDIUM-HIGH confidence assessment based on evidence convergence.

### Business Impact

The governed impact engine provides deterministic cost comparison for the bearing component:

| Scenario | Estimated Cost |
|----------|---------------|
| Planned intervention | $13,300 |
| Unplanned failure | $44,900 |
| **Potential avoided impact** | **$31,600** |

Source: SYNTHETIC_DEMO assumptions with documented basis. These are governed estimates derived from operational assumptions — not predictions or guaranteed savings.

### Governed Action

1. **Recommendation generated** — emergency bearing inspection for M-302
2. **Human approval** — plant manager reviews evidence and approves
3. **Governed execution** — action executed through EXECUTE AS OWNER procedure
4. **Audit trail** — complete lifecycle recorded: creation → approval → execution

### Healthy-Machine Validation

M-201 (Hydraulic Press A) scores **0.0 LOW** with all five factor scores at 0 and DATA_QUALITY=COMPLETE. The system correctly reports healthy equipment without fabricating problems — proving the solution generalizes rather than targeting a single demo machine.

## Architecture

```
                    OPERATIONAL DATA                      OPERATIONAL KNOWLEDGE
          ┌──────────────────────────────┐           ┌─────────────────────────┐
          │  Sensor Readings (telemetry) │           │  SOPs & Procedures      │
          │  OEE Metrics                 │           │  Vibration Thresholds   │
          │  Maintenance History         │           │  Inspection Guides      │
          │  Failure History             │           │  Troubleshooting Docs   │
          │  Work Orders                 │           └────────────┬────────────┘
          │  Anomaly Signals             │                        │
          └──────────────┬───────────────┘                        │
                         │                                        │
                         ▼                                        ▼
          ┌──────────────────────────────┐           ┌────────────────────────┐
          │    SNOWFLAKE DATA LAYER      │           │    CORTEX SEARCH       │
          │                              │           │   (Arctic Embedding)   │
          │  Equipment Failure Risk Index │           └────────────┬──────────┘
          │  Business Impact Engine      │                        │
          │  Governed Configuration      │                        │
          └──────────────┬───────────────┘                        │
                         │                                        │
                         ▼                                        │
          ┌──────────────────────────────┐                        │
          │    SEMANTIC VIEW             │                        │
          │  (Cortex Analyst interface)  │                        │
          │   12 logical tables          │                        │
          └──────────────┬───────────────┘                        │
                         │                ┌───────────────────────┘
                         ▼                ▼
                ┌─────────────────────────────┐
                │       CORTEX AGENT          │
                │  OperationsAnalyst tool      │
                │  KnowledgeSearch tool        │
                │  (read-only investigation)   │
                └──────────────┬──────────────┘
                               │
                               ▼
                ┌─────────────────────────────┐
                │   STREAMLIT COMMAND CENTER  │
                │   (owner: OPSMIND_STREAMLIT)│
                │                             │
                │  Operations Overview        │
                │  Asset Intelligence         │
                │  AI Investigator            │
                │  Decision Center            │
                │  Audit & Governance         │
                └──────────────┬──────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
          ┌──────────────┐     ┌────────────────────┐
          │ Human        │     │ Governed Procedures │
          │ Approval     │────▶│ (EXECUTE AS OWNER)  │
          │ Gate         │     │                      │
          └──────────────┘     └──────────┬───────────┘
                                          │
                                          ▼
                               ┌────────────────────┐
                               │    AUDIT TRAIL      │
                               │  (immutable log)    │
                               └─────────────────────┘
```

The Agent has **no write access**. All state mutations flow through human approval and governed stored procedures.

## Snowflake and CoCo Technologies Used

| Technology | Usage |
|-----------|-------|
| **Snowflake** | Data platform — tables, views, stored procedures, RBAC, sequences |
| **Cortex Agent** | Orchestrates multi-tool investigation (DATA_AGENT_RUN) |
| **Cortex Analyst / Semantic View** | Natural language to SQL over 12-table operational model |
| **Cortex Search** | Retrieval over operational SOPs and threshold documents (Arctic embedding) |
| **Streamlit in Snowflake** | 5-view Command Center with owner-rights execution model |
| **Snowpark** | Session management, parameterized query execution, procedure calls |
| **Snowflake RBAC** | 5-role hierarchy with least-privilege grants and governed configuration |
| **Stored Procedures** | EXECUTE AS OWNER for governed approval/execution state machine |
| **Cortex Code (CoCo) CLI** | Primary development tool — all implementation authored via CoCo |
| **CoCo Skills** | 3 reusable engineering/operations workflows |

## CoCo Skills

Three CoCo Skills support the OpsMind AI engineering and operations workflow:

### `$operations-investigation`
Evidence-grounded equipment investigation workflow. Guides CoCo through the full investigation loop: risk index assessment, telemetry evidence, maintenance/failure history, knowledge retrieval, business impact, and structured summary. Generalizes to any machine — no hard-coded equipment logic. Enforces correct risk terminology throughout.

### `$deployment-validation`
Repeatable deployment and regression validation. Verifies all Snowflake objects exist, confirms Streamlit ownership (must be OPSMIND_STREAMLIT), validates Semantic View / Cortex Search / Cortex Agent availability, runs read-only smoke tests, and checks Phase 4A/4C regressions. Never mutates data.

### `$security-rbac-validation`
Least-privilege security validation. Tests positive access (required reads, agent invocation, procedure usage) and negative access (governed config blocked, direct DML denied, UPDATE/DELETE denied) under strict role isolation (`USE SECONDARY ROLES NONE`). Includes source-level scans for secrets, direct DML, governed config references, and unsupported predictive claims.

## Command Center

The Streamlit Command Center provides five views covering the complete operational intelligence workflow:

<!-- Screenshot placeholders — capture from the deployed Streamlit app
![Operations Overview](docs/images/operations-overview.png)
![Asset Intelligence](docs/images/asset-intelligence.png)
![AI Investigator](docs/images/ai-investigator.png)
![Decision Center](docs/images/decision-center.png)
![Audit & Governance](docs/images/audit-governance.png)
-->

| View | Purpose |
|------|---------|
| **Operations Overview** | Fleet risk summary, plant inventory, latest OEE by machine, recent anomaly signals |
| **Asset Intelligence** | Per-machine risk drill-down: factor breakdown, OEE trend, sensor charts, maintenance/failure history, business impact scenarios with assumption provenance |
| **AI Investigator** | Natural language investigation via Cortex Agent with multi-turn conversation, suggested investigation prompts, and structured response rendering |
| **Decision Center** | Three-tab governance workflow: pending approval, ready-to-execute, and full recommendation history. Approve/reject with justification; execute through governed procedures |
| **Audit & Governance** | Complete audit log, approval decisions, and executed actions history |

## Security and Governance

Security is a core differentiator, not an afterthought.

**Execution model**: The Streamlit app runs with **owner's rights** under the `OPSMIND_STREAMLIT` role — a dedicated least-privilege role that inherits from OPSMIND_OPERATOR (which inherits from OPSMIND_ANALYST).

**Agent access**: Uses the narrow `SNOWFLAKE.CORTEX_AGENT_USER` database role — not the broad `CORTEX_USER`.

**What the application CAN do**:
- Read operational data (CORE schema), analytical outputs (risk scores, impact scenarios, recommendations), and governance history
- Invoke the Cortex Agent for investigation (read-only)
- Call governed stored procedures for approval/execution (EXECUTE AS OWNER)

**What the application CANNOT do**:
- Read governed configuration (IMPACT_ASSUMPTIONS, MACHINE_RISK_THRESHOLDS)
- Directly INSERT into governance tables (must use procedures)
- Directly UPDATE or DELETE recommendations (must use procedures)
- TRUNCATE or DELETE audit records
- Create objects or grant privileges

**Human authority**: The Agent generates recommendations and explains evidence. It cannot approve or execute actions. Approval requires explicit human action with justification. Execution flows through governed procedures that enforce state-machine transitions (pending → approved → executed) with concurrency safety.

## Data Model

14 entities organized across 5 schemas:

**Operational Hierarchy** (CORE)

| Entity | Description |
|--------|-------------|
| PLANTS | Manufacturing facilities with region and capacity |
| PRODUCTION_LINES | Lines within plants with design capacity |
| MACHINES | Equipment with type, criticality, and installation date |

**Operational Signals** (CORE)

| Entity | Description |
|--------|-------------|
| SENSOR_READINGS | Time-series telemetry (vibration, bearing temp, spindle speed, power) |
| OEE_METRICS | Daily availability, performance, quality, composite OEE per machine/shift |
| ANOMALY_SIGNALS | System-detected anomaly indicators with severity and confidence |

**Maintenance and Reliability** (CORE)

| Entity | Description |
|--------|-------------|
| MAINTENANCE_HISTORY | Scheduled and completed maintenance with component and cost |
| FAILURE_HISTORY | Historical failure events with root cause, downtime, and repair cost |
| WORK_ORDERS | Maintenance work orders linked to recommendations |

**Decision and Governance** (AI + GOVERNANCE)

| Entity | Description |
|--------|-------------|
| RECOMMENDATIONS | AI-generated action recommendations with priority and status |
| APPROVAL_DECISIONS | Human approval/rejection records with justification |
| EXECUTED_ACTIONS | Governed action execution records |
| AUDIT_LOG | Immutable event log for the complete recommendation lifecycle |

**Knowledge** (KNOWLEDGE)

| Entity | Description |
|--------|-------------|
| OPERATIONAL_DOCUMENTS | SOPs, threshold guidelines, inspection procedures, troubleshooting guides |

## Repository Structure

```
opsmind-ai/
├── .cortex/
│   ├── skills/              # CoCo Skills (3 implemented)
│   │   ├── operations-investigation/
│   │   ├── deployment-validation/
│   │   └── security-rbac-validation/
│   └── agents/              # Custom CoCo agent configurations
├── architecture/            # Architecture documentation (10 docs)
├── agent/                   # Cortex Agent YAML specification
├── semantic/                # Semantic View YAML (12 logical tables)
├── search/                  # Cortex Search source documents (4 docs)
├── setup/
│   ├── sql/                 # Snowflake DDL scripts (00–14, ordered)
│   └── data/                # Seed data CSVs
├── streamlit/               # Streamlit Command Center
│   ├── streamlit_app.py     # Main application (5 views)
│   ├── src/                 # Modules: queries, agent, components
│   ├── snowflake.yml        # Deployment manifest
│   └── .streamlit/          # Theme configuration
├── tests/                   # Test SQL and fixtures
├── scripts/                 # Seed data generation and validation
└── docs/                    # Documentation
```

## Setup and Deployment

### Prerequisites

- Snowflake account with ACCOUNTADMIN access
- Snowflake CoCo (Cortex Code) CLI
- Cortex Agent, Cortex Analyst, and Cortex Search enabled in the account

### Deployment

All Snowflake objects are defined as version-controlled SQL scripts. Deploy in order:

```
setup/sql/00_context.sql           # Session context
setup/sql/01_database_schemas.sql  # OPSMIND database and 6 schemas
setup/sql/02_roles_grants.sql      # RBAC role hierarchy
setup/sql/03_tables.sql            # Core data tables
setup/sql/04_stages_file_formats.sql
setup/sql/05_load_seed_data.sql    # Synthetic demo data
setup/sql/05b_load_document_content.sql
setup/sql/06_validate.sql          # Data validation
setup/sql/07_semantic_view.sql     # Cortex Analyst semantic model
setup/sql/08_cortex_search.sql     # Knowledge retrieval service
setup/sql/09_agent.sql             # Cortex Agent
setup/sql/10_impact_model.sql      # Business impact engine
setup/sql/11_governance_enforcement.sql  # State machine + RBAC hardening
setup/sql/12_predictive_risk.sql   # Equipment Failure Risk Index
setup/sql/14_streamlit_role.sql    # Streamlit role + app deployment
```

Demo data is entirely synthetic. Financial assumptions are documented with provenance in ASSUMPTION_SOURCE and ASSUMPTION_BASIS fields.

### Pre-Demo Preparation

```
setup/sql/13_demo_prepare.sql      # Insert fresh pending recommendation
```

Run this script before each live demo to ensure the Decision Center has an actionable pending recommendation.

## Demo Walkthrough (3–5 minutes)

1. **Operations Overview** — open the Command Center; fleet risk summary shows 1 HIGH, 10 LOW
2. **M-302 surfaces** — highest-risk machine is immediately visible without searching
3. **Asset Intelligence** — select M-302; view risk factor breakdown, OEE trend chart, sensor trends
4. **AI Investigator** — ask: *"Why is M-302 at elevated risk and what should we do?"*
5. **Agent response** — structured investigation with observations, risk assessment, hypothesis, and recommendation
6. **Business impact** — bearing scenario shows $31,600 potential avoided impact (governed assumptions)
7. **Decision Center** — pending recommendation visible with evidence summary
8. **Approve** — enter justification, approve the recommendation
9. **Execute** — execute the approved action through the governed procedure
10. **Audit & Governance** — complete lifecycle trail: creation → approval → execution

## Design Principles

- **Evidence before recommendation** — the Agent investigates and cites sources before suggesting action
- **Deterministic authoritative values** — risk scores and financial impact are computed by SQL views with documented methodology, not generated by LLMs
- **LLM explains, does not invent** — the Agent synthesizes and correlates existing evidence; it does not fabricate sensor readings or financial numbers
- **Human authority over consequential actions** — recommendations require explicit human approval and justification
- **Least privilege** — every role has exactly the access it needs; governed configuration is hidden from the application layer
- **Auditability** — every state transition is recorded with actor, timestamp, and justification
- **Generalization** — identical computation for all machines; no hard-coded demo behavior

The Equipment Failure Risk Index uses expert-defined operational heuristic weights and thresholds grounded in ISO 10816-3 adapted vibration zones. It is a deterministic SQL computation — not a trained ML model, not a calibrated probability, and not a time-to-failure prediction.

## Known Limitations

- **Synthetic dataset** — demo data and financial assumptions are synthetic; real deployment would use actual operational data
- **Risk index is heuristic** — composite weights and risk bands are expert-defined, not statistically calibrated against observed failure rates
- **No time-to-failure prediction** — the system assesses current condition risk, not when failure will occur
- **Small knowledge corpus** — 4 operational documents; production deployment would include a broader SOP library
- **DATA_AGENT_RUN constant-string constraint** — Snowflake requires the request body as a string constant; Snowpark bind variables cannot be used (documented mitigation: json.dumps structural escaping)

## Hackathon Alignment

**Problem Statement #3: Predictive Maintenance & OEE Command Center**

| Dimension | OpsMind AI Approach |
|-----------|-------------------|
| **Condition-based maintenance** | 5-factor Equipment Failure Risk Index computed from vibration, thermal, OEE, and maintenance signals with documented thresholds |
| **OEE degradation** | Trend analysis across availability, performance, and quality with baseline comparison |
| **Explainable intelligence** | Cortex Agent produces structured investigations with cited evidence, not black-box predictions |
| **Business impact** | Governed what-if engine comparing planned intervention vs unplanned failure with assumption provenance |
| **Governed corrective action** | Human-in-the-loop approval, EXECUTE AS OWNER procedures, complete audit trail |

**Real-world relevance**: Manufacturing operations teams manage complex fleets where the cost of unplanned downtime dwarfs the cost of planned intervention. OpsMind AI bridges the gap between detection and governed action.

**Technical execution**: Built entirely on Snowflake Cortex — Agent, Analyst, Search, Streamlit — with infrastructure-as-code deployment, least-privilege RBAC, and parameterized queries throughout.

**Solution completeness**: End-to-end from detection through audit, with 3 CoCo Skills for repeatable engineering workflows, comprehensive security validation, and healthy-machine generalization proof.

## Project Status

| Component | Status |
|-----------|--------|
| Snowflake data platform (6 schemas, 14 entities) | Deployed |
| Cortex Analyst / Semantic View (12 logical tables) | Deployed |
| Cortex Search (4 operational documents) | Deployed |
| Cortex Agent (2 tools: OperationsAnalyst + KnowledgeSearch) | Deployed |
| Business Impact Engine (governed what-if scenarios) | Deployed |
| Governance Engine (approval/execution state machine) | Deployed |
| Equipment Failure Risk Index (5-factor composite) | Deployed |
| Streamlit Command Center (5 views, owner-rights) | Deployed |
| CoCo Skills (3 engineering workflows) | Implemented |
| End-to-end validation | **PASS** |
| Security/RBAC validation | **PASS** |
| Demo readiness | **YES** |

---

Built with [Snowflake CoCo](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) (Cortex Code)
