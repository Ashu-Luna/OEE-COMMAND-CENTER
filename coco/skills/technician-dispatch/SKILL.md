---
name: technician-dispatch
description: Rules for auto-assigning the best available technician to a work order based on machine failure type, severity, availability, and shift. Use when drafting or assigning work orders and Jira tickets.
---

# Smart Technician Dispatch Rules

When a work order is created for a failing machine, assign the most suitable technician from
OEE_CC.RAW.DIM_TECHNICIAN using these rules, in priority order.

## 1. Specialization must match the machine type

Map the failing machine's type (from DIM_MACHINE.machine_type) to the required specialization:

| Machine type | Required SPECIALIZATION |
|--------------|-------------------------|
| CNC          | CNC_MACHINES            |
| PRESS        | HYDRAULICS              |
| ROBOT        | ROBOTICS                |
| (electrical fault) | ELECTRICAL        |
| (welding)    | WELDING_SYSTEMS         |
| (unknown)    | GENERAL (fallback)      |

If no specialist is available, fall back to a GENERAL technician.

## 2. Availability

Only assign technicians where IS_AVAILABLE = TRUE.

## 3. Skill level by severity

- HIGH severity  -> prefer SKILL_LEVEL = SENIOR
- MEDIUM/LOW     -> JUNIOR is acceptable; use SENIOR only if no junior is free

## 4. Shift (tie-breaker)

Prefer a technician whose SHIFT_ASSIGNMENT covers the time the failure/anomaly occurred.
If unknown, ignore shift.

## 5. Load balancing (final tie-breaker)

If several technicians still qualify, pick the one with the FEWEST currently open work orders
(loop_status in DRAFTED, TICKETED, ACKNOWLEDGED) so work spreads evenly.

## Output

Write the chosen technician onto the work order: assigned_technician_id and
assigned_technician_name.

### Jira assignment (real, not just description)
If the technician has a JIRA_EMAIL in DIM_TECHNICIAN:
1. Look up the Jira accountId for that email (Atlassian tool: lookupJiraAccountId / user search).
2. Set that accountId as the REAL assignee on the Jira issue (assignJiraIssue), so the ticket is
   actually assigned to that user on the board.
3. Also include the technician name + contact in the description as a fallback.
If the technician has NO JIRA_EMAIL, just put the name + contact in the description (no assignee).
If no technician can be found, set assigned_technician_id = NULL and flag as UNASSIGNED.

## Good example

CNC-01, HIGH severity, spindle bearing failure, Shift A window:
-> CNC_MACHINES + SENIOR + available + Shift A = Rajesh Kumar (TECH-001).
Ticket description ends with: "Assigned to: Rajesh Kumar (Senior, CNC_MACHINES, Shift A)."
