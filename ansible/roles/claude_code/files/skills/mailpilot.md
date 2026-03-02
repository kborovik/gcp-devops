---
name: mailpilot
description: Interact with MailPilot email automation system via CLI. Use for managing accounts, contacts, missions, assignments, emails, tasks, executions, workflows, calendar events, and server operations. Troubleshoot sync issues, task failures, execution errors, and server problems. Use this skill whenever the user asks about email sync, assignment status, why something failed, server logs, calendar invitations, E2E testing, sending emails, or any pilot CLI operation.
---

# MailPilot CLI

Email automation system with Gmail integration. Mission-based workflow where LLM generates tasks from mission descriptions.

## Getting Started

Fetch the complete, up-to-date API specification before constructing commands:

```bash
pilot schema get
```

Returns all resources, methods, parameters, types, defaults, and constraints. Use this as the primary reference for command syntax.

## CLI Usage Pattern

```
pilot <resource> [--debug] <method> [--input.<param> <value>]...
```

- Output is JSONC (syntax-highlighted JSON with comments) by default
- `--debug` flag enables debug logging (must appear before the method name)
- **Boolean flags** are presence-based: `--input.<param>` for true, `--no_input.<param>` for false
- **Array parameters** use `+` suffix: `--input.<param>+ value1 --input.<param>+ value2`

## Entity Relationships

```
account (email account)
  |-- registration (inbound mission registrations for this account)
  |-- assignment (missions assigned via this account)
  |     |-- task (LLM-generated action steps)
  |     |     |-- execution (individual task execution attempts)
  |     |-- calendar event (events linked to assignment)
  |     |-- email (emails routed to assignment)
  |
mission (outbound or inbound)
  |-- assignment (linked to contact + account)
  |-- registration (inbound: linked to account)
  |
contact (person in contact database)
  |-- assignment (missions assigned to this contact)
```

- **Assignment** is the core unit: links a mission to a contact via an account
- **Task** is an LLM-generated action step within an assignment
- **Execution** is a single attempt to run a task (includes LLM reasoning)
- **Registration** maps an inbound mission to an account for routing incoming emails

## Operational Notes

Side effects and behaviors not captured in the schema:

- **`account create`**: Automatically sets up Gmail push notification watch. Reactivates soft-deleted accounts.
- **`account delete --force`**: Cascades to delete associated assignments and registrations.
- **`assignment create`**: Creates initial task execution and applies Gmail status labels.
- **`mission update`**: Creates a new version (does not overwrite previous).
- **`registration create`**: Validates mission is inbound type.
- **`dev clean`**: Irreversible cascade across 5 systems -- trashes Gmail messages, deletes DB emails, deletes calendar events, hard-deletes all assignments (including soft-deleted).
- **`workflow sync_emails`** (all accounts): Individual account errors do not stop other accounts.
- **`workflow process_emails`**: Multi-step pipeline -- LLM classification, body cleaning, mission routing.
- **`server start`** (no `--daemon`): Blocks until interrupted. With `--daemon`: returns immediately.

## Troubleshooting

### System Health Check

```bash
pilot setup validate
pilot server status
pilot account list
```

### Email Sync Issues

```bash
# 1. Check account -- look for is_disabled or stale last_sync_at
pilot account get --input.account_email <email>
# 2. Sync manually (--debug for verbose)
pilot workflow --debug sync_emails --input.account_email <email>
# 3. Verify emails arrived
pilot email list --input.account_email <email> --input.limit 10
```

If `is_disabled: true`, re-enable with `pilot account enable`. If `last_sync_at` is null, account has never synced. If sync succeeds but no emails appear, check with `--debug` for Gmail query filtering.

### Assignment Diagnostics

```bash
# 1. Assignment overview -- check assignment_status and execution count
pilot assignment get --input.assignment_id <uuid>
# 2. Tasks -- check task_status for pending/completed/cancelled
pilot task list --input.assignment_id <uuid>
# 3. Executions -- look for execution_status: failed
pilot execution list --input.assignment_id <uuid>
# 4. Full narrative report
pilot report get --input.assignment_id <uuid>
```

If `completed`, check `completion_reason` in the latest execution. If tasks show `cancelled`, the LLM decided to cancel them -- check execution reasoning. If 0 executions, tasks may still be pending (check `scheduled_at`).

### Task/Execution Failures

```bash
# 1. Check agent_decision.failure_reason and reasoning
pilot execution get --input.execution_id <uuid>
# 2. Retry failed execution (creates new execution for same task)
pilot execution retry --input.execution_id <uuid>
```

If `failure_reason` mentions a tool error, check server logs. If reasoning shows LLM misunderstood the mission, review `pilot mission get`. If `cancelled` rather than `failed`, the LLM intentionally stopped -- read `agent_decision.reasoning`.

### Understanding Execution Results

| Field                                 | Purpose                                 |
| ------------------------------------- | --------------------------------------- |
| `agent_decision.reasoning`            | LLM's explanation of actions taken      |
| `agent_decision.assignment_completed` | Whether assignment was marked complete  |
| `agent_decision.email_sent`           | Whether an email was sent               |
| `agent_decision.email_subject`        | Subject of sent email                   |
| `agent_decision.failure_reason`       | Error details if execution failed       |
| `trigger_email_id`                    | The email that triggered this execution |

### Server Logs

```bash
pilot server logs                                    # default 50 lines
pilot server logs --input.log_level error            # filter by level
pilot server logs --input.since 10m                  # filter by time
pilot server logs --input.follow                     # tail -f mode
pilot server logs --input.fields "message,log.level" # specific fields
```

**Log structure** (ECS format JSON):

| Field           | Description                                            |
| --------------- | ------------------------------------------------------ |
| `message`       | Human-readable log message                             |
| `log.level`     | debug, info, warning, error                            |
| `event_type`    | Machine-readable event classifier (best for search)    |
| `phase`         | Processing phase: sync, route, tool, execute, complete |
| `outcome`       | success or failure                                     |
| `trace_id`      | Correlation ID linking related operations              |
| `assignment_id` | Assignment UUID (when applicable)                      |
| `execution_id`  | Execution UUID (when applicable)                       |

**Key event types:**

| event_type                 | When it fires                      |
| -------------------------- | ---------------------------------- |
| `sync.complete`            | Email sync finished for an account |
| `route.complete`           | Emails classified and routed       |
| `task.execution.complete`  | A task execution finished          |
| `scheduler.batch_complete` | Batch of pending tasks completed   |
| `tool.assignment.complete` | Agent marked assignment complete   |
| `tool.calendar.create`     | Agent created a calendar event     |
| `tool.calendar.respond`    | Agent responded to invitation      |

## E2E Testing

```bash
# Clean all test data (Gmail, DB, calendar, assignments) -- irreversible
pilot dev clean --input.account_email <email>
# Poll assignment to completion and validate outcome
pilot dev poll --input.assignment_id <uuid> --input.expected_outcome objective_achieved
```
