-- ============================================================
-- 07_work_orders.sql — Work Order Table + Drafting Procedure
-- Self-healing loop: anomaly -> work order -> Jira ticket
-- Includes smart technician dispatch from DIM_TECHNICIAN
-- ============================================================

create or replace TABLE OEE_CC.OPS.WORK_ORDER (
    WO_ID NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
    MACHINE_ID VARCHAR(10),
    ANOMALY_TS TIMESTAMP_NTZ(9),
    DETECTED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    SEVERITY VARCHAR(10),
    RECOMMENDED_PART VARCHAR(20),
    ROOT_CAUSE VARCHAR(2000),
    EST_COST_USD FLOAT,
    LOOP_STATUS VARCHAR(20) DEFAULT 'DRAFTED',
    EXTERNAL_TICKET VARCHAR(50),
    ASSIGNED_TECHNICIAN_ID VARCHAR(10),
    ASSIGNED_TECHNICIAN_NAME VARCHAR(100),
    primary key (WO_ID)
);

-- Idempotent procedure: one open work order per affected machine
-- Dispatch rules (from technician-dispatch skill):
--   1. Match machine_type -> specialization
--   2. Only IS_AVAILABLE = TRUE technicians
--   3. HIGH severity prefers Senior skill level
--   4. Load-balance by fewest open work orders
--   5. Tie-break by hire date (most experienced first)
CREATE OR REPLACE PROCEDURE OEE_CC.OPS.DRAFT_WORK_ORDERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    MERGE INTO OEE_CC.OPS.WORK_ORDER AS tgt
    USING (
        WITH
        top_anomaly AS (
            SELECT machine_id, anomaly_ts, vibration_deviation_score,
                ROW_NUMBER() OVER (PARTITION BY machine_id
                    ORDER BY vibration_deviation_score DESC, anomaly_ts DESC) AS rn
            FROM OEE_CC.ML.V_ACTIVE_ANOMALIES
        ),
        rep AS (SELECT machine_id, anomaly_ts, vibration_deviation_score FROM top_anomaly WHERE rn = 1),
        rc AS (SELECT machine_id, root_cause_narrative FROM OEE_CC.ML.ROOT_CAUSE_REPORTS),
        hist_parts AS (
            SELECT machine_id, part_used,
                ROW_NUMBER() OVER (PARTITION BY machine_id ORDER BY COUNT(*) DESC) AS rn
            FROM OEE_CC.RAW.IT_MAINTENANCE_RECORD
            WHERE event_type = 'UNPLANNED' AND part_used IS NOT NULL
            GROUP BY machine_id, part_used
        ),
        cost_est AS (
            SELECT machine_id, ROUND(AVG(downtime_cost_usd), 2) AS est_cost_usd
            FROM OEE_CC.CONVERGED.DT_OEE_DAILY
            WHERE run_date >= DATEADD('day', -3, CURRENT_DATE())
            GROUP BY machine_id
        ),
        machine_spec AS (
            SELECT machine_id,
                CASE
                    WHEN machine_type ILIKE '%CNC%'   THEN 'CNC Machining'
                    WHEN machine_type ILIKE '%PRESS%' THEN 'Hydraulic Press'
                    WHEN machine_type ILIKE '%ROBOT%' THEN 'Robotics'
                    ELSE 'Electrical Systems'
                END AS required_spec
            FROM OEE_CC.RAW.DIM_MACHINE
        ),
        tech_load AS (
            SELECT assigned_technician_id, COUNT(*) AS open_wos
            FROM OEE_CC.OPS.WORK_ORDER
            WHERE loop_status IN ('DRAFTED','TICKETED','ACKNOWLEDGED')
              AND assigned_technician_id IS NOT NULL
            GROUP BY assigned_technician_id
        ),
        tech_ranked AS (
            SELECT r.machine_id, t.technician_id, t.technician_name,
                ROW_NUMBER() OVER (
                    PARTITION BY r.machine_id
                    ORDER BY
                        CASE
                            WHEN r.vibration_deviation_score > 2.5 AND t.skill_level = 'Senior' THEN 0
                            WHEN r.vibration_deviation_score > 2.5 AND t.skill_level = 'Mid'    THEN 1
                            WHEN r.vibration_deviation_score > 2.5 AND t.skill_level = 'Junior' THEN 2
                            WHEN t.skill_level = 'Senior' THEN 1
                            WHEN t.skill_level = 'Mid'    THEN 0
                            WHEN t.skill_level = 'Junior' THEN 0
                            ELSE 3
                        END ASC,
                        COALESCE(tl.open_wos, 0) ASC,
                        t.hire_date ASC
                ) AS tech_rank
            FROM rep r
            JOIN machine_spec ms ON r.machine_id = ms.machine_id
            JOIN OEE_CC.RAW.DIM_TECHNICIAN t
                ON t.specialization = ms.required_spec AND t.is_available = TRUE
            LEFT JOIN tech_load tl ON t.technician_id = tl.assigned_technician_id
        ),
        best_tech AS (SELECT machine_id, technician_id, technician_name FROM tech_ranked WHERE tech_rank = 1)
        SELECT r.machine_id, r.anomaly_ts, r.vibration_deviation_score,
            CASE WHEN r.vibration_deviation_score > 2.5 THEN 'HIGH'
                 WHEN r.vibration_deviation_score > 1.0 THEN 'MEDIUM' ELSE 'LOW' END AS severity,
            COALESCE(hp.part_used, 'BRG-204') AS recommended_part,
            rc.root_cause_narrative AS root_cause,
            COALESCE(ce.est_cost_usd, 0) AS est_cost_usd,
            bt.technician_id AS assigned_technician_id,
            bt.technician_name AS assigned_technician_name
        FROM rep r
        LEFT JOIN rc ON r.machine_id = rc.machine_id
        LEFT JOIN hist_parts hp ON r.machine_id = hp.machine_id AND hp.rn = 1
        LEFT JOIN cost_est ce ON r.machine_id = ce.machine_id
        LEFT JOIN best_tech bt ON r.machine_id = bt.machine_id
    ) AS src
    ON tgt.machine_id = src.machine_id AND tgt.loop_status <> 'CLOSED'
    WHEN NOT MATCHED THEN
        INSERT (machine_id, anomaly_ts, detected_at, severity, recommended_part,
                root_cause, est_cost_usd, loop_status,
                assigned_technician_id, assigned_technician_name)
        VALUES (src.machine_id, src.anomaly_ts, CURRENT_TIMESTAMP(), src.severity,
                src.recommended_part, src.root_cause, src.est_cost_usd, 'DRAFTED',
                src.assigned_technician_id, src.assigned_technician_name)
    WHEN MATCHED THEN
        UPDATE SET anomaly_ts = src.anomaly_ts, severity = src.severity,
                   root_cause = src.root_cause, est_cost_usd = src.est_cost_usd,
                   assigned_technician_id = src.assigned_technician_id,
                   assigned_technician_name = src.assigned_technician_name;
    RETURN 'Work orders drafted with technician assignments';
END;
$$;

CALL OEE_CC.OPS.DRAFT_WORK_ORDERS();
