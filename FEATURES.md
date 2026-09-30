# Features

## Required Challenge Features

### Feature 1: IT/OT Data Convergence (Dynamic Tables)

**What:** Near-real-time join of OT sensor streams (vibration, temperature, RPM, load) with IT/ERP data (production runs, downtime, units, margin) using Snowflake Dynamic Tables with 1-5 minute target lag.

**Snowflake Objects:**
- `OEE_CC.CONVERGED.DT_SENSOR_MINUTE` (1-min lag, per-minute sensor rollup)
- `OEE_CC.CONVERGED.DT_MACHINE_HEALTH` (1-min lag, IT/OT joined view)
- `OEE_CC.CONVERGED.DT_OEE_DAILY` (5-min lag, OEE + downtime cost in dollars)

**Results:** 4 machines, 14 days of data, ~80K sensor readings converged with production runs. OEE and DOWNTIME_COST_USD auto-refresh as new sensor data arrives.

### Feature 2: OEE Calculation with Downtime Cost in Dollars

**What:** OEE = Availability x Performance x Quality, plus DOWNTIME_COST_USD = downtime_min x throughput x unit_margin. Speaks in dollars, not just percentages.

**Snowflake Objects:** `DT_OEE_DAILY` computes all metrics. Streamlit app shows KPI tiles per machine.

**Results:** ~$40K total downtime cost tracked over 14 days across 4 machines.

### Feature 3: Cortex ML Anomaly Detection + Forecasting + Root-Cause Analysis

**3a. Dual-Signal Anomaly Detection:**
- Two Cortex ML anomaly models (vibration + temperature) at 0.995 prediction interval
- Only flag when BOTH signals are anomalous in the same minute (dual-signal intersection)
- 3-consecutive-minute gap-and-island filter to eliminate noise

**Snowflake Objects:** `VIBRATION_ANOMALY_MODEL`, `TEMPERATURE_ANOMALY_MODEL`, `ML.ANOMALY_RESULTS`, `ML.V_ACTIVE_ANOMALIES`

**Results:** 100% failure recall (4/4 failures caught), ~35-40 minute advance warning, 28.7% false positive reduction (675 -> 516 anomalies).

**3b. Temperature Forecasting:**
- Cortex ML multi-series forecast, 60-minute projection per machine
- V_TEMP_RISK view with per-machine relative threshold (baseline + 8C)
- CRITICAL/WARNING/WATCH severity levels

**Snowflake Objects:** `TEMP_FORECAST_MODEL`, `TEMP_FORECAST_60`, `ML.V_TEMP_RISK`

**3c. Root-Cause Time Machine (AI Narratives):**
- For each active anomaly, assembles evidence: 50-minute sensor lead-up, past failures from IT_MAINTENANCE_RECORD, parts stock from IT_PARTS_INVENTORY
- Calls `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` with a reliability-engineer prompt
- Produces 4-sentence analysis: failure mode, sensor pattern, time-to-failure, recommended part

**Snowflake Objects:** `ML.ROOT_CAUSE_REPORTS`

**Results:** Narratives cite specific vibration/temperature trends, name exact parts (BRG-204, COOL-PLG, BRG-308) with stock location (WH-EAST), and estimate time-to-failure.

### Feature 4: Self-Healing Automation Loop

**What:** Anomaly -> Work Order -> Jira Ticket -> Technician Assignment. Fully automated pipeline with idempotent MERGE-based DRAFT_WORK_ORDERS procedure and loop status lifecycle (DRAFTED -> TICKETED -> ACKNOWLEDGED -> CLOSED).

**Snowflake Objects:** `OPS.WORK_ORDER`, `OPS.DRAFT_WORK_ORDERS()` procedure

**Results:** 3 work orders auto-drafted with severity, recommended part, cost estimate, root cause, and assigned technician. Can be scheduled via CoCo automation or Snowflake Task.

### Feature 5: Streamlit in Snowflake Dashboard

**What:** OEE Command Center with 5 sections: OEE KPI tiles + trend chart, Downtime Cost Ledger, Root-Cause + Self-Healing Loop with technician dispatch, Technician Workload panel, Ask the Factory (Cortex Analyst chat).

**Snowflake Objects:** `OEE_CC.APP.OEE_COMMAND_CENTER` (deployed to warehouse runtime)

### Feature 6: Real Jira Ticketing (Atlassian MCP)

**What:** CoCo connects to the official Atlassian MCP server via OAuth. For each DRAFTED work order, creates a real Jira issue in project MFG with root cause, recommended part, cost, and assigned technician in the description. Sets the real Jira assignee using the technician's jira_email.

**Tools Used:** `createJiraIssue`, `transitionJiraIssue`, `editJiraIssue`, `lookupJiraAccountId`

**Results:** MFG-17 (CNC-01, assigned to Naveen Bharathi), MFG-18 (PRS-01, assigned to Bhavna), MFG-19 (CNC-02, assigned to Naveen Bharathi). All in "To Do" status.

---

## Bonus Features

### Bonus: Semantic View + Cortex Analyst ("Ask the Factory")

**What:** Semantic view over 4 tables (DT_OEE_DAILY, DT_MACHINE_HEALTH, WORK_ORDER, DIM_TECHNICIAN) with 17 dimensions, 8 metrics, 5 verified queries. Users ask plain-English questions and get SQL + results. Includes technician workload queries.

**Snowflake Objects:** `OEE_CC.APP.OEE_SEMANTIC`

**Verified Queries:**
- "Which machine had the highest downtime cost in the last 7 days?"
- "How many open work orders does each technician have?"
- "Which specialization has the most work orders?"
- "Show me OEE breakdown by machine and day"
- "What is the total downtime cost per machine?"

### Bonus: Smart Technician Dispatch with Real Jira Assignees

**What:** DRAFT_WORK_ORDERS automatically assigns the best available technician based on:
1. **Specialization match** — CNC_LATHE/CNC_MILL -> CNC Machining, HYDRAULIC_PRESS -> Hydraulic Press, ROBOTIC_WELDER -> Robotics
2. **Severity-based skill preference** — HIGH severity prefers Senior technicians
3. **Availability filter** — only IS_AVAILABLE = TRUE
4. **Load balancing** — fewest open work orders (DRAFTED/TICKETED/ACKNOWLEDGED)
5. **Tie-breaker** — earliest hire date (most experienced)

The technician's `jira_email` is used to look up their Jira accountId via `lookupJiraAccountId` and set them as the **real Jira issue assignee** (not just mentioned in the description).

**Snowflake Objects:** `RAW.DIM_TECHNICIAN` (12 technicians, 4 real Jira users), dispatch logic embedded in `DRAFT_WORK_ORDERS()`

**Real Jira Users:**

| Technician | Jira Email | Specializations |
|-----------|-----------|----------------|
| Naveen Bharathi | knskings05@gmail.com | CNC Machining, Thermal Systems |
| Bhavna | bhavna.vinodh-pillai@rntbci-nissan.com | Hydraulic Press, Bearing & Spindle |
| Nelakurthi Meghana | nelakurthi.meghana@rntbci-nissan.com | Robotics, Bearing & Spindle, CNC Machining |
| Asha Jyothi | ashajyothiakula81@gmail.com | Electrical Systems, Robotics |

**CoCo Prompts:** See `coco/prompts/00_PLAYBOOK.md` Prompt 10 (10a-10d) for the full build sequence.

### Bonus: CoCo Skills (Domain Knowledge)

Four custom CoCo skills encode manufacturing domain knowledge so CoCo can build the entire system from natural-language prompts:
- **oee-domain** — OEE formulas, downtime cost, severity rules
- **root-cause-timemachine** — Evidence assembly, LLM prompt pattern
- **work-order-triage** — Severity thresholds, part mapping, Jira format
- **technician-dispatch** — Specialization matching, skill preference, load balancing, Jira assignee rules
