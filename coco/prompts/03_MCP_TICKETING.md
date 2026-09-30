# MCP Ticketing (Feature 6)

Feature 6 uses the **official Atlassian MCP server** connected to CoCo via OAuth — no custom
code or credentials in this repo.

Full setup and the loop-close prompt are documented in **[`../mcp/README.md`](../mcp/README.md)**.

Quick summary:
- Add MCP connector: Remote (HTTP), URL `https://mcp.atlassian.com/v2/mcp`.
- Authenticate in the browser (OAuth).
- CoCo uses the `createJiraIssue` tool to auto-create real Jira tickets from work orders.
