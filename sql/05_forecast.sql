-- ============================================================
-- 05_forecast.sql — Temperature Forecast + Countdown to Failure
-- Cortex ML multi-series forecast, 60-minute projection
-- ============================================================

-- Training view (same split as anomaly: older than last 3 days)
CREATE OR REPLACE VIEW OEE_CC.ML.V_TRAIN_TEMP_FORECAST AS
SELECT machine_id AS series, minute_ts AS timestamp, avg_temperature_c AS value
FROM OEE_CC.CONVERGED.DT_SENSOR_MINUTE
WHERE minute_ts < DATEADD('day', -3, CURRENT_TIMESTAMP());

-- Train forecast model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST OEE_CC.ML.TEMP_FORECAST_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'OEE_CC.ML.V_TRAIN_TEMP_FORECAST'),
    SERIES_COLNAME => 'SERIES',
    TIMESTAMP_COLNAME => 'TIMESTAMP',
    TARGET_COLNAME => 'VALUE'
);

-- Generate 60-minute forecast
CREATE OR REPLACE TABLE OEE_CC.ML.TEMP_FORECAST_60 AS
SELECT * FROM TABLE(OEE_CC.ML.TEMP_FORECAST_MODEL!FORECAST(
    FORECASTING_PERIODS => 60,
    CONFIG_OBJECT => {'prediction_interval': 0.95}
));

-- V_TEMP_RISK: machines predicted to breach baseline + 8C threshold
CREATE OR REPLACE VIEW OEE_CC.ML.V_TEMP_RISK AS
WITH baselines AS (
    SELECT machine_id, MEDIAN(avg_temperature_c) AS baseline_temp_c
    FROM OEE_CC.CONVERGED.DT_SENSOR_MINUTE
    WHERE minute_ts < DATEADD('day', -3, CURRENT_TIMESTAMP())
    GROUP BY machine_id
),
forecast_with_baseline AS (
    SELECT
        f.SERIES AS machine_id, f.TS AS forecast_ts,
        ROUND(f.FORECAST, 1) AS forecast_temp_c,
        ROUND(f.UPPER_BOUND, 1) AS forecast_upper_c,
        ROUND(b.baseline_temp_c, 1) AS baseline_temp_c,
        ROUND(b.baseline_temp_c + 8, 1) AS breach_threshold_c
    FROM OEE_CC.ML.TEMP_FORECAST_60 f
    JOIN baselines b ON f.SERIES = b.machine_id
),
breach_machines AS (
    SELECT machine_id, baseline_temp_c, breach_threshold_c,
        MIN(CASE WHEN forecast_temp_c > breach_threshold_c
            THEN DATEDIFF('minute', CURRENT_TIMESTAMP(), forecast_ts) END) AS minutes_to_breach,
        MAX(forecast_temp_c) AS peak_forecast_temp_c,
        ROUND(MAX(forecast_temp_c) - baseline_temp_c, 1) AS peak_deviation_c,
        SUM(CASE WHEN forecast_temp_c > breach_threshold_c THEN 1 ELSE 0 END) AS breach_minutes
    FROM forecast_with_baseline
    GROUP BY machine_id, baseline_temp_c, breach_threshold_c
    HAVING SUM(CASE WHEN forecast_temp_c > breach_threshold_c THEN 1 ELSE 0 END) > 0
)
SELECT machine_id, baseline_temp_c, breach_threshold_c,
    peak_forecast_temp_c, peak_deviation_c, minutes_to_breach, breach_minutes,
    CASE
        WHEN minutes_to_breach <= 0  THEN 'CRITICAL — ALREADY IN BREACH'
        WHEN minutes_to_breach <= 15 THEN 'CRITICAL'
        WHEN minutes_to_breach <= 30 THEN 'WARNING'
        ELSE 'WATCH'
    END AS risk_level
FROM breach_machines ORDER BY minutes_to_breach;
