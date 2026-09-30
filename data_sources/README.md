# Data Sources

Exported from OEE_CC database. These CSVs are snapshots of live Snowflake tables.

## Files

| File | Table | Rows | Description |
|------|-------|------|-------------|
| DIM_MACHINE.csv | OEE_CC.RAW.DIM_MACHINE | 4 | Machine dimension: machine_id, machine_name, line_id, machine_type, ideal_cycle_sec, warehouse_loc |
| OT_SENSOR_READING.csv | OEE_CC.RAW.OT_SENSOR_READING | ~80,670 | OT sensor readings: reading_id, machine_id, ts, vibration_mm_s, temperature_c, rpm, load_pct. Too large for CSV; regenerate with sql/02_data_generation.sql |
| IT_PRODUCTION_RUN.csv | OEE_CC.RAW.IT_PRODUCTION_RUN | 112 | Daily production runs per shift: run_id, machine_id, run_date, shift, planned_time_min, downtime_min, units_produced, units_good, unit_margin_usd |
| IT_MAINTENANCE_RECORD.csv | OEE_CC.RAW.IT_MAINTENANCE_RECORD | 7 | Maintenance events: record_id, machine_id, event_ts, event_type (PLANNED/UNPLANNED), failure_mode, part_used, downtime_min, notes |
| IT_PARTS_INVENTORY.csv | OEE_CC.RAW.IT_PARTS_INVENTORY | 8 | Spare parts: part_id, part_name, warehouse_loc, qty_on_hand, reorder_point, unit_cost_usd |
| DIM_TECHNICIAN.csv | OEE_CC.RAW.DIM_TECHNICIAN | 12 | Technicians: technician_id, technician_name, specialization, skill_level, shift_assignment, contact_number, is_available, hire_date, jira_email |
| WORK_ORDER.csv | OEE_CC.OPS.WORK_ORDER | 3 | Active work orders: wo_id, machine_id, anomaly_ts, severity, recommended_part, root_cause, est_cost_usd, loop_status, external_ticket, assigned_technician_id, assigned_technician_name |
| ROOT_CAUSE_REPORTS.csv | OEE_CC.ML.ROOT_CAUSE_REPORTS | 3 | AI-generated root-cause narratives: machine_id, anomaly_ts, deviation_score, root_cause_narrative |

## Notes

- OT_SENSOR_READING has ~80K rows (1 reading/min/machine x 4 machines x 14 days). A sample CSV is provided; regenerate full data using `sql/02_data_generation.sql`.
- All failures are placed within the last 3 days of the 14-day window, with correlated vibration+temperature ramp-up signatures in the ~50 minutes before each failure.
