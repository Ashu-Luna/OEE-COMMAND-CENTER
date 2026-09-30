-- ============================================================
-- 06_root_cause.sql — Root-Cause Time Machine
-- Uses Cortex COMPLETE (llama3.1-70b) to generate evidence-backed
-- root-cause narratives for each active anomaly.
-- ============================================================

CREATE OR REPLACE TABLE OEE_CC.ML.ROOT_CAUSE_REPORTS (
    MACHINE_ID VARIANT,
    ANOMALY_TS TIMESTAMP_NTZ(9),
    DEVIATION_SCORE FLOAT,
    ROOT_CAUSE_NARRATIVE VARCHAR(16777216)
);

-- For each anomaly in V_ACTIVE_ANOMALIES, we assemble evidence:
--   1. Last 50 minutes of sensor data (vibration + temperature trend)
--   2. Past failure records for this machine from IT_MAINTENANCE_RECORD
--   3. Current parts stock from IT_PARTS_INVENTORY
--
-- Then call SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b', prompt) asking for
-- a 4-sentence reliability-engineer analysis:
--   1. Likely failure mode
--   2. Supporting sensor pattern (cite vibration/temperature trends)
--   3. Estimated time-to-failure
--   4. Recommended part + stock location
--
-- The INSERT statement uses a CTE to build the evidence JSON and prompt,
-- then passes it to CORTEX.COMPLETE. Results are cleaned with REGEXP_REPLACE
-- to strip any preamble like "Here are the 4 sentences:".
--
-- See coco/skills/root-cause-timemachine/SKILL.md for the full prompt pattern.
