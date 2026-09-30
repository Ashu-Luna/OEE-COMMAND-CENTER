# Predictive Maintenance OEE Command Center

An end-to-end predictive maintenance solution built entirely on Snowflake using CoCo (Cortex Code), demonstrating IT/OT data convergence, ML-powered anomaly detection, AI root-cause analysis, smart technician dispatch, and a self-healing operational loop with real Jira integration.

**Built with:** Snowflake Dynamic Tables, Cortex ML, Cortex COMPLETE (LLM), Cortex Analyst, Streamlit in Snowflake, Atlassian MCP, and 4 custom CoCo skills.

## Quick Start

1. Run the SQL scripts in order: `sql/01_setup.sql` through `sql/09_semantic_view.sql`
2. The Streamlit app is deployed as `OEE_CC.APP.OEE_COMMAND_CENTER` in Snowsight
3. Connect the Atlassian MCP server in CoCo for Jira integration (see `mcp/README.md`)

## Project Structure

```
Predictive_Maintanence_OEE/
|-- README.md                        <- You are here
|-- FEATURES.md                      <- All 6 features + bonuses with validated results
|-- ARCHITECTURE.md                  <- Data flow diagram + Snowflake services used
|
|-- sql/                             <- DDL for every Snowflake object (run in order)
|   |-- 01_setup.sql                 <- Warehouse OEE_WH, database OEE_CC, schemas
|   |-- 02_data_generation.sql       <- RAW tables (DIM_MACHINE, sensors, production, maintenance, parts)
|   |-- 03_dynamic_tables.sql        <- DT_SENSOR_MINUTE, DT_MACHINE_HEALTH, DT_OEE_DAILY
|   |-- 04_anomaly_detection.sql     <- Dual-signal anomaly models + V_ACTIVE_ANOMALIES
|   |-- 05_forecast.sql              <- Temperature forecast + V_TEMP_RISK
|   |-- 06_root_cause.sql            <- ROOT_CAUSE_REPORTS via Cortex COMPLETE
|   |-- 07_work_orders.sql           <- WORK_ORDER + DRAFT_WORK_ORDERS (with technician dispatch)
|   |-- 08_technician_dispatch.sql   <- DIM_TECHNICIAN + dispatch rules
|   |-- 09_semantic_view.sql         <- OEE_SEMANTIC semantic view (4 tables, 17 dims, 8 metrics)
|
|-- streamlit/                       <- Streamlit in Snowflake app
|   |-- streamlit_app.py             <- Full OEE Command Center (6 tabs + Cortex Analyst chat)
|   +-- environment.yml              <- Conda dependencies for SiS
|
|-- data_sources/                    <- Exported data (CSV snapshots)
|   |-- README.md                    <- Column descriptions and row counts
|   |-- DIM_MACHINE.csv              <- 4 machines
|   |-- IT_PARTS_INVENTORY.csv       <- 8 spare parts
|   |-- IT_MAINTENANCE_RECORD.csv    <- 7 maintenance events
|   |-- DIM_TECHNICIAN.csv           <- 12 technicians (4 real Jira users)
|   +-- (sensor + production data regenerated via sql/02)
|
|-- coco/                            <- CoCo skills + prompts (the AI build process)
|   |-- skills/                      <- 4 custom domain skills loaded into CoCo
|   |   |-- oee-domain/SKILL.md      <- OEE formulas, downtime cost, severity rules
|   |   |-- root-cause-timemachine/SKILL.md  <- Evidence assembly + LLM prompt pattern
|   |   |-- work-order-triage/SKILL.md       <- Severity, part mapping, Jira format
|   |   +-- technician-dispatch/SKILL.md     <- Specialization match, skill pref, load balance
|   |-- 00_PLAYBOOK.md               <- Full 9-prompt demo playbook (paste into CoCo)
|   |-- 02_AUTOMATION.md             <- Scheduled alert triage via CoCo automation
|   +-- 03_MCP_TICKETING.md          <- Atlassian MCP setup instructions
|
+-- mcp/                             <- MCP integration docs
    +-- README.md                    <- Atlassian MCP setup + Jira project details
```

## What CoCo Built vs. What's in the Repo

| Layer | Built by CoCo (in Snowflake) | In this repo (source files) |
|-------|-----------------------------|-----------------------------|
| Infrastructure | Warehouse, database, schemas | `sql/01_setup.sql` |
| Data | 80K sensor readings, production runs | `sql/02_data_generation.sql`, `data_sources/` |
| Convergence | 3 dynamic tables (auto-refresh) | `sql/03_dynamic_tables.sql` |
| ML | Anomaly + forecast models | `sql/04_anomaly_detection.sql`, `sql/05_forecast.sql` |
| AI | Root-cause narratives (LLM) | `sql/06_root_cause.sql` |
| Ops | Work orders + technician dispatch | `sql/07_work_orders.sql`, `sql/08_technician_dispatch.sql` |
| Analytics | Semantic view (Cortex Analyst) | `sql/09_semantic_view.sql` |
| Dashboard | Streamlit app (deployed) | `streamlit/streamlit_app.py` |
| Ticketing | Real Jira tickets via MCP | `mcp/README.md` |
| Knowledge | 4 CoCo skills | `coco/skills/` |

## Key Results

| Metric | Value |
|--------|-------|
| Failure Recall | 100% (4/4 failures caught) |
| Advance Warning | 35-40 minutes before failure |
| False Positive Reduction | 28.7% (675 -> 516 anomalies) |
| Downtime Cost Tracked | ~$40K over 14 days |
| Jira Tickets Created | MFG-17, MFG-18, MFG-19 (with real assignees) |
| Semantic View | 4 tables, 17 dimensions, 8 metrics, 5 verified queries |
| Technicians | 12 staff, 4 real Jira users, smart dispatch |
| Cortex Analyst | Correct SQL for all verified queries |

## Snowflake Features Demonstrated

- Dynamic Tables (near-real-time IT/OT convergence with incremental refresh)
- Cortex ML Anomaly Detection (multi-series, dual-signal, 0.995 prediction interval)
- Cortex ML Forecasting (multi-series temperature projection)
- Cortex COMPLETE / LLM (evidence-backed root-cause narratives)
- Cortex Analyst + Semantic Views (natural-language factory queries)
- Streamlit in Snowflake (command center dashboard with 6 tabs)
- Atlassian MCP (real Jira tickets with assignee dispatch)
- CoCo Skills (domain knowledge for manufacturing)
- CoCo Automation (scheduled alert triage)

## How to Reproduce

1. Follow `coco/00_PLAYBOOK.md` — paste each prompt into CoCo Desktop in order
2. CoCo builds everything: data, dynamic tables, ML models, root-cause reports, work orders
3. Connect Atlassian MCP for Jira integration (see `coco/03_MCP_TICKETING.md`)
4. The Streamlit app deploys automatically as `OEE_CC.APP.OEE_COMMAND_CENTER`

No credentials are stored in this repo. Jira auth is via OAuth through the MCP server.
