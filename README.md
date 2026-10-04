# OpsMind AI

**Enterprise Operations Intelligence Platform — powered by Snowflake Cortex**

> An AI operations engineer that continuously understands equipment health, explains operational degradation using evidence from multiple enterprise systems, quantifies operational impact, and coordinates corrective action under human governance.

**Hackathon:** Snowflake CoCo CLI Hackathon — GCC Edition  
**Problem Statement #3:** Predictive Maintenance & OEE Command Center  
**Team:** SoloOps — Pratik Pritam  

---

## The Problem

Manufacturing operations teams manage fleets where telemetry, OEE, maintenance records, failure history, work orders, and operating procedures are fragmented across systems. When degradation begins:

- dashboards expose symptoms but engineers still have to correlate the evidence manually;
- root causes often sit at the intersection of sensor trends, maintenance gaps, and historical patterns;
- operational knowledge in SOPs and threshold guides is disconnected from live data;
- technical alerts rarely quantify the business trade-off between planned intervention and unplanned failure; and
- AI recommendations cannot be trusted to execute consequential actions without explicit human authority.

OpsMind AI closes this gap with an evidence-grounded, governed operational loop inside Snowflake.

## The Solution

```text
DETECT → INVESTIGATE → EXPLAIN → QUANTIFY IMPACT
      → RECOMMEND → HUMAN APPROVE → EXECUTE → AUDIT
```

| Phase | What happens |
|---|---|
| **Detect** | A condition-based Equipment Failure Risk Index surfaces elevated-risk assets. |
| **Investigate** | Cortex Agent queries structured operations data and retrieves relevant SOPs/guidelines. |
| **Explain** | Independent evidence streams are correlated into an understandable operational hypothesis. |
| **Quantify Impact** | Governed deterministic scenarios compare planned intervention with unplanned failure. |
| **Recommend** | Corrective actions are prioritized from the converging evidence. |
| **Human Approve** | Recommendations require explicit human approval; the Agent cannot self-approve. |
| **Execute** | Approved actions flow through governed `EXECUTE AS OWNER` procedures. |
| **Audit** | Lifecycle events retain actor, timestamp, decision, and execution history. |

**OpsMind is not just a chatbot or dashboard. AI investigates and explains; deterministic services calculate authoritative values; humans retain authority over consequential actions.**

## Key Capabilities

- **Fleet-wide condition risk** — 5-factor Equipment Failure Risk Index (0–100) from vibration, thermal, OEE, and maintenance signals.
- **Explainable risk factors** — factor scores and data completeness are exposed rather than hidden behind a black-box prediction.
- **OEE + telemetry degradation analysis** — latest OEE is presented once per machine with supporting sensor and anomaly trends.
- **Evidence-grounded AI investigation** — Cortex Agent combines Cortex Analyst structured analytics with Cortex Search operational knowledge.
- **Multi-turn investigation** — follow-ups such as *“Summarize it in 3 bullet points”* retain the current Streamlit-session investigation context.
- **Suggested investigations** — one-click prompts enter the same guarded execution path as typed questions.
- **Safe interaction lifecycle** — Enter or **Investigate** submits exactly one request; input/suggestions/clear controls are disabled while processing; the question field resets after completion.
- **Governed business impact** — deterministic planned-vs-unplanned scenarios with assumption provenance.
- **Human-in-the-loop governance** — approval and execution are separated from Agent reasoning.
- **Complete auditability** — approval, rejection, and execution events retain authenticated actor information.
- **Least-privilege security** — dedicated roles, strict procedure boundaries, and governed configuration hidden from Agent/Analyst access.

## Validated Demo Scenario — M-302

The synthetic demo fleet contains **11 machines across 2 plants**. The same risk logic is applied to every machine.

### Detection

**M-302 — CNC Finishing Mill #2** is surfaced as the fleet asset requiring attention:

- Equipment Failure Risk Index: **69.7 — HIGH**
- Data quality: **COMPLETE**
- Healthy peers remain **LOW**
- Evidence includes OEE decline, vibration anomaly, thermal anomaly, and overdue bearing maintenance

> The Equipment Failure Risk Index is a deterministic, condition-based heuristic score. It is **not** a calibrated probability of failure and does **not** predict exact time-to-failure or Remaining Useful Life.

### Explainable Risk Factors

| Factor | Score |
|---|---:|
| Vibration level | 54.9 |
| Vibration trend | 70.8 |
| Thermal deviation | 61.1 |
| OEE degradation | 94.7 |
| Maintenance overdue | 84.0 |

The Command Center also exposes OEE trends, 7-day sensor trends, maintenance history, failure history, and recent anomaly signals so an operator can inspect the evidence behind the score.

### AI Investigator

The AI Investigator supports both typed and suggested investigations. A validated multi-turn sequence is:

```text
Why is M-302 at elevated risk?
Summarize it in 3 bullet points.
```

The follow-up retains the previous M-302 investigation context within the current Streamlit session. The Agent remains **read-only**: it can investigate, retrieve evidence, and explain recommendations, but it cannot approve or execute actions.

### Business Impact — Evidence-Aligned Scenario

For M-302, the UI promotes **Bearing — Evidence-Aligned Scenario**:

| Scenario | Governed estimate |
|---|---:|
| Planned intervention | **$13,300** |
| Unplanned failure | **$44,900** |
| **Potential avoided impact** | **$31,600** |

These values are deterministic estimates derived from governed synthetic assumptions. They are **not predictions or guaranteed savings**.

### Governed Action

The validated lifecycle separates reasoning from authority:

1. recommendation is created;
2. a human reviews evidence and approves/rejects with justification;
3. only an approved action can be executed through the governed procedure; and
4. the complete lifecycle is retained in the audit trail.

Historical records are preserved. Records without a verified actor remain visible for audit but are blocked from execution in the UI.

## Snowflake-Native Architecture

```text
OPERATIONAL DATA                         OPERATIONAL KNOWLEDGE
Telemetry • OEE • Maintenance            SOPs • Thresholds
Failures • Work Orders • Anomalies       Inspection / Troubleshooting
             │                                      │
             ▼                                      ▼
   ┌──────────────────────┐               ┌──────────────────┐
   │ Snowflake Data Layer │               │  Cortex Search   │
   │ Risk + Impact SQL    │               │ Knowledge Ground │
   └──────────┬───────────┘               └────────┬─────────┘
              ▼                                    │
      ┌───────────────┐                            │
      │ Semantic View │◄───────────────────────────┘
      │ Cortex Analyst│
      └───────┬───────┘
              ▼
      ┌────────────────────┐
      │    Cortex Agent    │
      │ OperationsAnalyst  │
      │ KnowledgeSearch    │
      │ READ-ONLY          │
      └─────────┬──────────┘
                ▼
      ┌────────────────────┐
      │ Streamlit Command  │
      │ Center — 5 views   │
      └─────────┬──────────┘
                ▼
       HUMAN APPROVAL GATE
                │
                ▼
      EXECUTE AS OWNER procedures
                │
                ▼
            AUDIT TRAIL
```

The Agent has **no write authority**. State changes flow through human approval and governed stored procedures.

## Snowflake & CoCo Technologies

| Technology | Usage |
|---|---|
| **Snowflake** | Data platform, tables, views, procedures, RBAC, sequences |
| **Cortex Agent** | Multi-tool operational investigation |
| **Cortex Analyst / Semantic View** | Natural-language structured analytics over the operational model |
| **Cortex Search** | Retrieval over SOPs, thresholds, inspection and troubleshooting documents |
| **Streamlit in Snowflake** | Five-view OpsMind AI Command Center |
| **Snowpark** | Session management, parameterized query execution, procedure calls |
| **Snowflake RBAC** | Least-privilege role hierarchy and governed configuration boundaries |
| **Stored Procedures** | `EXECUTE AS OWNER` approval/execution state machine |
| **Cortex Code (CoCo) CLI** | Primary implementation, deployment, and validation workflow |
| **CoCo Skills** | Reusable investigation, deployment-validation, and security-validation workflows |

## CoCo Skills

### `$operations-investigation`
Evidence-grounded asset investigation across risk, telemetry, OEE, maintenance/failure history, operational knowledge, and impact.

### `$deployment-validation`
Repeatable validation of deployed Snowflake objects, Streamlit runtime contracts, Semantic View, Cortex Search, Cortex Agent, and regression checks.

### `$security-rbac-validation`
Positive/negative access testing under explicit role isolation (`USE SECONDARY ROLES NONE`), including governed-config denial, direct-DML denial, secret scans, and unsupported-claim checks.

## Command Center

| View | Purpose |
|---|---|
| **Operations Overview** | Fleet Risk Summary, Attention Required, plant inventory, one latest-OEE row per machine, recent anomaly signals |
| **Asset Intelligence** | Machine risk drill-down, factor breakdown, OEE/sensor trends, maintenance/failure history, business-impact scenarios |
| **AI Investigator** | Cortex Agent investigation with suggested prompts, Enter/click submission, session-scoped multi-turn context, and duplicate-request protection |
| **Decision Center** | Pending approval, ready-to-execute, and history; invalid-actor historical approvals are preserved but not executable |
| **Audit & Governance** | Approval decisions, executed actions, and lifecycle audit history |

## Security & Governance

Security is a core part of the design.

- **Agent:** read-only investigation; no approval or execution side effects.
- **Governed configuration:** impact assumptions and risk-threshold configuration are not exposed to unintended Agent/Analyst access.
- **Human authority:** approval requires explicit user action and justification.
- **Execution:** only approved actions can pass through owner-rights procedures.
- **Authenticated actor:** Streamlit passes the authenticated viewer identity into governed procedures.
- **Least privilege:** effective grants were validated with secondary roles disabled.
- **Audit preservation:** historical records are retained rather than rewritten to make a demo look cleaner.

## Data Model

**14 entities** span operational hierarchy, telemetry/OEE/anomalies, maintenance/reliability, decision/governance, and operational knowledge.

Key entities include:

`PLANTS`, `PRODUCTION_LINES`, `MACHINES`, `SENSOR_READINGS`, `OEE_METRICS`, `ANOMALY_SIGNALS`, `MAINTENANCE_HISTORY`, `FAILURE_HISTORY`, `WORK_ORDERS`, `RECOMMENDATIONS`, `APPROVAL_DECISIONS`, `EXECUTED_ACTIONS`, `AUDIT_LOG`, `OPERATIONAL_DOCUMENTS`.

## Repository Structure

```text
opsmind-ai/
├── .cortex/skills/             # 3 reusable CoCo Skills
├── architecture/               # architecture / design documentation
├── agent/                      # Cortex Agent specification
├── semantic/                   # Semantic View definition
├── search/                     # operational knowledge source documents
├── setup/
│   ├── sql/                    # ordered Snowflake deployment scripts
│   └── data/                   # synthetic seed data
├── streamlit/
│   ├── streamlit_app.py        # five-view Command Center
│   ├── src/                    # queries, agent, UI components
│   ├── snowflake.yml
│   └── .streamlit/
├── tests/
├── scripts/
└── docs/
```

## Deployment

The application is deployed as:

`OPSMIND.APP.OPSMIND_COMMAND_CENTER`

**App-viewer URL**

`https://app.snowflake.com/streamlit/FPGVDTH/ST12623/#/apps/5iprinhv6tz7do64lqe5`

Snowflake's app-viewer URL removes the Snowsight builder interface. Direct viewer access still follows Snowflake authentication/RBAC; the hackathon demo video therefore provides the judge-accessible product walkthrough.

## Demo Walkthrough — 3–5 Minutes

1. **Operations Overview** — show **1 HIGH / 10 LOW** and M-302 in **Attention Required**.
2. **Asset Intelligence** — open M-302; show **69.7 HIGH**, factor breakdown, OEE and sensor trends.
3. **AI Investigator** — ask **“Why is M-302 at elevated risk?”**
4. **Multi-turn follow-up** — ask **“Summarize it in 3 bullet points.”**
5. **Business Impact** — show **Bearing — Evidence-Aligned Scenario**: $13.3K planned / $44.9K unplanned / $31.6K potential avoided impact.
6. **Decision Center** — explain that AI cannot approve or execute its own recommendation.
7. **Audit & Governance** — show the validated recommendation → approval → execution lifecycle and authenticated actor.
8. **Close** — AI explains; deterministic services calculate; humans authorize.

## Design Principles

- **Evidence before recommendation**
- **Deterministic authoritative values**
- **LLM explains; it does not invent authoritative numbers**
- **Human authority over consequential actions**
- **Least privilege**
- **Auditability**
- **Generalization across the fleet**
