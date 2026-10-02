# OpsMind AI

**Autonomous Enterprise Operations Intelligence — powered by Snowflake Cortex**

## Vision

OpsMind AI is an enterprise operations intelligence platform that transforms how organizations detect, investigate, and resolve operational anomalies. Built entirely on Snowflake's Cortex AI stack, it combines structured data analysis with unstructured document retrieval to deliver autonomous investigation workflows — from initial anomaly detection through root-cause analysis, impact quantification, and remediation recommendation — with full evidence transparency and human-in-the-loop governance.

## Problem Statement

Enterprise operations teams drown in alerts, dashboards, and siloed data sources. When an anomaly surfaces — a revenue drop, a spike in support tickets, a supply chain disruption — the investigation process is manual, slow, and fragmented:

- Analysts context-switch across dozens of tools and data sources.
- Root causes hide in the intersection of structured metrics and unstructured documents (runbooks, incident reports, change logs).
- Tribal knowledge evaporates with team turnover.
- The same investigation patterns repeat across incidents with no institutional learning.
- Time-to-resolution directly correlates with business impact.

OpsMind AI eliminates this friction by orchestrating a Cortex Agent that autonomously investigates anomalies across structured and unstructured enterprise data, surfaces evidence-backed conclusions, and recommends actions — while keeping humans in control of consequential decisions.

## Core Workflow

```
DETECT → INVESTIGATE → EXPLAIN → PREDICT → QUANTIFY → RECOMMEND → APPROVE → EXECUTE → AUDIT
```

| Phase | Description |
|-------|-------------|
| **DETECT** | Identify anomalies in operational metrics through statistical and AI-driven monitoring |
| **INVESTIGATE** | Autonomously query structured data and retrieve relevant operational documents |
| **EXPLAIN** | Synthesize findings into a coherent root-cause narrative with cited evidence |
| **PREDICT** | Project forward impact if the issue remains unresolved |
| **QUANTIFY** | Calculate business impact in concrete terms (revenue, customers, SLA) |
| **RECOMMEND** | Generate prioritized remediation options with trade-off analysis |
| **APPROVE** | Present recommendations with supporting evidence for human decision |
| **EXECUTE** | Carry out approved actions through governed operational procedures |
| **AUDIT** | Record the full investigation trail for compliance and institutional learning |

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Data Platform | Snowflake |
| AI Orchestration | Cortex Agent |
| Structured Data Analysis | Cortex Analyst + Semantic Views |
| Unstructured Data Retrieval | Cortex Search |
| LLM Functions | Cortex AI Functions (AI_COMPLETE, AI_CLASSIFY, AI_EXTRACT) |
| User Interface | Streamlit in Snowflake |
| Development CLI | Snowflake CoCo (Cortex Code) |
| Infrastructure Definition | SQL DDL scripts (version-controlled) |

## Repository Structure

```
opsmind-ai/
├── .cortex/              # CoCo skills and agent configurations
│   ├── skills/           # Modular CoCo capabilities
│   └── agents/           # Custom subagent definitions
├── architecture/         # Architecture Decision Records (ADRs)
├── setup/
│   ├── sql/              # Snowflake DDL scripts (numbered, ordered)
│   └── data/             # Seed data and sample datasets
├── semantic/             # Semantic view definitions (YAML/SQL)
├── search/               # Cortex Search service definitions and source data
├── agent/                # Cortex Agent specification
├── streamlit/            # Streamlit application source
├── tests/
│   ├── data/             # Test fixtures
│   ├── agent/            # Agent behavior tests
│   └── scenarios/        # End-to-end scenario definitions
├── scripts/              # Deployment and utility scripts
├── docs/                 # Documentation
├── .gitignore
├── README.md
└── LICENSE
```

## Deployment Philosophy

**Infrastructure as code. Reproducible deployment. No snowflakes in Snowflake.**

Every Snowflake object required by OpsMind AI — databases, schemas, tables, semantic views, search services, agents, Streamlit apps — has its creation definition committed to this repository. The deployment process is:

1. Clone the repository.
2. Connect to a Snowflake account with appropriate privileges.
3. Execute the numbered SQL setup scripts in order.
4. Deploy the Streamlit application.
5. Validate with the test scenarios.

No manual Snowflake configuration should be required beyond initial account-level privileges. If it can't be reproduced from source control, it doesn't belong in the deployment.

## Project Status

| Phase | Status |
|-------|--------|
| Environment discovery | Complete |
| Capability verification | Complete |
| Repository scaffold | Complete |
| Data model and scenario design | Complete |
| Snowflake foundation and data deployment | **Complete** |
| Semantic layer (Cortex Analyst) | **Complete** |
| Cortex Search integration | **Complete** |
| Cortex Agent specification | **Complete** |
| Business Impact Engine | **Complete** |
| Governance Engine (Approval/Execution) | **Complete** |
| Failure Risk Index (Predictive Risk) | **Complete** |
| Streamlit UI | Not started |
| CoCo skills | Not started |
| End-to-end testing | Not started |
| Demo preparation | Not started |

---

Built with [Snowflake CoCo](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) (Cortex Code)
