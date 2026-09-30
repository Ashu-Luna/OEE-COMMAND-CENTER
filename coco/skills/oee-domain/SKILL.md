---
name: oee-domain
description: Manufacturing OEE and downtime-cost rules for the Predictive Maintenance Command Center. Use whenever computing OEE, availability, performance, quality, or downtime cost.
---

# OEE & Downtime Cost Domain Rules

Apply these formulas exactly whenever you build OEE or cost logic for this project.

## OEE = Availability × Performance × Quality

- **Availability** = (planned_time_min − downtime_min) / planned_time_min
- **Performance** = (ideal_cycle_sec × units_produced / 60) / (planned_time_min − downtime_min)
- **Quality** = units_good / units_produced
- **OEE** = Availability × Performance × Quality

Always guard divisions with NULLIF(denominator, 0). World-class OEE ≈ 85%.

## Downtime Cost (the differentiator — speak in dollars)

DOWNTIME_COST_USD = downtime_min × (units_produced / (planned_time_min − downtime_min)) × unit_margin_usd

Interpretation: lost production minutes × units-per-minute throughput × profit margin per unit.
Always surface this in dollars, not just percentages — a CFO cares about $/hour lost, not OEE points.

## Severity from anomaly deviation

- deviation > 2.5 → HIGH
- deviation > 1.0 → MEDIUM
- otherwise → LOW

## Failure modes and recommended parts

- BEARING → part BRG-204 (Spindle Bearing)
- SPINDLE → part BRG-204
- OVERHEAT → part MTR-110 (Servo Motor)

## Conventions

- Database OEE_CC; schemas RAW (source), CONVERGED (dynamic tables), ML (Cortex), OPS (work orders), APP.
- Warehouse OEE_WH, XSMALL, auto-suspend 60s — keep costs low on the trial account.
- Prefer dynamic tables for convergence; use TARGET_LAG of 1–5 minutes for the demo.
