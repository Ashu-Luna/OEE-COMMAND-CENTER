# Atlassian MCP Integration (Feature 6)

The self-healing loop uses the **official Atlassian MCP server** connected to CoCo via OAuth.
No API tokens or credentials are stored in this repo.

## Setup

1. Open CoCo Desktop -> Agent Settings -> MCP -> New
2. Server Name: `Atlassian`
3. Server Type: **Remote (HTTP)**
4. Server URL: `https://mcp.atlassian.com/v2/mcp`
5. Headers / Env Variables: none. Save.
6. A browser window opens for Atlassian OAuth login - approve it.

## Tools Used

- `createJiraIssue` - creates a Jira ticket per drafted work order
- `transitionJiraIssue` - moves tickets through the workflow (To Do -> In Progress -> Done)
- `editJiraIssue` - sets the real Jira assignee from DIM_TECHNICIAN.jira_email
- `lookupJiraAccountId` - resolves email to Jira accountId
- `getJiraIssue` - reads ticket status back

## Jira Project

- Project key: **MFG** (Manufacturing)
- Issue type: Task
- Workflow: To Do -> In Progress -> Done
- Current tickets: MFG-17 (CNC-01), MFG-18 (PRS-01), MFG-19 (CNC-02)

## Ticket Format

Summary: `[HIGH] Predicted failure on CNC-01`
Description includes: root-cause narrative, recommended part + stock location, estimated cost,
assigned technician name, skill level, contact number, and shift.
Assignee: real Jira user resolved from technician's jira_email.
