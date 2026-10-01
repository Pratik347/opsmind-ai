# Governance Engine — Architecture

## Overview

Phase 4B enforces the governance chain that Phases 1–4A modeled as passive
data. Two stored procedures implement a state machine over the
RECOMMENDATIONS → APPROVAL_DECISIONS → EXECUTED_ACTIONS chain. All
mutations go through these procedures, which enforce pre-conditions,
capture identity, provide atomicity, and write audit entries.

## State Machine

```
                ┌──────────────────────────────┐
                │     RECOMMENDATIONS.STATUS    │
                └──────────────────────────────┘

    ┌─────────┐     APPROVE_RECOMMENDATION     ┌──────────┐
    │ pending │ ──────────('approved')────────> │ approved │
    │         │                                 │          │
    │         │     APPROVE_RECOMMENDATION      └─────┬────┘
    │         │ ──────────('rejected')────────> ┌─────┴──────────┐
    └─────────┘                                │   rejected     │
                                               │  (terminal)    │
                EXECUTE_APPROVED_ACTION         └────────────────┘
    ┌──────────┐ ──────────────────────────> ┌──────────────────┐
    │ approved │                             │    executed      │
    └──────────┘                             │   (terminal)     │
                                             └──────────────────┘
```

No reverse transitions. No skip transitions. Each recommendation can
have at most one approval decision and at most one executed action.

## Security Model

### Roles

| Role | Purpose | Governance Access |
|------|---------|-------------------|
| OPSMIND_GOVERNANCE_EXECUTOR | Least-privilege procedure owner | SELECT+INSERT on governance tables, SELECT+UPDATE on RECOMMENDATIONS. No DELETE, TRUNCATE, or CORE access. |
| OPSMIND_OPERATOR | Human approval/execution | USAGE on procedures only. Direct INSERT/UPDATE revoked. SELECT on governance tables. |
| OPSMIND_ANALYST / Agent | Investigation | No GOVERNANCE access. No procedure USAGE. No RECOMMENDATIONS access. |
| OPSMIND_ADMIN | Deployment | Full read/write on all schemas. No procedure USAGE (deployment role, not operational). |

### Agent Self-Approval Prevention

**Primary enforcement:** RBAC boundary. The Agent operates through Cortex
Analyst which uses the semantic view, running under ANALYST-level access.
ANALYST has no USAGE on GOVERNANCE schema and no USAGE on the governance
procedures.

**Defense-in-depth:** Procedures check `CURRENT_USER()` against a denied-actor
pattern. This is a secondary control; it is not relied upon as the primary
enforcement mechanism.

### Procedure Ownership

Procedures are owned by `OPSMIND_GOVERNANCE_EXECUTOR` and use `EXECUTE AS
OWNER`. When OPSMIND_OPERATOR calls a procedure, it executes with
GOVERNANCE_EXECUTOR's privileges (SELECT+INSERT on governance, SELECT+UPDATE
on recommendations). `CURRENT_USER()` still returns the calling user's
identity, not the owner.

## Idempotency

| Invariant | Enforcement |
|-----------|-------------|
| One approval per recommendation | Procedure pre-condition check (authoritative). UNIQUE constraint on RECOMMENDATION_ID is metadata only — Snowflake does not enforce UNIQUE on standard tables. |
| One execution per approval | Procedure pre-condition check (authoritative). UNIQUE constraint on APPROVAL_ID is metadata only. |
| Valid status values | CHECK constraint on RECOMMENDATIONS.STATUS (enforced by Snowflake). |
| Valid decision values | CHECK constraint on APPROVAL_DECISIONS.DECISION (enforced by Snowflake). |
| No execution of rejected recommendations | Procedure checks DECISION = 'approved'. |
| No execution of pending recommendations | Procedure checks RECOMMENDATIONS.STATUS = 'approved' (belt-and-suspenders). |

## Atomicity and Concurrency

Each procedure uses explicit transaction management with a concurrency-safe
write pattern:

1. **Fast-fail validation:** Pre-condition checks run before the transaction.
   If any check fails, the procedure returns an error string with no state
   change. These are **not** the concurrency-safety mechanism.
2. **Conditional UPDATE as first DML:** Inside the transaction, a conditional
   `UPDATE ... WHERE STATUS = 'pending'` (or `'approved'` for execution) is
   the first write operation. Snowflake serializes concurrent UPDATEs to the
   same row: the second caller waits for the first to commit, then finds the
   status already changed, matches 0 rows, and bails out. This closes the
   TOCTOU window between the pre-check SELECT and the write.
3. **Post-UPDATE verification:** After the UPDATE, the procedure verifies that
   the target row now has the expected status. If not (0 rows matched), it
   rolls back and returns a concurrency-detection error.
4. **Remaining writes:** APPROVAL_DECISIONS/EXECUTED_ACTIONS INSERT and audit
   entries follow the UPDATE guard. They only execute if the UPDATE succeeded.
5. **Exception handler:** `EXCEPTION WHEN OTHER THEN ROLLBACK; RAISE;` ensures
   that unexpected errors roll back all changes. No partial state can remain.

### Concurrency Limitation

True concurrent testing cannot be performed from a single Snowflake session.
The concurrency model relies on Snowflake's documented DML serialization
behavior for concurrent UPDATEs to the same row. This provides high confidence
but is not formally proven by integration tests. In production environments
with multiple concurrent operators, the conditional-UPDATE guard provides
the safety mechanism; the pre-checks provide fast-fail efficiency.

## Sequence ID Generation

Snowflake sequences (`APPROVAL_SEQ`, `ACTION_SEQ`, `AUDIT_SEQ`) provide
unique, monotonically increasing values for ID generation. Sequences are
**not gap-free** — values may be skipped under concurrency or restart.
Sequences start at 100 to avoid collision with seed data IDs.

## Phase 4A Security Boundaries (Preserved)

- ANALYST cannot read `AI.IMPACT_ASSUMPTIONS` (governed configuration).
- ANALYST cannot read `AI.RECOMMENDATIONS` (operator-only).
- ANALYST has no GOVERNANCE schema access.
- OPERATOR cannot read `AI.IMPACT_ASSUMPTIONS`.
- Agent cannot approve or execute actions (no procedure USAGE, no
  GOVERNANCE schema access).

## Files

| File | Purpose |
|------|---------|
| `setup/sql/11_governance_enforcement.sql` | CHECK constraints, UNIQUE constraints, GOVERNANCE_EXECUTOR role, sequences, procedures, RBAC tightening |
| `tests/sql/test_governance_enforcement.sql` | Comprehensive test suite: positive, negative, RBAC, idempotency, rollback, regression |
| `architecture/GOVERNANCE_ENGINE.md` | This document |

## Deployment

Run `setup/sql/11_governance_enforcement.sql` after all scripts 00–10.
The script:

1. Adds CHECK and UNIQUE constraints to existing tables.
2. Creates the OPSMIND_GOVERNANCE_EXECUTOR role with minimum privileges.
3. Switches to GOVERNANCE_EXECUTOR to create sequences and procedures
   (ensuring correct ownership).
4. Switches back to ACCOUNTADMIN to revoke direct DML from OPERATOR
   and grant procedure USAGE.
