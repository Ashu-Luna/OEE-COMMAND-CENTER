# CoCo CLI Playbook — OEE Command Center

**How to use this file:** Each numbered block below is a prompt you paste into the CoCo
"Describe a task" box (desktop app) or type in the `cortex` terminal. Run them in order.
CoCo will show a plan and ask for approval before it changes anything — review, then approve.

> Keep **Default Approvals** on so you (and the judges) see CoCo's plan for each step.
> This playbook IS the demo script. Build it live and narrate what CoCo does.

Connection: confirm with `/status` before starting (use your CoCo-enabled account).

---

## Prompt 0 — Set the stage (bootstrap)

```
Create a warehouse called OEE_WH (XSMALL, auto-suspend 60s, auto-resume).
Create a database OEE_CC with schemas RAW, CONVERGED, ML, OPS, and APP.
Use OEE_WH and OEE_CC.RAW as my current context.
Confirm what you created.
```

Why: gives CoCo a sandboxed, credit-safe place to work. XSMALL + auto-suspend protects the trial credits.

---

## Prompt 1 — FEATURE 1: synthetic IoT + ERP data

```
I'm building a predictive-maintenance demo for manufacturing. In OEE_CC.RAW create
and populate these tables with realistic synthetic data for 4 machines
(CNC-01, CNC-02, PRS-01, RBT-01) over the last 14 days:

1. DIM_MACHINE: machine_id, machine_name, line_id, machine_type, ideal_cycle_sec, warehouse_loc
2. OT_SENSOR_READING: one reading per minute per machine with ts, vibration_mm_s,
   temperature_c, rpm, load_pct. IMPORTANT: for 3-4 randomly chosen failure events,
   make vibration and temperature drift upward together over the ~50 minutes BEFORE
   the failure timestamp (a correlated failure signature).
3. IT_PRODUCTION_RUN: per day per shift (DAY/NIGHT): planned_time_min, downtime_min,
   units_produced, units_good, unit_margin_usd. Give days with a failure much higher downtime.
4. IT_MAINTENANCE_RECORD: the labeled failures with event_ts, event_type, failure_mode
   (BEARING/OVERHEAT/SPINDLE), part_used, downtime_min, notes.
5. IT_PARTS_INVENTORY: parts like BRG-204 spindle bearing with warehouse_loc, qty_on_hand.

Use Snowflake generator functions where possible. Show me row counts when done.
```

Why: this is the "generate synthetic IoT streams correlated with ERP" requirement. The
correlated lead-up is what makes anomaly detection and the Root-Cause Time Machine work.
(Reference implementation lives in ../reference/ if CoCo needs a template — you can also
attach it with @ in CoCo.)

---

## Prompt 2 — FEATURE 2: IT/OT convergence with dynamic tables

```
In OEE_CC.CONVERGED build dynamic tables for near-real-time IT/OT convergence:

1. DT_SENSOR_MINUTE: per-minute rollup of OT_SENSOR_READING (avg/max vibration, avg/max
   temperature, avg rpm, avg load), TARGET_LAG 1 minute, on OEE_WH.
2. DT_MACHINE_HEALTH: join DT_SENSOR_MINUTE to DIM_MACHINE and same-day IT_PRODUCTION_RUN
   so each sensor minute carries its IT/ERP context (margin, downtime, units). This is the
   unified IT/OT view. TARGET_LAG 1 minute.
3. DT_OEE_DAILY: per machine per day compute Availability = (planned-downtime)/planned,
   Performance = (ideal_cycle_sec * units_produced / 60) / runtime, Quality = good/produced,
   OEE = A*P*Q. ALSO compute DOWNTIME_COST_USD = downtime_min * (units per runtime minute) *
   unit_margin_usd. TARGET_LAG 5 minutes.

Explain how dynamic tables keep these fresh incrementally, then show me sample rows.
```

Why: dynamic tables = the "incremental and streaming convergence" requirement. The
DOWNTIME_COST_USD column is our unique angle (dollars, not just percentages).

---

## Prompt 3 — FEATURE 3a: Cortex ML anomaly detection

> IMPORTANT: train on data OLDER than the last **3 days**, detect on the last **3 days**.
> The failures are placed inside that 3-day detection window (see generate_data.py
> DETECT_WINDOW_DAYS), so the model has real pre-failure ramps to catch. Using "last 2 days"
> or a random split causes 0 failures to be caught — that was the original bug.

```
Using Snowflake Cortex ML anomaly detection, train a multi-series model on per-minute
average vibration per machine from DT_SENSOR_MINUTE, using all data OLDER than the last 3 days
as training. Then detect anomalies on the last 3 days. Save flagged anomalies to a table
OEE_CC.ML.ANOMALY_RESULTS and create a view V_ACTIVE_ANOMALIES showing machine_id,
anomaly_ts, observed vs expected vibration, and the deviation. How many anomalies were flagged?
```

### Prompt 3b — Validate against ground truth (do this every time)

```
For each flagged anomaly in OEE_CC.ML.V_ACTIVE_ANOMALIES, find the nearest FAILURE record in
OEE_CC.RAW.IT_MAINTENANCE_RECORD for the same machine within 6 hours AFTER the anomaly. Show
machine_id, anomaly_ts, deviation, nearest failure ts, failure_mode, minutes_to_failure. Then
report failure recall (were all failures caught?) and the false-positive rate.
```

Expected good result: ~100% failure recall, anomalies appearing ~40 min before each failure.

### Prompt 3c — (Optional) cut false positives with correlated signals

```
Reduce false positives while keeping 100% recall: tighten the vibration model to
prediction_interval 0.995, train a SECOND anomaly model on temperature, and only flag a
reading when BOTH vibration AND temperature are anomalous in the same minute for the same
machine. Re-run the Prompt 3b validation and compare before vs after.
```

## Prompt 4 — FEATURE 3b: Cortex ML forecast (countdown to failure)

> Use a per-machine RELATIVE threshold (baseline + 8C), not a fixed high number. Normal temps
> differ by machine type (CNC ~55C, PRESS ~48C, ROBOT ~42C), so a fixed threshold can return
> nothing if the data ends in a calm period. If V_TEMP_RISK is empty, lower to baseline + 5C.

```
Using Snowflake Cortex ML forecasting, train a model on per-minute temperature per machine
from DT_SENSOR_MINUTE and forecast the next 60 minutes. For each machine, compute its normal
baseline temperature (median over the training period). Create a view OEE_CC.ML.V_TEMP_RISK
listing any machine whose forecast temperature is predicted to exceed its baseline + 8C, with
minutes_to_breach from now and the peak forecast temperature. This powers a "countdown to
failure" tile. Show me the at-risk machines.
```

Note: forecasting 60 min ahead on data ending in a calm period mostly predicts "stays calm."
This satisfies Feature 3b (forecasting capability); the anomaly model (Prompt 3) is the strong
predictive story.

## Prompt 5 — FEATURE 3c: Root-Cause Time Machine (the wow moment)

```
For each active anomaly, build a root-cause narrative using Snowflake Cortex COMPLETE.
Assemble evidence: the 50-minute sensor lead-up (vibration+temp trend), this machine's past
failures from IT_MAINTENANCE_RECORD, and current parts stock from IT_PARTS_INVENTORY.
Prompt the model as a reliability engineer to give a 4-sentence analysis: likely failure mode,
the supporting sensor pattern, estimated time-to-failure, and the recommended part with its
stock location. Save results to OEE_CC.ML.ROOT_CAUSE_REPORTS. Show me the narratives.
```

Why: turns feature 3's "natural language root cause" into an evidence-backed story.

---

## Prompt 6 — FEATURE 4: alert triage workflow

```
Build an alert-triage workflow in OEE_CC.OPS:
1. A WORK_ORDER table tracking machine_id, anomaly_ts, severity (from deviation), recommended
   part, root_cause, loop_status (DRAFTED->TICKETED->ACKNOWLEDGED->CLOSED), external_ticket,
   est_cost_usd.
2. A stored procedure DRAFT_WORK_ORDERS that MERGEs new anomalies from V_ACTIVE_ANOMALIES into
   WORK_ORDER (idempotent), pulling the root cause and a recommended part, and estimating cost
   from DT_OEE_DAILY downtime cost.
Run it once and show me the drafted work orders.
```

Then schedule it with CoCo automation (see 02_AUTOMATION.md).

---

## Prompt 7 — FEATURE 6: real Jira ticketing via the official Atlassian MCP server

We connect CoCo to the official Atlassian MCP server (OAuth, no tokens in the repo). Three steps:

### 7a. Add the Atlassian MCP connector
CoCo Desktop -> Agent Settings -> MCP -> New:
- Server Name: `Atlassian`
- Server Type: **Remote (HTTP)**
- Server URL: `https://mcp.atlassian.com/v2/mcp`
- Headers / Env Variables: none. Save.

### 7b. Authenticate (browser OAuth) and confirm tools
```
List my Jira projects using the Atlassian tools.
```
A browser opens for Atlassian login; approve it. CoCo then has ~21 Atlassian tools including
`createJiraIssue`. If tools don't become callable, Restart the connector (Agent Settings -> MCP)
and start a New session.

### 7c. Close the loop
```
Using the Atlassian MCP tool createJiraIssue, create one Jira issue per DRAFTED work order in
OEE_CC.OPS.WORK_ORDER, in project MFG, issue type Task. Title each "[<severity>] Predicted
failure on <machine_id>" and put root_cause, recommended_part and est_cost_usd in the
description. Take the returned issue key and update that work order row: set external_ticket =
the key and loop_status = 'TICKETED'. Then show me the work orders with their real Jira keys.
```

Real MFG-x tickets appear on your Jira board, driven by the anomaly data.
Full details in ../mcp/README.md.

---

## Prompt 8 — FEATURE 5: Streamlit OEE Command Center

```
Build a Streamlit in Snowflake app called OEE_COMMAND_CENTER with three sections:
1. OEE KPI tiles per machine (OEE% with A/P/Q breakdown) from DT_OEE_DAILY.
2. A "Downtime Cost Ledger" showing dollars lost over 14 days, biggest bleeder, and a bar
   chart by machine.
3. A "Root-Cause Time Machine" listing anomalies with their Cortex narratives, plus a
   "Self-Healing Loop" table showing each work order's loop_status and external_ticket.
Deploy it and give me the link.
```

---

## Prompt 9 — STRETCH FEATURE: Semantic View + "Ask the Factory" (Cortex Analyst)

> Bonus 7th feature. Requires a supported LLM in your account (claude-4-sonnet, claude-3-7-sonnet,
> mistral-large2, or openai-gpt-4.1). Check first: SHOW MODELS IN SNOWFLAKE.MODELS.

### 9a. Create the semantic view
```
Create a Snowflake semantic view OEE_CC.APP.OEE_SEMANTIC over the converged tables
DT_MACHINE_HEALTH and DT_OEE_DAILY. Define dimensions: machine_id, machine_name, line_id,
machine_type, shift_date. Define metrics with business-friendly synonyms: oee ("overall
equipment effectiveness", "machine efficiency"), availability, performance, quality, and
downtime_cost_usd ("money lost", "downtime cost"). Then verify it with Cortex Analyst by asking:
"Which machine had the highest downtime cost in the last 7 days and what was its OEE?" Show the
generated SQL and the answer.
```

### 9b. Add "Ask the Factory" to the Streamlit app
```
Add a fourth section to the OEE_COMMAND_CENTER Streamlit app called "Ask the Factory". Give it
a text box where the user types a plain-English question. On submit, call the Cortex Analyst
REST endpoint (/api/v2/cortex/analyst/message) with the semantic view OEE_CC.APP.OEE_SEMANTIC,
run the SQL that Analyst returns, and display both the generated SQL and the result table.
Provide 3 example questions as clickable buttons (highest downtime cost, lowest OEE machine,
availability by line). Redeploy the app.
```

---

## Prompt 10 — FEATURE: Smart Technician Dispatch

Auto-assigns the right technician to each work order and Jira ticket.

### 10a. Load the technician dimension (now includes jira_email)
```
Recreate table OEE_CC.RAW.DIM_TECHNICIAN (technician_id, technician_name, specialization,
skill_level, shift_assignment, contact_number, is_available boolean, hire_date date,
jira_email) and load the 12 technicians from data_sources/dim_technician.csv. Show the rows.
```

> Technicians ARE real Jira users (names match exactly, no mismatch):
> - Nelakurthi Meghana (CNC)     nelakurthi.meghana@rntbci-nissan.com  -> CNC-01, CNC-02
> - Bhavna Vinodh Pillai (PRESS) bhavna.vinodh-pillai@rntbci-nissan.com -> PRS-01
> - Naveen Bharathi (ROBOT)      knskings05@gmail.com                   -> RBT-01
> - Asha Jyothi (GENERAL)        ashajyothiakula81@gmail.com            -> fallback
> Every demo work order maps to a real Jira user, assigned by exact name.

### 10b. Add assignment to work orders
```
Use the technician-dispatch skill. Add columns assigned_technician_id and
assigned_technician_name to OEE_CC.OPS.WORK_ORDER. Update DRAFT_WORK_ORDERS so each new work
order is assigned the best available technician: match the machine type to specialization
(CNC->CNC Machining, PRESS->Hydraulic Press, ROBOT->Robotics, else Electrical Systems),
prefer SENIOR for HIGH severity, only IS_AVAILABLE=TRUE, and load-balance by fewest open
work orders. Re-run it and show each work order with its assigned technician.
```

### 10c. REAL Jira assignment + Streamlit
```
Use the technician-dispatch skill. For each work order whose assigned technician has a
JIRA_EMAIL in DIM_TECHNICIAN, look up that user's Jira accountId (Atlassian user search) and
set them as the ACTUAL assignee on the corresponding Jira issue (not just the description).
Also add the technician name + contact to the description. For technicians without a JIRA_EMAIL,
put the name in the description only. Then in the OEE_COMMAND_CENTER Streamlit app, show the
assigned technician in the self-healing-loop table and add a "Technician Workload" panel
(open work orders per technician). Redeploy and confirm which Jira issues now have a real
assignee.
```

### 10d. Add technician to the semantic view
```
Extend the OEE_SEMANTIC semantic view so users can ask about technicians (e.g. "How many open
work orders does each technician have?" and "Which specialization has the most failures?").
```

---

## Progress tracker

- [x] Prompt 0 — setup
- [x] Prompt 1 — data (failures in last 3 days)
- [x] Prompt 2 — convergence
- [x] Prompt 3 — anomaly detection (validated: ~100% failure recall, ~40 min lead time)
- [x] Prompt 4 — forecast
- [x] Prompt 5 — Root-Cause Time Machine
- [x] Prompt 6 — alert triage / work orders
- [x] Prompt 7 — real Jira MCP ticketing
- [x] Automation — scheduled triage (02_AUTOMATION.md)
- [x] Prompt 8 — Streamlit Command Center
- [x] Skills loaded (oee-domain, root-cause-timemachine, work-order-triage, technician-dispatch)
- [x] Prompt 9 — semantic view + "Ask the Factory"
- [x] Prompt 10 — smart technician dispatch + real Jira assignees
- [ ] Push to GitHub

## Demo-day order (what to show judges)

1. `/status` — prove CoCo is driving a real Snowflake account.
2. Prompt 1 live — CoCo generates data. Narrate the correlated failure signature.
3. Prompt 2 — convergence. "OT and IT are now one view."
4. Prompt 3b — validation: "100% of failures caught, ~40 minutes early."
5. Prompt 5 — the Root-Cause Time Machine narrative. This is the wow.
6. Prompt 7 — a REAL Jira ticket appears on the board (show the MFG-x key live).
7. Prompt 10c — show the Jira ticket has a real person assigned (not just in description).
8. Open the Streamlit app — Cost Ledger in dollars + loop status + Technician Workload.
9. "Ask the Factory" — type "How many open work orders does each technician have?"
10. Close: "Every step here was built by talking to CoCo."
```