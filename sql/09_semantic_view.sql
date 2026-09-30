-- ============================================================
-- 09_semantic_view.sql — Cortex Analyst Semantic View
-- Natural-language queries over OEE, work orders, and technicians
-- ============================================================

CREATE OR REPLACE SEMANTIC VIEW OEE_CC.APP.OEE_SEMANTIC
    TABLES (
        OEE_DAILY AS OEE_CC.CONVERGED.DT_OEE_DAILY
            PRIMARY KEY (MACHINE_ID, RUN_DATE)
            WITH SYNONYMS = ('daily OEE', 'production metrics')
            COMMENT = 'Daily OEE metrics per machine with downtime cost',
        MACHINE_HEALTH AS OEE_CC.CONVERGED.DT_MACHINE_HEALTH
            PRIMARY KEY (MACHINE_ID, MINUTE_TS)
            COMMENT = 'Per-minute converged IT/OT sensor readings with machine and production context',
        WORK_ORDERS AS OEE_CC.OPS.WORK_ORDER
            PRIMARY KEY (WO_ID)
            WITH SYNONYMS = ('work order', 'ticket', 'alert', 'maintenance request')
            COMMENT = 'Work orders from anomaly detection with Jira tickets and assigned technicians',
        TECHNICIANS AS OEE_CC.RAW.DIM_TECHNICIAN
            PRIMARY KEY (TECHNICIAN_ID)
            WITH SYNONYMS = ('technician', 'engineer', 'maintenance staff', 'repair crew')
            COMMENT = 'Maintenance technicians with specialization, skill level, shift, and Jira identity'
    )
    RELATIONSHIPS (
        HEALTH_TO_OEE AS MACHINE_HEALTH(MACHINE_ID) REFERENCES OEE_DAILY(MACHINE_ID),
        WO_TO_OEE AS WORK_ORDERS(MACHINE_ID) REFERENCES OEE_DAILY(MACHINE_ID),
        WO_TO_TECH AS WORK_ORDERS(ASSIGNED_TECHNICIAN_ID) REFERENCES TECHNICIANS(TECHNICIAN_ID)
    )
    FACTS (
        OEE_DAILY.PLANNED_TIME_MIN AS planned_time_min COMMENT = 'Total planned production time in minutes',
        OEE_DAILY.DOWNTIME_MIN AS downtime_min WITH SYNONYMS = ('downtime', 'downtime minutes') COMMENT = 'Total downtime in minutes',
        OEE_DAILY.UNITS_PRODUCED AS units_produced WITH SYNONYMS = ('output', 'production', 'parts produced') COMMENT = 'Total units produced',
        OEE_DAILY.UNITS_GOOD AS units_good WITH SYNONYMS = ('good parts', 'good units') COMMENT = 'Units that passed quality inspection',
        OEE_DAILY.RUNTIME_MIN AS runtime_min WITH SYNONYMS = ('runtime', 'operating time') COMMENT = 'Actual operating time in minutes',
        WORK_ORDERS.EST_COST_USD AS est_cost_usd WITH SYNONYMS = ('estimated cost', 'repair cost', 'work order cost') COMMENT = 'Estimated cost impact of the work order in USD'
    )
    DIMENSIONS (
        OEE_DAILY.MACHINE_ID AS machine_id WITH SYNONYMS = ('machine', 'equipment', 'asset') COMMENT = 'Unique machine identifier',
        OEE_DAILY.MACHINE_NAME AS machine_name WITH SYNONYMS = ('machine name', 'equipment name') COMMENT = 'Human-readable machine name',
        OEE_DAILY.LINE_ID AS line_id WITH SYNONYMS = ('production line', 'line') COMMENT = 'Production line the machine belongs to',
        OEE_DAILY.RUN_DATE AS run_date WITH SYNONYMS = ('date', 'day', 'shift date', 'production date') COMMENT = 'Calendar date of the production run',
        MACHINE_HEALTH.MACHINE_TYPE AS machine_type WITH SYNONYMS = ('type', 'equipment type') COMMENT = 'Machine type',
        MACHINE_HEALTH.MINUTE_TS AS minute_ts WITH SYNONYMS = ('timestamp', 'reading time', 'sensor time') COMMENT = 'Minute-level timestamp of the sensor reading',
        WORK_ORDERS.WO_ID AS wo_id WITH SYNONYMS = ('work order number', 'WO number') COMMENT = 'Unique work order identifier',
        WORK_ORDERS.SEVERITY AS severity WITH SYNONYMS = ('priority', 'urgency', 'alert level') COMMENT = 'Work order severity: HIGH, MEDIUM, or LOW',
        WORK_ORDERS.LOOP_STATUS AS loop_status WITH SYNONYMS = ('work order status', 'ticket status') COMMENT = 'DRAFTED, TICKETED, ACKNOWLEDGED, CLOSED',
        WORK_ORDERS.EXTERNAL_TICKET AS external_ticket WITH SYNONYMS = ('Jira key', 'ticket key', 'Jira issue') COMMENT = 'External Jira ticket key',
        WORK_ORDERS.ASSIGNED_TECHNICIAN_NAME AS assigned_technician_name WITH SYNONYMS = ('assigned to', 'who is assigned') COMMENT = 'Name of the assigned technician',
        TECHNICIANS.TECHNICIAN_ID AS technician_id WITH SYNONYMS = ('tech ID', 'staff ID') COMMENT = 'Unique technician identifier',
        TECHNICIANS.TECHNICIAN_NAME AS technician_name WITH SYNONYMS = ('tech name', 'engineer name') COMMENT = 'Full name of the technician',
        TECHNICIANS.SPECIALIZATION AS specialization WITH SYNONYMS = ('expertise', 'skill area', 'trade') COMMENT = 'Technician specialization area',
        TECHNICIANS.SKILL_LEVEL AS skill_level WITH SYNONYMS = ('experience level', 'seniority') COMMENT = 'Skill level: Senior, Mid, or Junior',
        TECHNICIANS.SHIFT_ASSIGNMENT AS shift_assignment WITH SYNONYMS = ('shift', 'work shift') COMMENT = 'Shift assignment: DAY or NIGHT',
        TECHNICIANS.IS_AVAILABLE AS is_available WITH SYNONYMS = ('available', 'on duty') COMMENT = 'Whether the technician is available'
    )
    METRICS (
        OEE_DAILY.OEE AS AVG(oee) WITH SYNONYMS = ('overall equipment effectiveness', 'machine efficiency', 'OEE score') COMMENT = 'OEE = Availability x Performance x Quality',
        OEE_DAILY.AVAILABILITY AS AVG(availability) WITH SYNONYMS = ('uptime', 'machine availability') COMMENT = 'Fraction of planned time machine was running',
        OEE_DAILY.PERFORMANCE AS AVG(performance) WITH SYNONYMS = ('speed efficiency', 'throughput efficiency') COMMENT = 'Actual output vs theoretical maximum during runtime',
        OEE_DAILY.QUALITY AS AVG(quality) WITH SYNONYMS = ('quality rate', 'yield', 'first pass yield') COMMENT = 'Fraction of produced units that passed quality',
        OEE_DAILY.DOWNTIME_COST_USD AS SUM(downtime_cost_usd) WITH SYNONYMS = ('money lost', 'downtime cost', 'dollars lost') COMMENT = 'Dollars lost due to downtime',
        MACHINE_HEALTH.AVG_VIBRATION AS AVG(avg_vibration_mm_s) WITH SYNONYMS = ('vibration', 'vibration level') COMMENT = 'Average vibration in mm/s',
        MACHINE_HEALTH.AVG_TEMPERATURE AS AVG(avg_temperature_c) WITH SYNONYMS = ('temperature', 'temp', 'heat') COMMENT = 'Average temperature in Celsius',
        WORK_ORDERS.WORK_ORDER_COUNT AS COUNT(wo_id) WITH SYNONYMS = ('work order count', 'number of work orders', 'workload') COMMENT = 'Number of work orders'
    )
    COMMENT = 'Manufacturing OEE analytics with technician dispatch - efficiency, costs, work orders, and technician workload'
    AI_SQL_GENERATION 'Round percentages to 1 decimal. Round dollars to 2 decimals. Multiply OEE by 100 for display. Join WORK_ORDER to DIM_TECHNICIAN on assigned_technician_id = technician_id. Open work orders have loop_status IN (DRAFTED, TICKETED, ACKNOWLEDGED).'
    AI_VERIFIED_QUERIES (
        HIGHEST_DOWNTIME_COST_7D AS (
            QUESTION 'Which machine had the highest downtime cost in the last 7 days and what was its OEE?'
            SQL 'SELECT machine_id, ROUND(SUM(downtime_cost_usd), 2) AS total_downtime_cost, ROUND(AVG(oee) * 100, 1) AS avg_oee_pct FROM OEE_CC.CONVERGED.DT_OEE_DAILY WHERE run_date >= DATEADD(''day'', -7, CURRENT_DATE()) GROUP BY machine_id ORDER BY total_downtime_cost DESC LIMIT 1'
        ),
        OEE_BREAKDOWN AS (
            QUESTION 'Show me OEE breakdown by machine and day'
            SQL 'SELECT machine_id, run_date, ROUND(oee * 100, 1) AS oee_pct, ROUND(availability * 100, 1) AS availability_pct, ROUND(performance * 100, 1) AS performance_pct, ROUND(quality * 100, 1) AS quality_pct FROM OEE_CC.CONVERGED.DT_OEE_DAILY ORDER BY run_date DESC, machine_id'
        ),
        DOWNTIME_COST_PER_MACHINE AS (
            QUESTION 'What is the total downtime cost per machine?'
            SQL 'SELECT machine_id, SUM(downtime_min) AS total_downtime_min, ROUND(SUM(downtime_cost_usd), 2) AS total_cost_usd FROM OEE_CC.CONVERGED.DT_OEE_DAILY GROUP BY machine_id ORDER BY total_cost_usd DESC'
        ),
        OPEN_WO_PER_TECHNICIAN AS (
            QUESTION 'How many open work orders does each technician have?'
            SQL 'SELECT t.technician_name, t.specialization, t.skill_level, COUNT(wo.wo_id) AS open_work_orders FROM OEE_CC.RAW.DIM_TECHNICIAN t LEFT JOIN OEE_CC.OPS.WORK_ORDER wo ON t.technician_id = wo.assigned_technician_id AND wo.loop_status IN (''DRAFTED'', ''TICKETED'', ''ACKNOWLEDGED'') GROUP BY t.technician_name, t.specialization, t.skill_level ORDER BY open_work_orders DESC'
        ),
        SPECIALIZATION_WORK_ORDERS AS (
            QUESTION 'Which specialization has the most work orders?'
            SQL 'SELECT t.specialization, COUNT(wo.wo_id) AS work_order_count, ROUND(SUM(wo.est_cost_usd), 2) AS total_est_cost FROM OEE_CC.OPS.WORK_ORDER wo JOIN OEE_CC.RAW.DIM_TECHNICIAN t ON wo.assigned_technician_id = t.technician_id GROUP BY t.specialization ORDER BY work_order_count DESC'
        )
    );
