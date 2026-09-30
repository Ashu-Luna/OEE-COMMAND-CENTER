---
name: root-cause-timemachine
description: How to generate the Root-Cause Time Machine narrative for a predicted machine failure using Cortex COMPLETE. Use when building or explaining anomaly root-cause analysis.
---

# Root-Cause Time Machine

Turn a detected anomaly into an evidence-backed, plain-English root-cause story. This is the
demo's wow moment — it must be specific and confident, not generic.

## Evidence to assemble per anomaly

1. **Sensor lead-up**: the last 50 minutes of per-minute vibration and temperature before the
   anomaly timestamp, ordered in time, from CONVERGED.DT_SENSOR_MINUTE.
2. **Machine history**: past FAILURE rows for this machine from RAW.IT_MAINTENANCE_RECORD
   (when, failure_mode, part_used, downtime_min).
3. **Parts stock**: matching part from RAW.IT_PARTS_INVENTORY (name, warehouse_loc, qty_on_hand).

## Prompt pattern for SNOWFLAKE.CORTEX.COMPLETE

Role: "You are a manufacturing reliability engineer."
Ask for **max 4 sentences** covering, in order:
1. The likely **failure mode**.
2. The **sensor pattern** that supports it (cite the vibration/temperature trend).
3. An **estimated time-to-failure**.
4. The **recommended part** and its **stock location**.

Instruct the model to be specific and confident. Feed the assembled evidence as JSON/text.

## Output

Save to OEE_CC.ML.ROOT_CAUSE_REPORTS (machine_id, anomaly_ts, deviation, root_cause_narrative).

## Good example narrative

"CNC-01 is showing early-stage spindle bearing degradation. Vibration climbed from 1.8 to
4.9 mm/s over 45 minutes while bearing temperature rose in lockstep — the same signature that
preceded the BEARING failure on 2026-09-18. Estimated time-to-failure is 4–6 hours at the
current trend. Replace with part BRG-204 (Spindle Bearing), 12 in stock at Warehouse B."
