# OpsMind AI — Knowledge Retrieval Layer

## Architecture

Cortex Search service `OPSMIND.APP.OPS_KNOWLEDGE_SEARCH` provides semantic retrieval over the operational document corpus. The future Cortex Agent combines structured evidence from Cortex Analyst (Phase 3A) with operational knowledge from this retrieval layer.

```
Agent Question (e.g., "What vibration threshold applies?")
        |
        v
  Cortex Search: OPSMIND.APP.OPS_KNOWLEDGE_SEARCH
        |
        v
  Source: OPSMIND.KNOWLEDGE.OPERATIONAL_DOCUMENTS (4 documents)
```

## Indexed Corpus

| DOC_ID | Type | Title | Content (chars) |
|--------|------|-------|----------------|
| DOC-001 | SOP | Bearing Inspection Standard Operating Procedure | 3,711 |
| DOC-002 | Manual | Vibration Analysis and Threshold Guidelines | 3,348 |
| DOC-003 | SOP | Preventive Maintenance Schedule and Procedures | 2,451 |
| DOC-004 | Troubleshooting | CNC Milling Center Troubleshooting Guide | 4,072 |

All documents contain generic manufacturing operational knowledge. No machine-specific diagnoses or expected answers are included.

## Cortex Search Configuration

| Property | Value |
|----------|-------|
| Service | `OPSMIND.APP.OPS_KNOWLEDGE_SEARCH` |
| Search column | `CONTENT` |
| Primary key | `DOC_ID` |
| Attributes (filterable) | `DOC_TYPE`, `TITLE`, `APPLICABLE_MACHINE_TYPES`, `APPLICABLE_COMPONENTS` |
| Embedding model | `snowflake-arctic-embed-m-v1.5` (default) |
| Warehouse | `OPSMIND_WH` |
| Target lag | 1 hour |
| Refresh mode | INCREMENTAL |

## Key Knowledge Available

| Concept | Source Document | Key Content |
|---------|----------------|-------------|
| CNC vibration warning threshold | DOC-002 | 4.5-7.0 mm/s (Zone C) |
| CNC vibration critical threshold | DOC-002 | >7.0 mm/s (Zone D) |
| CNC bearing temp warning | DOC-002, DOC-004 | 50-65 C |
| CNC bearing temp critical | DOC-002, DOC-004 | 65-80 C |
| Bearing temp shutdown | DOC-002, DOC-004 | >80 C |
| Bearing inspection interval | DOC-001, DOC-003 | Every 6 months (spindle) |
| Bearing replacement interval | DOC-001, DOC-003 | 12-18 months |
| Vibration+temperature correlation | DOC-002, DOC-004 | Strong indicator of bearing degradation |
| Overdue maintenance policy | DOC-003 | Escalation at 1, 8, 15, 30 days |
| Troubleshooting decision tree | DOC-004 | Vibration/temp diagnostic flow |

## Retrieval Validation

### Investigation Queries (7/7 correct top result)

| # | Query | Top Result | Relevant |
|---|-------|-----------|----------|
| Q1 | Vibration warning for CNC milling | DOC-002 (Threshold Guidelines) | Yes |
| Q2 | Critical bearing temperature | DOC-001 (Bearing Inspection SOP) | Yes |
| Q3 | Spindle bearing inspection frequency | DOC-001 (Bearing Inspection SOP) | Yes |
| Q4 | Action when vibration exceeds baseline | DOC-004 (Troubleshooting Guide) | Yes |
| Q5 | Vibration + temperature correlation | DOC-004 (Troubleshooting Guide) | Yes |
| Q6 | Overdue bearing maintenance procedure | DOC-003 (PM Schedule) | Yes |
| Q7 | Bearing degradation troubleshooting | DOC-004 (Troubleshooting Guide) | Yes |

### Generalization Queries (3/3 correct top result)

| # | Query | Top Result | Relevant |
|---|-------|-----------|----------|
| G1 | Coolant system maintenance | DOC-003 (PM Schedule) | Yes |
| G2 | Hydraulic press vibration thresholds | DOC-002 (Threshold Guidelines) | Yes |
| G3 | Spare parts policy for CNC bearings | DOC-003 (PM Schedule) | Yes |

## Limitations

1. **Small corpus** (4 documents) — retrieval quality is high because semantic overlap is low. A production corpus with hundreds of documents would require chunking and more targeted attribute filtering.
2. **No chunking** — documents are indexed whole. Cortex Search handles this well for documents under 5KB, but larger documents would benefit from chunking.
3. **No Cortex Search integration with semantic view yet** — the future agent will bridge both retrieval layers.

## Deployment

```sql
-- Step 1: Load document content (after seed data)
-- setup/sql/05b_load_document_content.sql

-- Step 2: Create Cortex Search service
-- setup/sql/08_cortex_search.sql
```
