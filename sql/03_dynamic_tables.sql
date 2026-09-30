-- ============================================================
-- 03_dynamic_tables.sql — IT/OT Convergence via Dynamic Tables
-- Near-real-time join of OT sensor data with IT/ERP context
-- ============================================================

-- Per-minute sensor rollup (1-minute lag)
create or replace dynamic table OEE_CC.CONVERGED.DT_SENSOR_MINUTE(
    MACHINE_ID, MINUTE_TS,
    AVG_VIBRATION_MM_S, MAX_VIBRATION_MM_S,
    AVG_TEMPERATURE_C, MAX_TEMPERATURE_C,
    AVG_RPM, AVG_LOAD_PCT
) target_lag = '1 minute'
  refresh_mode = AUTO initialize = ON_CREATE
  warehouse = OEE_WH
as
    SELECT
        machine_id,
        DATE_TRUNC('minute', ts) AS minute_ts,
        ROUND(AVG(vibration_mm_s), 2)  AS avg_vibration_mm_s,
        ROUND(MAX(vibration_mm_s), 2)  AS max_vibration_mm_s,
        ROUND(AVG(temperature_c), 1)   AS avg_temperature_c,
        ROUND(MAX(temperature_c), 1)   AS max_temperature_c,
        ROUND(AVG(rpm))::INT           AS avg_rpm,
        ROUND(AVG(load_pct), 1)        AS avg_load_pct
    FROM OEE_CC.RAW.OT_SENSOR_READING
    GROUP BY machine_id, DATE_TRUNC('minute', ts);

-- Converged IT/OT view: sensor + machine + production context (1-minute lag)
create or replace dynamic table OEE_CC.CONVERGED.DT_MACHINE_HEALTH(
    MACHINE_ID, MINUTE_TS, MACHINE_NAME, LINE_ID, MACHINE_TYPE, IDEAL_CYCLE_SEC,
    AVG_VIBRATION_MM_S, MAX_VIBRATION_MM_S, AVG_TEMPERATURE_C, MAX_TEMPERATURE_C,
    AVG_RPM, AVG_LOAD_PCT,
    TOTAL_PLANNED_TIME_MIN, TOTAL_DOWNTIME_MIN, TOTAL_UNITS_PRODUCED,
    TOTAL_UNITS_GOOD, UNIT_MARGIN_USD
) target_lag = '1 minute'
  refresh_mode = AUTO initialize = ON_CREATE
  warehouse = OEE_WH
as
    SELECT
        s.machine_id, s.minute_ts,
        m.machine_name, m.line_id, m.machine_type, m.ideal_cycle_sec,
        s.avg_vibration_mm_s, s.max_vibration_mm_s,
        s.avg_temperature_c, s.max_temperature_c,
        s.avg_rpm, s.avg_load_pct,
        p.total_planned_time_min, p.total_downtime_min,
        p.total_units_produced, p.total_units_good, p.unit_margin_usd
    FROM OEE_CC.CONVERGED.DT_SENSOR_MINUTE s
    JOIN OEE_CC.RAW.DIM_MACHINE m ON s.machine_id = m.machine_id
    LEFT JOIN (
        SELECT machine_id, run_date,
               SUM(planned_time_min) AS total_planned_time_min,
               SUM(downtime_min)     AS total_downtime_min,
               SUM(units_produced)   AS total_units_produced,
               SUM(units_good)       AS total_units_good,
               MAX(unit_margin_usd)  AS unit_margin_usd
        FROM OEE_CC.RAW.IT_PRODUCTION_RUN
        GROUP BY machine_id, run_date
    ) p ON s.machine_id = p.machine_id AND s.minute_ts::DATE = p.run_date;

-- Daily OEE with downtime cost in dollars (5-minute lag)
create or replace dynamic table OEE_CC.CONVERGED.DT_OEE_DAILY(
    MACHINE_ID, RUN_DATE, MACHINE_NAME, LINE_ID, IDEAL_CYCLE_SEC,
    PLANNED_TIME_MIN, DOWNTIME_MIN, UNITS_PRODUCED, UNITS_GOOD, UNIT_MARGIN_USD,
    RUNTIME_MIN, AVAILABILITY, PERFORMANCE, QUALITY, OEE, DOWNTIME_COST_USD
) target_lag = '5 minutes'
  refresh_mode = AUTO initialize = ON_CREATE
  warehouse = OEE_WH
as
    SELECT
        pr.machine_id, pr.run_date,
        m.machine_name, m.line_id, m.ideal_cycle_sec,
        SUM(pr.planned_time_min)     AS planned_time_min,
        SUM(pr.downtime_min)         AS downtime_min,
        SUM(pr.units_produced)       AS units_produced,
        SUM(pr.units_good)           AS units_good,
        MAX(pr.unit_margin_usd)      AS unit_margin_usd,
        SUM(pr.planned_time_min) - SUM(pr.downtime_min) AS runtime_min,
        -- Availability
        ROUND((SUM(pr.planned_time_min) - SUM(pr.downtime_min))
              / NULLIF(SUM(pr.planned_time_min), 0), 4) AS availability,
        -- Performance
        ROUND((m.ideal_cycle_sec * SUM(pr.units_produced) / 60.0)
              / NULLIF(SUM(pr.planned_time_min) - SUM(pr.downtime_min), 0), 4) AS performance,
        -- Quality
        ROUND(SUM(pr.units_good)::FLOAT / NULLIF(SUM(pr.units_produced), 0), 4) AS quality,
        -- OEE = A * P * Q
        ROUND(
            ((SUM(pr.planned_time_min) - SUM(pr.downtime_min)) / NULLIF(SUM(pr.planned_time_min), 0))
            * ((m.ideal_cycle_sec * SUM(pr.units_produced) / 60.0) / NULLIF(SUM(pr.planned_time_min) - SUM(pr.downtime_min), 0))
            * (SUM(pr.units_good)::FLOAT / NULLIF(SUM(pr.units_produced), 0))
        , 4) AS oee,
        -- Downtime cost in dollars
        ROUND(
            SUM(pr.downtime_min)
            * (SUM(pr.units_produced)::FLOAT / NULLIF(SUM(pr.planned_time_min) - SUM(pr.downtime_min), 0))
            * MAX(pr.unit_margin_usd)
        , 2) AS downtime_cost_usd
    FROM OEE_CC.RAW.IT_PRODUCTION_RUN pr
    JOIN OEE_CC.RAW.DIM_MACHINE m ON pr.machine_id = m.machine_id
    GROUP BY pr.machine_id, pr.run_date, m.machine_name, m.line_id, m.ideal_cycle_sec;
