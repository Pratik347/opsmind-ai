# Architecture Decision Records

This document records the key architectural decisions for OpsMind AI.

Each decision is numbered, dated, and includes context, the decision itself, and its consequences. Decisions are append-only — superseded decisions are marked as such, not deleted.

---

## ADR-001: Snowflake as Primary Enterprise Data and AI Platform

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
OpsMind AI requires a platform that provides data warehousing, AI/ML capabilities, unstructured data retrieval, and application hosting in a unified governed environment. The hackathon targets the Snowflake ecosystem specifically.

**Decision:**
Snowflake is the primary enterprise data and AI platform for OpsMind AI. All data storage, AI orchestration, search, and application hosting will use Snowflake-native services.

**Consequences:**
- All data resides within Snowflake's governance boundary.
- AI features use Cortex functions rather than external AI services.
- Deployment is simplified to a single platform.
- Feature availability is constrained by the Snowflake account's region and edition.

---

## ADR-002: Streamlit as Deployed UI

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
The application needs a web interface for human interaction with the investigation workflow. Streamlit in Snowflake (SiS) provides a managed deployment with native Snowflake session context.

**Decision:**
The deployed user interface will use Streamlit in Snowflake.

**Consequences:**
- No separate web server infrastructure required.
- Native access to Snowflake session and role context.
- UI capabilities are constrained to Streamlit's widget set.
- Agent API integration must account for SiS runtime limitations (see ADR-006).

---

## ADR-003: Cortex Agent as Investigation Orchestrator

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
The core OpsMind workflow requires multi-step reasoning across structured and unstructured data sources. Cortex Agents provide autonomous tool selection, planning, and reflection within Snowflake's governed environment.

**Decision:**
A Cortex Agent will orchestrate enterprise investigation workflows, combining Cortex Analyst for structured data queries and Cortex Search for document retrieval.

**Consequences:**
- The agent handles tool selection and multi-step reasoning autonomously.
- Investigation quality depends on the agent's semantic view definitions and search service configuration.
- Cost scales with token usage across orchestration, Analyst, and Search.
- The agent specification is declarative and version-controllable via SQL DDL.

---

## ADR-004: Cortex Analyst for Governed Structured-Data Analysis

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
OpsMind needs to query operational metrics (revenue, incidents, SLAs) with natural language. Cortex Analyst converts natural language to SQL using semantic views that define business metrics, dimensions, and relationships.

**Decision:**
Cortex Analyst, accessed through semantic views, will provide governed structured-data analysis within the agent's investigation workflow.

**Consequences:**
- Business metrics have a single authoritative definition in the semantic view.
- Query accuracy depends on semantic view quality (descriptions, relationships, verified queries).
- The semantic view acts as a governed abstraction over physical tables.
- Semantic views are version-controllable as SQL DDL or YAML.

---

## ADR-005: Cortex Search for Operational Document Retrieval

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
Investigations require context from unstructured sources: runbooks, incident reports, change logs, and policy documents. Cortex Search provides hybrid (vector + keyword) retrieval over text data stored in Snowflake.

**Decision:**
Cortex Search will provide retrieval over operational documents within the agent's investigation workflow.

**Consequences:**
- Documents must be ingested into Snowflake tables with appropriate text columns.
- Search service definitions are version-controllable as SQL DDL.
- Retrieval quality depends on document chunking strategy and column configuration.
- Search services incur ongoing cost based on index size and persistence.

---

## ADR-006: DATA_AGENT_RUN() for Streamlit-Agent Integration

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
Cortex Agents REST API is not supported from Streamlit in Snowflake using warehouse runtime. Container runtime supports the REST API but adds deployment complexity. The SQL function `SNOWFLAKE.CORTEX.DATA_AGENT_RUN()` can invoke agents from any SQL execution context including SiS warehouse runtime.

**Decision:**
The Streamlit warehouse-runtime implementation will invoke the Cortex Agent using `SNOWFLAKE.CORTEX.DATA_AGENT_RUN()` unless testing identifies a blocker. If a blocker is found, the fallback is container runtime with direct REST API calls.

**Consequences:**
- Simpler deployment (no SPCS container setup required).
- Responses are returned as complete JSON rather than streamed events.
- Thread/conversation state management must be handled through the function's parameters.
- This decision will be validated during integration testing and may be revised.

---

## ADR-007: Separation of Operational Actions from Analytical Reasoning

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
An AI system that can both analyze problems and execute remediation actions poses governance risks. Analytical errors should not cascade into operational damage.

**Decision:**
Operational actions will be separated from analytical reasoning and require human approval where appropriate. The agent may recommend actions, but execution of consequential operations requires explicit human confirmation.

**Consequences:**
- The investigation workflow includes an explicit APPROVE gate before EXECUTE.
- The agent's tool configuration does not include write-access procedures without approval mechanisms.
- The UI must surface recommendations with supporting evidence and provide approval controls.
- Audit trail captures both the recommendation and the approval decision.

---

## ADR-008: Evidence Transparency for AI Conclusions

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
Enterprise users need to trust and verify AI-generated conclusions. Black-box answers are insufficient for operational decisions with business impact.

**Decision:**
Every material AI conclusion must expose supporting evidence. This includes the data queries executed, documents retrieved, reasoning steps taken, and confidence indicators.

**Consequences:**
- The UI must render evidence alongside conclusions (SQL queries, document citations, reasoning traces).
- Agent responses must be structured to separate conclusions from supporting evidence.
- This may require post-processing of agent output to extract and format evidence components.
- Investigation audit trails are comprehensive by design.

---

## ADR-009: Infrastructure as Code

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
Reproducibility is essential for both hackathon judging (demonstrating the deployment workflow) and production readiness. Manual Snowflake configuration creates undocumented dependencies.

**Decision:**
All deployable Snowflake objects must be reproducible from version-controlled source. The GitHub repository is the source of truth for all infrastructure definitions.

**Consequences:**
- Every database, schema, table, view, semantic view, search service, agent, and Streamlit app has a corresponding SQL definition in the repository.
- Setup scripts are numbered and ordered for sequential execution.
- No manual Snowflake configuration is required beyond initial account-level privileges.
- Changes to infrastructure require a commit, not a Snowsight click.

---

## ADR-010: Hackathon Demo Requirements

**Date:** 2026-09-27
**Status:** Accepted

**Context:**
The hackathon submission requires a public GitHub repository, a deployed prototype, an end-to-end workflow, visible CoCo CLI usage, and demonstration of 2-3 modular CoCo capabilities.

**Decision:**
The hackathon demo must visibly demonstrate at least three modular CoCo capabilities through one complete end-to-end investigation workflow. The demo scenario will exercise the full DETECT-through-AUDIT pipeline.

**Consequences:**
- At least three CoCo skills will be developed and committed to `.cortex/skills/`.
- The demo script will be designed to showcase CoCo orchestration visibly.
- The end-to-end scenario must be self-contained and reproducible.
- Documentation must clearly identify which CoCo capabilities are demonstrated.
