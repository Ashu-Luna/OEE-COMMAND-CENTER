import streamlit as st
import pandas as pd
import altair as alt
import json
import _snowflake
from datetime import datetime
from snowflake.snowpark.context import get_active_session
 
st.set_page_config(page_title="OEE Command Center", layout="wide")
session = get_active_session()
 
@st.cache_data(ttl=120, show_spinner=False)
def cached_query(sql):
    return session.sql(sql).to_pandas()
 
def query(sql):
    return session.sql(sql).to_pandas()
 
st.markdown("""
<style>
    .kpi-card { padding: 1.2rem; border-radius: 10px; text-align: center; border: 1px solid #e0e0e0; margin-bottom: 0.5rem; }
    .kpi-green { background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%); border-color: #28a745; }
    .kpi-amber { background: linear-gradient(135deg, #fff3cd 0%, #ffeaa7 100%); border-color: #ffc107; }
    .kpi-red { background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%); border-color: #dc3545; }
    .kpi-value { font-size: 2.2rem; font-weight: 700; margin: 0.3rem 0; }
    .kpi-label { font-size: 0.85rem; color: #555; font-weight: 600; }
    .kpi-sub { font-size: 0.75rem; color: #777; margin-top: 0.2rem; }
    .kpi-status { font-size: 0.7rem; font-weight: 700; padding: 2px 8px; border-radius: 12px; display: inline-block; margin-top: 0.3rem; }
    .status-wc { background: #28a745; color: white; }
    .status-att { background: #ffc107; color: #333; }
    .status-crit { background: #dc3545; color: white; }
    .badge { padding: 3px 10px; border-radius: 12px; font-size: 0.78rem; font-weight: 600; display: inline-block; }
    .badge-high { background: #dc3545; color: white; }
    .badge-med { background: #fd7e14; color: white; }
    .badge-low { background: #28a745; color: white; }
    .pipeline { font-size: 0.8rem; color: #888; }
    .pipe-active { font-weight: 700; color: #0d6efd; }
    .summary-card { padding: 1rem 1.5rem; border-radius: 8px; text-align: center; background: linear-gradient(135deg, #e8f4fd 0%, #d1ecf1 100%); border: 1px solid #bee5eb; }
    .summary-val { font-size: 1.8rem; font-weight: 700; color: #0c5460; }
    .summary-lbl { font-size: 0.8rem; color: #0c5460; font-weight: 600; }
    .countdown-card { padding: 1rem; border-radius: 8px; text-align: center; background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%); border: 2px solid #dc3545; }
    .countdown-val { font-size: 2rem; font-weight: 700; color: #721c24; }
    .countdown-lbl { font-size: 0.75rem; color: #721c24; }
    .tech-card { padding: 0.8rem 1rem; border-radius: 8px; text-align: center; border: 1px solid #e0e0e0; margin-bottom: 0.5rem; }
    .tech-avail { background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%); border-color: #28a745; }
    .tech-busy { background: linear-gradient(135deg, #fff3cd 0%, #ffeaa7 100%); border-color: #ffc107; }
    .tech-off { background: linear-gradient(135deg, #e2e3e5 0%, #d6d8db 100%); border-color: #6c757d; }
    [data-testid="stSidebar"] > div:first-child { padding-top: 0.5rem; padding-bottom: 0.5rem; }
    [data-testid="stSidebar"] [data-testid="stVerticalBlock"] { gap: 0.3rem; }
    .sidebar-title { font-size: 1.6rem; font-weight: 800; margin: 0 0 0.1rem 0; line-height: 1.2; }
    .sidebar-subtitle { font-size: 0.95rem; font-weight: 600; color: #adb5bd; margin: 0 0 0.2rem 0; }
    .sidebar-divider { border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 0.2rem 0; }
</style>
""", unsafe_allow_html=True)
 
with st.sidebar:
    st.markdown('<p class="sidebar-title">Predictive Maintenance</p><p class="sidebar-subtitle">OEE Command Center</p>', unsafe_allow_html=True)
    st.markdown('<hr class="sidebar-divider">', unsafe_allow_html=True)
    all_machines = cached_query("SELECT machine_id FROM OEE_CC.RAW.DIM_MACHINE ORDER BY machine_id")
    machine_list = all_machines["MACHINE_ID"].tolist()
    selected_machines = st.multiselect("Filter Machines", options=machine_list, default=machine_list, help="Select one or more machines to analyze")
    date_range = st.radio("Date Range", options=["7 days", "14 days", "30 days"], index=1, help="Time window for OEE and cost analysis")
    days_back = int(date_range.split()[0])
    st.markdown('<hr class="sidebar-divider">', unsafe_allow_html=True)
    st.caption(f"Last refreshed: {datetime.now().strftime('%Y-%m-%d %H:%M')} | Snowflake Cortex")
 
if not selected_machines:
    st.warning("Please select at least one machine from the sidebar.")
    st.stop()
 
machine_filter = "', '".join(selected_machines)
machine_sql = f"IN ('{machine_filter}')"
st.markdown("## Predictive Maintenance Command Center")
 
summary_df = cached_query(f"SELECT ROUND(AVG(oee)*100,1) AS plant_oee, COUNT(DISTINCT machine_id) AS machine_count, SUM(downtime_min) AS total_downtime, ROUND(SUM(downtime_cost_usd),0) AS total_cost FROM OEE_CC.CONVERGED.DT_OEE_DAILY WHERE machine_id {machine_sql} AND run_date >= DATEADD('day', -{days_back}, CURRENT_DATE())")
anomaly_count_df = cached_query(f"SELECT COUNT(DISTINCT machine_id) AS cnt FROM OEE_CC.ML.V_ACTIVE_ANOMALIES WHERE machine_id {machine_sql}")
wo_count_df = cached_query(f"SELECT COUNT(*) AS cnt FROM OEE_CC.OPS.WORK_ORDER WHERE machine_id {machine_sql} AND loop_status != 'CLOSED'")
s = summary_df.iloc[0]
anom_cnt = int(anomaly_count_df.iloc[0]["CNT"])
wo_cnt = int(wo_count_df.iloc[0]["CNT"])
tech_on_df = cached_query("SELECT COUNT(*) AS cnt FROM OEE_CC.RAW.DIM_TECHNICIAN WHERE is_available = TRUE")
tech_on = int(tech_on_df.iloc[0]["CNT"])
c1, c2, c3, c4, c5 = st.columns(5)
with c1:
    plant_oee = float(s["PLANT_OEE"]) if s["PLANT_OEE"] is not None else 0
    oee_color = "#28a745" if plant_oee >= 85 else ("#ffc107" if plant_oee >= 65 else "#dc3545")
    st.markdown(f'<div class="summary-card"><div class="summary-lbl">PLANT OEE</div><div class="summary-val" style="color:{oee_color}">{plant_oee:.1f}%</div></div>', unsafe_allow_html=True)
with c2:
    st.markdown(f'<div class="summary-card"><div class="summary-lbl">MACHINES MONITORED</div><div class="summary-val">{int(s["MACHINE_COUNT"])}</div></div>', unsafe_allow_html=True)
with c3:
    anom_color = "#dc3545" if anom_cnt > 0 else "#28a745"
    st.markdown(f'<div class="summary-card"><div class="summary-lbl">MACHINES WITH ANOMALIES</div><div class="summary-val" style="color:{anom_color}">{anom_cnt}</div></div>', unsafe_allow_html=True)
with c4:
    wo_color = "#dc3545" if wo_cnt > 0 else "#28a745"
    st.markdown(f'<div class="summary-card"><div class="summary-lbl">OPEN WORK ORDERS</div><div class="summary-val" style="color:{wo_color}">{wo_cnt}</div></div>', unsafe_allow_html=True)
with c5:
    st.markdown(f'<div class="summary-card"><div class="summary-lbl">TECHNICIANS ON DUTY</div><div class="summary-val">{tech_on}/12</div></div>', unsafe_allow_html=True)
st.markdown("")
tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs(["OEE Dashboard", "Downtime Cost", "Root-Cause & Alerts", "Work Orders", "Workforce", "Ask the Factory"])
 
with tab1:
    st.markdown("#### OEE by Machine")
    oee_df = cached_query(f"SELECT machine_id, machine_name, ROUND(AVG(availability)*100,1) AS availability_pct, ROUND(AVG(performance)*100,1) AS performance_pct, ROUND(AVG(quality)*100,1) AS quality_pct, ROUND(AVG(oee)*100,1) AS oee_pct FROM OEE_CC.CONVERGED.DT_OEE_DAILY WHERE machine_id {machine_sql} AND run_date >= DATEADD('day', -{days_back}, CURRENT_DATE()) GROUP BY machine_id, machine_name ORDER BY machine_id")
    cols = st.columns(len(oee_df))
    for i, row in oee_df.iterrows():
        with cols[i]:
            oee_val = float(row["OEE_PCT"])
            if oee_val >= 85: css_class, status_class, status_text = "kpi-green", "status-wc", "WORLD CLASS"
            elif oee_val >= 65: css_class, status_class, status_text = "kpi-amber", "status-att", "NEEDS ATTENTION"
            else: css_class, status_class, status_text = "kpi-red", "status-crit", "CRITICAL"
            st.markdown(f'<div class="kpi-card {css_class}"><div class="kpi-label">{row["MACHINE_NAME"]}</div><div class="kpi-value">{oee_val}%</div><div class="kpi-sub">A: {row["AVAILABILITY_PCT"]}% | P: {row["PERFORMANCE_PCT"]}% | Q: {row["QUALITY_PCT"]}%</div><span class="kpi-status {status_class}">{status_text}</span></div>', unsafe_allow_html=True)
    st.markdown("")
    st.markdown("#### OEE Trend")
    trend_df = cached_query(f"SELECT run_date, machine_id, ROUND(oee*100,1) AS oee_pct FROM OEE_CC.CONVERGED.DT_OEE_DAILY WHERE machine_id {machine_sql} AND run_date >= DATEADD('day', -{days_back}, CURRENT_DATE()) ORDER BY run_date, machine_id")
    threshold_line = alt.Chart(pd.DataFrame({"y":[85]})).mark_rule(strokeDash=[6,4], color="#28a745", opacity=0.6).encode(y="y:Q")
    trend_chart = alt.Chart(trend_df).mark_line(point=True, strokeWidth=2.5).encode(x=alt.X("RUN_DATE:T", title="Date"), y=alt.Y("OEE_PCT:Q", title="OEE %", scale=alt.Scale(domain=[0,100])), color=alt.Color("MACHINE_ID:N", title="Machine"), tooltip=["RUN_DATE:T","MACHINE_ID:N","OEE_PCT:Q"]).properties(height=350)
    st.altair_chart(trend_chart + threshold_line, use_container_width=True)
    st.caption("Green dashed line = 85% World-Class threshold")
 
with tab2:
    st.markdown("#### Downtime Cost Overview")
    cost_df = cached_query(f"SELECT machine_id, machine_name, SUM(downtime_min) AS total_downtime_min, ROUND(SUM(downtime_cost_usd),2) AS total_cost_usd FROM OEE_CC.CONVERGED.DT_OEE_DAILY WHERE machine_id {machine_sql} AND run_date >= DATEADD('day', -{days_back}, CURRENT_DATE()) GROUP BY machine_id, machine_name ORDER BY total_cost_usd DESC")
    total_cost = float(cost_df["TOTAL_COST_USD"].sum())
    total_downtime = int(cost_df["TOTAL_DOWNTIME_MIN"].sum())
    top_machine = cost_df.iloc[0]
    mc1, mc2, mc3, mc4 = st.columns(4)
    mc1.metric("Total Cost", f"${total_cost:,.0f}")
    mc2.metric("Total Downtime", f"{total_downtime:,} min")
    mc3.metric("Biggest Bleeder", str(top_machine["MACHINE_ID"]))
    mc4.metric("That Machine Cost", f"${float(top_machine['TOTAL_COST_USD']):,.0f}")
    st.markdown("")
    left, right = st.columns([3, 2])
    with left:
        st.markdown("##### Cost by Machine")
        cost_chart = alt.Chart(cost_df).mark_bar(cornerRadiusTopLeft=6, cornerRadiusTopRight=6).encode(x=alt.X("MACHINE_ID:N", title="Machine", sort="-y"), y=alt.Y("TOTAL_COST_USD:Q", title="Downtime Cost (USD)"), color=alt.Color("MACHINE_ID:N", legend=None), tooltip=[alt.Tooltip("MACHINE_ID:N",title="Machine"),alt.Tooltip("TOTAL_COST_USD:Q",title="Cost ($)",format=",.2f"),alt.Tooltip("TOTAL_DOWNTIME_MIN:Q",title="Downtime (min)")]).properties(height=350)
        st.altair_chart(cost_chart, use_container_width=True)
    with right:
        st.markdown("##### Cost Breakdown")
        cost_display = cost_df.copy()
        cost_display["TOTAL_COST_USD"] = cost_display["TOTAL_COST_USD"].apply(lambda x: f"${x:,.2f}")
        cost_display = cost_display.rename(columns={"MACHINE_ID":"Machine","MACHINE_NAME":"Name","TOTAL_DOWNTIME_MIN":"Downtime (min)","TOTAL_COST_USD":"Cost"})
        st.dataframe(cost_display, use_container_width=True, hide_index=True)
    st.markdown("")
    st.markdown("##### Daily Cost Trend")
    daily_cost = cached_query(f"SELECT run_date, machine_id, ROUND(downtime_cost_usd,2) AS cost_usd FROM OEE_CC.CONVERGED.DT_OEE_DAILY WHERE machine_id {machine_sql} AND run_date >= DATEADD('day', -{days_back}, CURRENT_DATE()) ORDER BY run_date")
    daily_chart = alt.Chart(daily_cost).mark_area(opacity=0.6).encode(x=alt.X("RUN_DATE:T",title="Date"), y=alt.Y("sum(COST_USD):Q",title="Daily Cost ($)",stack=True), color=alt.Color("MACHINE_ID:N",title="Machine"), tooltip=["RUN_DATE:T","MACHINE_ID:N","COST_USD:Q"]).properties(height=300)
    st.altair_chart(daily_chart, use_container_width=True)
 
with tab3:
    risk_df = cached_query(f"SELECT machine_id, risk_level, minutes_to_breach, peak_forecast_temp_c, breach_threshold_c FROM OEE_CC.ML.V_TEMP_RISK WHERE machine_id {machine_sql} ORDER BY minutes_to_breach")
    if len(risk_df) > 0:
        st.markdown("#### Countdown to Failure")
        risk_cols = st.columns(len(risk_df))
        for i, row in risk_df.iterrows():
            with risk_cols[i]:
                mins = int(row["MINUTES_TO_BREACH"]) if row["MINUTES_TO_BREACH"] is not None else 0
                if mins <= 0:
                    display_val = "IN BREACH"
                    card_css = 'background: linear-gradient(135deg, #dc3545 0%, #c82333 100%); border-color: #dc3545;'
                    lbl_color = 'color: white;'
                else:
                    display_val = f"{mins} min"
                    card_css = 'background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%); border: 2px solid #dc3545;'
                    lbl_color = 'color: #721c24;'
                st.markdown(f'<div style="padding:1rem; border-radius:8px; text-align:center; {card_css}"><div style="font-size:0.75rem; {lbl_color}">{row["MACHINE_ID"]} - {row["RISK_LEVEL"]}</div><div style="font-size:2rem; font-weight:700; {lbl_color}">{display_val}</div><div style="font-size:0.75rem; {lbl_color}">Peak: {row["PEAK_FORECAST_TEMP_C"]}C / Threshold: {row["BREACH_THRESHOLD_C"]}C</div></div>', unsafe_allow_html=True)
        st.markdown("")
    st.markdown("#### AI Root-Cause Narratives")
    rc_df = cached_query(f"SELECT machine_id::VARCHAR AS machine_id, anomaly_ts, deviation_score, root_cause_narrative FROM OEE_CC.ML.ROOT_CAUSE_REPORTS WHERE machine_id::VARCHAR {machine_sql} ORDER BY deviation_score DESC")
    all_spark_df = pd.DataFrame()
    if len(rc_df) > 0:
        rc_machine_filter = "', '".join(rc_df["MACHINE_ID"].tolist())
        all_spark_df = cached_query(f"SELECT machine_id, minute_ts, avg_vibration_mm_s AS vibration, avg_temperature_c AS temperature FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY machine_id ORDER BY minute_ts DESC) AS rn FROM OEE_CC.CONVERGED.DT_SENSOR_MINUTE WHERE machine_id IN ('{rc_machine_filter}')) WHERE rn <= 60 ORDER BY machine_id, minute_ts")
    if len(rc_df) == 0:
        st.success("No active anomalies. All systems normal.")
    else:
        for _, row in rc_df.iterrows():
            machine_id = row["MACHINE_ID"]
            dev_score = float(row["DEVIATION_SCORE"])
            if dev_score > 2.5: sev_badge = '<span class="badge badge-high">HIGH</span>'
            elif dev_score > 1.0: sev_badge = '<span class="badge badge-med">MEDIUM</span>'
            else: sev_badge = '<span class="badge badge-low">LOW</span>'
            with st.expander(f"{machine_id} | Deviation: {dev_score:.1f}", expanded=True):
                st.markdown(f"**Severity:** {sev_badge}", unsafe_allow_html=True)
                st.markdown(f"> {row['ROOT_CAUSE_NARRATIVE']}")
                st.caption(f"Anomaly at: {row['ANOMALY_TS']}")
                spark_df = all_spark_df[all_spark_df["MACHINE_ID"] == machine_id].copy()
                if len(spark_df) > 0:
                    spark_melt = spark_df.melt(id_vars=["MINUTE_TS"], value_vars=["VIBRATION","TEMPERATURE"], var_name="Signal", value_name="Value")
                    spark_chart = alt.Chart(spark_melt).mark_line(strokeWidth=2).encode(x=alt.X("MINUTE_TS:T",title="",axis=alt.Axis(labels=False)), y=alt.Y("Value:Q",title="Sensor Reading"), color=alt.Color("Signal:N"), tooltip=["MINUTE_TS:T","Signal:N","Value:Q"]).properties(height=150, title="Last 60 min: Vibration & Temperature")
                    st.altair_chart(spark_chart, use_container_width=True)
 
with tab4:
    st.markdown("#### Work Order Tracker")
    wo_df = cached_query(f"SELECT wo_id, machine_id, severity, recommended_part, ROUND(est_cost_usd,2) AS est_cost_usd, loop_status, external_ticket, assigned_technician_name, assigned_technician_id FROM OEE_CC.OPS.WORK_ORDER WHERE machine_id {machine_sql} ORDER BY CASE severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, est_cost_usd DESC")
    if len(wo_df) == 0:
        st.success("No open work orders.")
    else:
        wc1, wc2, wc3 = st.columns(3)
        wc1.metric("Total Orders", len(wo_df))
        wc2.metric("HIGH Severity", len(wo_df[wo_df["SEVERITY"] == "HIGH"]))
        wc3.metric("Total Est. Cost", f"${float(wo_df['EST_COST_USD'].sum()):,.0f}")
        st.markdown("")
        pipeline_stages = ["DRAFTED", "TICKETED", "ACKNOWLEDGED", "CLOSED"]
        for _, row in wo_df.iterrows():
            sev = str(row["SEVERITY"])
            if sev == "HIGH": badge_html = '<span class="badge badge-high">HIGH</span>'
            elif sev == "MEDIUM": badge_html = '<span class="badge badge-med">MEDIUM</span>'
            else: badge_html = '<span class="badge badge-low">LOW</span>'
            status = str(row["LOOP_STATUS"])
            pipe_parts = [f'<span class="pipe-active">{stg}</span>' if stg == status else f'<span>{stg}</span>' for stg in pipeline_stages]
            pipeline_html = ' &#8594; '.join(pipe_parts)
            ticket = row["EXTERNAL_TICKET"]
            ticket_str = str(ticket) if ticket and str(ticket) != "None" else "---"
            tech_name = row["ASSIGNED_TECHNICIAN_NAME"] if row["ASSIGNED_TECHNICIAN_NAME"] else "Unassigned"
            tech_id = row["ASSIGNED_TECHNICIAN_ID"] if row["ASSIGNED_TECHNICIAN_ID"] else ""
            tech_str = f"{tech_name} ({tech_id})" if tech_id else tech_name
            st.markdown(f'**WO-{row["WO_ID"]}** | {badge_html} | **{row["MACHINE_ID"]}** | Part: `{row["RECOMMENDED_PART"]}` | Est: **${float(row["EST_COST_USD"]):,.2f}** | Ticket: `{ticket_str}` | Tech: **{tech_str}** <div class="pipeline">{pipeline_html}</div>', unsafe_allow_html=True)
            st.markdown("---")
 
with tab5:
    st.markdown("#### Technician Workload")
    workload_df = cached_query("SELECT t.technician_id, t.technician_name, t.specialization, t.skill_level, t.shift_assignment, t.is_available, COUNT(wo.wo_id) AS open_work_orders FROM OEE_CC.RAW.DIM_TECHNICIAN t LEFT JOIN OEE_CC.OPS.WORK_ORDER wo ON t.technician_id = wo.assigned_technician_id AND wo.loop_status IN ('DRAFTED','TICKETED','ACKNOWLEDGED') GROUP BY t.technician_id, t.technician_name, t.specialization, t.skill_level, t.shift_assignment, t.is_available ORDER BY open_work_orders DESC, t.technician_name")
    avail_cnt = int(workload_df["IS_AVAILABLE"].sum())
    assigned_cnt = int((workload_df["OPEN_WORK_ORDERS"] > 0).sum())
    tc1, tc2, tc3, tc4 = st.columns(4)
    tc1.metric("Total Technicians", len(workload_df))
    tc2.metric("Available Now", f"{avail_cnt}/12")
    tc3.metric("Currently Assigned", assigned_cnt)
    tc4.metric("Spare Capacity", avail_cnt - assigned_cnt)
    st.markdown("")
    st.markdown("##### Roster")
    tech_cols = st.columns(4)
    for i, row in workload_df.iterrows():
        with tech_cols[i % 4]:
            avail = row["IS_AVAILABLE"]
            wos = int(row["OPEN_WORK_ORDERS"])
            if not avail: css, status_txt = "tech-off", "OFF DUTY"
            elif wos > 0: css, status_txt = "tech-busy", f"{wos} WO ASSIGNED"
            else: css, status_txt = "tech-avail", "AVAILABLE"
            st.markdown(f'<div class="tech-card {css}"><div style="font-weight:700;">{row["TECHNICIAN_NAME"]}</div><div style="font-size:0.75rem;color:#555;">{row["TECHNICIAN_ID"]} | {row["SKILL_LEVEL"]}</div><div style="font-size:0.75rem;color:#555;">{row["SPECIALIZATION"]}</div><div style="font-size:0.75rem;color:#555;">{row["SHIFT_ASSIGNMENT"]} shift</div><div style="font-size:0.7rem;font-weight:600;margin-top:4px;">{status_txt}</div></div>', unsafe_allow_html=True)
    st.markdown("")
    st.markdown("##### Workload by Specialization")
    spec_df = workload_df.groupby("SPECIALIZATION").agg(techs=("TECHNICIAN_ID","count"), available=("IS_AVAILABLE","sum"), open_wos=("OPEN_WORK_ORDERS","sum")).reset_index()
    spec_df.columns = ["Specialization", "Techs", "Available", "Open WOs"]
    st.dataframe(spec_df, use_container_width=True, hide_index=True)
    wl_chart_df = workload_df[workload_df["OPEN_WORK_ORDERS"] > 0]
    if len(wl_chart_df) > 0:
        wl_chart = alt.Chart(wl_chart_df).mark_bar(cornerRadiusTopLeft=6, cornerRadiusTopRight=6).encode(x=alt.X("TECHNICIAN_NAME:N", title="Technician", sort="-y"), y=alt.Y("OPEN_WORK_ORDERS:Q", title="Open WOs"), color=alt.Color("SKILL_LEVEL:N", title="Level"), tooltip=["TECHNICIAN_NAME:N","SPECIALIZATION:N","OPEN_WORK_ORDERS:Q"]).properties(height=250)
        st.altair_chart(wl_chart, use_container_width=True)

with tab6:
    st.markdown("#### Ask the Factory")
    st.caption("Ask plain-English questions about OEE, downtime, and machine performance.")
    example_questions = ["Which machine had the highest downtime cost in the last 7 days?", "How many open work orders does each technician have?", "Show me OEE breakdown by machine and day", "What is the total downtime cost per machine?"]
    st.markdown("**Try an example:**")
    if "run_question" not in st.session_state:
        st.session_state["run_question"] = ""
    ex_cols = st.columns(len(example_questions))
    for i, eq in enumerate(example_questions):
        with ex_cols[i]:
            if st.button(eq, key=f"ex_{i}", use_container_width=True):
                st.session_state["run_question"] = eq
    user_question = st.text_input("Your question:", placeholder="e.g. Which machine lost the most money this week?")
    active_question = user_question or st.session_state.get("run_question", "")
    if st.session_state.get("run_question"):
        st.session_state["run_question"] = ""
    if active_question:
        st.info(f"**Question:** {active_question}")
        with st.spinner("Generating answer..."):
            try:
                escaped_q = active_question.replace("'", "''")
                gen_df = query(f"SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b', 'You are a SQL expert for manufacturing OEE data in Snowflake. Write ONLY a valid SQL query, nothing else. Tables: OEE_CC.CONVERGED.DT_OEE_DAILY (machine_id, run_date, machine_name, line_id, planned_time_min, downtime_min, units_produced, units_good, runtime_min, availability 0-1, performance 0-1, quality 0-1, oee 0-1, downtime_cost_usd), OEE_CC.CONVERGED.DT_MACHINE_HEALTH (machine_id, minute_ts, machine_name, line_id, machine_type, avg_vibration_mm_s, avg_temperature_c, avg_rpm, avg_load_pct). Multiply oee/availability/performance/quality by 100 for display. Round pct to 1 decimal, dollars to 2. Question: {escaped_q}') AS generated_sql")
                generated_sql = gen_df.iloc[0]["GENERATED_SQL"].strip()
                if generated_sql.startswith("```"):
                    generated_sql = "\n".join(generated_sql.split("\n")[1:])
                if generated_sql.endswith("```"):
                    generated_sql = generated_sql[:-3]
                generated_sql = generated_sql.strip().rstrip(";")
                st.markdown("**Generated SQL:**")
                st.code(generated_sql, language="sql")
                result_df = query(generated_sql)
                st.markdown("**Result:**")
                st.dataframe(result_df, use_container_width=True, hide_index=True)
            except Exception as e:
                st.error(f"Error: {str(e)}")
                st.info("Try rephrasing your question or use one of the examples above.")
 
st.markdown("---")
st.caption(f"OEE Command Center | Refreshed {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Powered by Snowflake Dynamic Tables, Cortex ML, Cortex LLM, Cortex Analyst & Jira MCP")
