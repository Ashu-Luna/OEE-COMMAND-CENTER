# Architecture

## Data Flow

```
                           Snowflake (OEE_CC)
  +-----------+  +-----------+  +---------------+
  |  OT/IoT   |  |  IT/ERP   |  |  HR / Roster  |
  |  Sensors   |  |  Systems  |  |  (Technicians)|
  +-----+-----+  +-----+-----+  +-------+-------+
        |               |                |
        v               v                v
  +-----------+   +-----------+   +-----------+   +-----------+
  | OT_SENSOR |   | IT_PROD   |   | IT_MAINT  |   | DIM_      |   RAW Schema
  | _READING  |   | _RUN      |   | _RECORD   |   | TECHNICIAN|   (source tables)
  +-----------+   +-----------+   +-----------+   +-----------+
        |               |               |                |
        +-------+-------+               |                |
                |                        |                |
                v                        |                |
  +-------------------------+            |                |
  |   DYNAMIC TABLES        |            |                |
  |   (1-5 min lag)         |            |                |
  |                         |            |                |
  |  DT_SENSOR_MINUTE       |            |                |
  |       |                 |            |                |
  |  DT_MACHINE_HEALTH      |            |                |
  |       |                 |            |                |
  |  DT_OEE_DAILY           |            |                |
  |  (OEE + $COST)          |            |                |
  +------------+------------+            |                |
               |                         |                |
       +-------+--------+               |                |
       |                 |               |                |
       v                 v               v                |
  +---------+     +------------+   +----------+           |
  | CORTEX  |     | CORTEX ML  |   | CORTEX   |    ML Schema
  | ML      |     | FORECAST   |   | COMPLETE |
  | ANOMALY |     | (temp 60m) |   | (LLM)    |
  +---------+     +------------+   +----------+
       |                |               |
       v                v               v
  V_ACTIVE       V_TEMP_RISK     ROOT_CAUSE
  _ANOMALIES                     _REPORTS
       |                               |
       +---------------+---------------+
                       |                |
                       v                v
              +----------------+  +----------------+
              | DRAFT_WORK     |  | DIM_TECHNICIAN |  OPS Schema
              | _ORDERS()      |<-| (specialization|
              | + technician   |  |  skill, shift,  |
              |   dispatch     |  |  jira_email)    |
              +-------+--------+  +----------------+
                      |
            +---------+---------+
            |                   |
            v                   v
      +----------+       +-----------+
      | WORK     |       | Atlassian |    External
      | _ORDER   | ----> | MCP       | -> Jira (MFG-xx)
      | (with    |       | + lookup  |    with REAL assignees
      |  tech_id |       |   accountId|   from jira_email
      |  tech_   |       +-----------+
      |  name)   |
      +----+-----+
           |
           v
  +-------------------+
  | STREAMLIT APP     |              APP Schema
  | OEE_COMMAND       |
  | _CENTER           |
  |                   |
  |  + OEE KPIs       |
  |  + Cost Ledger    |
  |  + Root-Cause     |
  |  + Self-Healing   |
  |  + Tech Workload  |----> DIM_TECHNICIAN (workload query)
  |  + Ask the Factory|----> CORTEX ANALYST
  +-------------------+      + OEE_SEMANTIC
                               (4 tables incl. TECHNICIAN)
```

## Snowflake Services Used

| Service | Purpose |
|---------|---------|
| Dynamic Tables | Near-real-time IT/OT convergence (1-5 min lag) |
| Cortex ML Anomaly Detection | Multi-series dual-signal anomaly models (vibration + temperature) |
| Cortex ML Forecasting | 60-minute temperature projection per machine |
| Cortex COMPLETE (llama3.1-70b) | Root-cause narratives from assembled evidence |
| Cortex Analyst + Semantic Views | Natural-language "Ask the Factory" queries |
| Streamlit in Snowflake | OEE Command Center dashboard |
| Atlassian MCP (via CoCo) | Real Jira ticket creation with assignee dispatch |
| CoCo Automation | Scheduled alert triage loop |

## Schemas

| Schema | Purpose |
|--------|---------|
| OEE_CC.RAW | Source tables: DIM_MACHINE, OT_SENSOR_READING, IT_PRODUCTION_RUN, IT_MAINTENANCE_RECORD, IT_PARTS_INVENTORY, DIM_TECHNICIAN |
| OEE_CC.CONVERGED | Dynamic tables: DT_SENSOR_MINUTE, DT_MACHINE_HEALTH, DT_OEE_DAILY |
| OEE_CC.ML | Anomaly models, forecast, V_ACTIVE_ANOMALIES, V_TEMP_RISK, ROOT_CAUSE_REPORTS |
| OEE_CC.OPS | WORK_ORDER table, DRAFT_WORK_ORDERS() procedure |
| OEE_CC.APP | OEE_COMMAND_CENTER Streamlit app, OEE_SEMANTIC semantic view |
