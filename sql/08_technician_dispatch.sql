-- ============================================================
-- 08_technician_dispatch.sql — Technician Table + Dispatch Logic
-- Smart assignment based on specialization, skill, availability
-- ============================================================

CREATE OR REPLACE TABLE OEE_CC.RAW.DIM_TECHNICIAN (
    TECHNICIAN_ID VARCHAR(10) NOT NULL,
    TECHNICIAN_NAME VARCHAR(100) NOT NULL,
    SPECIALIZATION VARCHAR(50) NOT NULL,
    SKILL_LEVEL VARCHAR(10) NOT NULL,
    SHIFT_ASSIGNMENT VARCHAR(10) NOT NULL,
    CONTACT_NUMBER VARCHAR(20),
    IS_AVAILABLE BOOLEAN NOT NULL DEFAULT TRUE,
    HIRE_DATE DATE NOT NULL,
    JIRA_EMAIL VARCHAR(100)
);

-- Load 12 technicians (real Jira users mapped to specializations)
INSERT INTO OEE_CC.RAW.DIM_TECHNICIAN VALUES
('TECH-01','Naveen Bharathi','CNC Machining','Senior','DAY','+91-9876543201',TRUE,'2018-03-15','knskings05@gmail.com'),
('TECH-02','Bhavna','Hydraulic Press','Senior','DAY','+91-9876543202',TRUE,'2017-06-22','bhavna.vinodh-pillai@rntbci-nissan.com'),
('TECH-03','Nelakurthi Meghana','Robotics','Mid','DAY','+91-9876543203',TRUE,'2020-01-10','nelakurthi.meghana@rntbci-nissan.com'),
('TECH-04','Asha Jyothi','Electrical Systems','Senior','NIGHT','+91-9876543204',TRUE,'2016-11-05','ashajyothiakula81@gmail.com'),
('TECH-05','Naveen Bharathi','CNC Machining','Mid','NIGHT','+91-9876543205',FALSE,'2021-04-18','knskings05@gmail.com'),
('TECH-06','Nelakurthi Meghana','Bearing & Spindle','Senior','DAY','+91-9876543206',TRUE,'2015-08-30','nelakurthi.meghana@rntbci-nissan.com'),
('TECH-07','Bhavna','Hydraulic Press','Junior','DAY','+91-9876543207',TRUE,'2024-02-14','bhavna.vinodh-pillai@rntbci-nissan.com'),
('TECH-08','Asha Jyothi','Robotics','Mid','NIGHT','+91-9876543208',TRUE,'2022-07-01','ashajyothiakula81@gmail.com'),
('TECH-09','Naveen Bharathi','Thermal Systems','Senior','DAY','+91-9876543209',FALSE,'2019-05-20','knskings05@gmail.com'),
('TECH-10','Nelakurthi Meghana','CNC Machining','Junior','NIGHT','+91-9876543210',TRUE,'2025-01-08','nelakurthi.meghana@rntbci-nissan.com'),
('TECH-11','Asha Jyothi','Electrical Systems','Mid','DAY','+91-9876543211',TRUE,'2021-09-12','ashajyothiakula81@gmail.com'),
('TECH-12','Bhavna','Bearing & Spindle','Mid','NIGHT','+91-9876543212',TRUE,'2023-03-25','bhavna.vinodh-pillai@rntbci-nissan.com');

-- Dispatch rules (applied inside DRAFT_WORK_ORDERS procedure in 07_work_orders.sql):
--
-- 1. SPECIALIZATION MATCH (machine_type -> required specialization):
--    CNC_LATHE/CNC_MILL  -> 'CNC Machining'
--    HYDRAULIC_PRESS     -> 'Hydraulic Press'
--    ROBOTIC_WELDER      -> 'Robotics'
--    (other)             -> 'Electrical Systems' (fallback)
--
-- 2. AVAILABILITY: only IS_AVAILABLE = TRUE
--
-- 3. SKILL PREFERENCE:
--    HIGH severity  -> prefer Senior
--    MEDIUM/LOW     -> Junior acceptable (save Senior for HIGH)
--
-- 4. LOAD BALANCING: fewest open work orders (DRAFTED/TICKETED/ACKNOWLEDGED)
--
-- 5. TIE-BREAKER: earliest hire_date (most experienced)
--
-- Jira integration: technician's jira_email is used to look up their
-- Atlassian accountId and set them as the real Jira issue assignee.
