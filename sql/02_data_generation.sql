-- ============================================================
-- 02_data_generation.sql — RAW Tables (DDL from GET_DDL)
-- Data was generated using Snowflake GENERATOR functions and
-- manual INSERT statements for correlated failure signatures.
-- See data_sources/ for exported CSV snapshots.
-- ============================================================

-- Machine dimension
create or replace TABLE OEE_CC.RAW.DIM_MACHINE (
    MACHINE_ID VARCHAR(10) NOT NULL,
    MACHINE_NAME VARCHAR(50),
    LINE_ID VARCHAR(10),
    MACHINE_TYPE VARCHAR(30),
    IDEAL_CYCLE_SEC FLOAT,
    WAREHOUSE_LOC VARCHAR(10),
    primary key (MACHINE_ID)
);

-- OT sensor readings (1 per minute per machine, ~80K rows over 14 days)
create or replace TABLE OEE_CC.RAW.OT_SENSOR_READING (
    READING_ID NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
    MACHINE_ID VARCHAR(10),
    TS TIMESTAMP_NTZ(9),
    VIBRATION_MM_S FLOAT,
    TEMPERATURE_C FLOAT,
    RPM NUMBER(38,0),
    LOAD_PCT FLOAT,
    primary key (READING_ID)
);

-- Enable change tracking for dynamic tables
ALTER TABLE OEE_CC.RAW.OT_SENSOR_READING SET CHANGE_TRACKING = TRUE;

-- IT production runs (per day per shift)
create or replace TABLE OEE_CC.RAW.IT_PRODUCTION_RUN (
    RUN_ID NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
    MACHINE_ID VARCHAR(10),
    RUN_DATE DATE,
    SHIFT VARCHAR(10),
    PLANNED_TIME_MIN NUMBER(38,0),
    DOWNTIME_MIN NUMBER(38,0),
    UNITS_PRODUCED NUMBER(38,0),
    UNITS_GOOD NUMBER(38,0),
    UNIT_MARGIN_USD FLOAT,
    primary key (RUN_ID)
);

ALTER TABLE OEE_CC.RAW.IT_PRODUCTION_RUN SET CHANGE_TRACKING = TRUE;

-- Maintenance records (planned + unplanned events)
create or replace TABLE OEE_CC.RAW.IT_MAINTENANCE_RECORD (
    RECORD_ID NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
    MACHINE_ID VARCHAR(10),
    EVENT_TS TIMESTAMP_NTZ(9),
    EVENT_TYPE VARCHAR(20),
    FAILURE_MODE VARCHAR(30),
    PART_USED VARCHAR(20),
    DOWNTIME_MIN NUMBER(38,0),
    NOTES VARCHAR(500),
    primary key (RECORD_ID)
);

-- Spare parts inventory
create or replace TABLE OEE_CC.RAW.IT_PARTS_INVENTORY (
    PART_ID VARCHAR(20) NOT NULL,
    PART_NAME VARCHAR(60),
    WAREHOUSE_LOC VARCHAR(10),
    QTY_ON_HAND NUMBER(38,0),
    REORDER_POINT NUMBER(38,0),
    UNIT_COST_USD FLOAT,
    primary key (PART_ID)
);

-- Note: Data was generated with Snowflake GENERATOR functions for sensor readings
-- and manual INSERTs for dimension/reference tables. All failures are placed in
-- the last 3 days with correlated vibration+temperature ramp-up signatures.
-- Run sql/02_load_data.sql or import from data_sources/*.csv to populate.
