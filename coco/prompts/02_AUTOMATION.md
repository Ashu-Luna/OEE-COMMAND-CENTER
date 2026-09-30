# CoCo Automation — Scheduled Alert Triage (Feature 4)

CoCo can schedule repeating tasks with **`cortex automation`** (or the **Automations** panel
in the desktop app, top-left sidebar). We use it to run the anomaly-triage loop on a schedule
so the Command Center stays fresh without you re-prompting.

## Option A — Desktop app (Automations panel)

1. Click **Automations** in the left sidebar.
2. Create a new automation with this prompt as the task:

```
Every 15 minutes: re-run anomaly detection on the last 2 days of DT_SENSOR_MINUTE,
refresh OEE_CC.ML.V_ACTIVE_ANOMALIES, then call the DRAFT_WORK_ORDERS procedure so new
anomalies become work orders. Report how many new work orders were created.
```

3. Set the schedule to every 15 minutes. Save.

## Option B — Terminal

```
cortex automation create --schedule "every 15 minutes" --prompt "Re-run anomaly detection on the last 2 days of DT_SENSOR_MINUTE, refresh V_ACTIVE_ANOMALIES, then CALL OEE_CC.OPS.DRAFT_WORK_ORDERS(); report new work order count."
```

## Cost note

Every run wakes OEE_WH. For the demo, enable the automation shortly before presenting and
disable it afterwards, or widen the interval to save trial credits.

## Native alternative

If you prefer a pure-Snowflake schedule (no CoCo running), ask CoCo:

```
Create a Snowflake Task TRIAGE_TASK on OEE_WH that runs every 5 minutes and calls
OEE_CC.OPS.DRAFT_WORK_ORDERS(). Create it suspended and show me how to resume it.
```

Both approaches satisfy Feature 4. The CoCo automation is the more "CoCo-native" story for judges.
