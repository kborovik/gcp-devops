# Objective

Test and develop all Ansible roles to achieve a running Pilot server on the GCE instance. The definition of success is `pilot server status` returning `running: true` on the remote host.

## Context

This repo provisions GCE infrastructure (Terraform) and configures VMs (Ansible). The Ansible roles run in two phases:

**Phase 1 — VM Configuration** (`ansible/playbook-vm-config.yaml`):
Roles execute in order: `zfs` → `tools` → `postgresql` → `sanoid` → `google_ops`

**Phase 2 — Pilot Deployment** (`ansible/playbook-pilot-deploy.yaml`):
Role: `pilot` (requires `pilot_version`, `pilot_anthropic_api_key`, `pilot_github_token` as extra vars)

## Deployment Commands

```bash
# Full VM configuration (Phase 1)
make ansible-vm-config

# Deploy Pilot application (Phase 2) — auto-detects latest release version
make pilot-deploy

# Full deploy (both phases)
make mailpilot-pilot-dev1

# Check Pilot service status on remote host
make pilot-status

# SSH into GCE instance for manual inspection
make gce-ssh
```

## Role Summary

| Role         | Purpose                                                                                            | Key Artifacts                                                      |
| ------------ | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `zfs`        | Creates `data` zpool on `/dev/sdb`, datasets for PG data (8K recordsize) and WAL (128K recordsize) | `/var/lib/postgresql/18/main`, `/var/lib/postgresql/18/wal`        |
| `tools`      | Installs: acl, fish, git, jq, make, gnupg                                                          | —                                                                  |
| `postgresql` | Installs PostgreSQL 18 from PGDG repo, configures WAL archiving, deploys pgBackRest backup timers  | Config: `/etc/postgresql/18/main/`, pgBackRest: `/etc/pgbackrest/` |
| `sanoid`     | ZFS snapshot automation (12h/7d/4w retention)                                                      | `/etc/sanoid/sanoid.conf`                                          |
| `google_ops` | Google Cloud Ops Agent for monitoring/logging                                                      | —                                                                  |
| `pilot`      | Deploys Pilot Python app from GitHub releases via `uv`, systemd service, DB schema init            | `/home/ubuntu/pilot/current/`, systemd: `pilot.service`            |

## Pilot CLI Reference

The `pilot` binary supports these resources (run on remote host):

- `pilot server start|stop|status|restart|logs|killall` — Server lifecycle
- `pilot setup init|validate|get|set` — Configuration and DB schema
- `pilot account list|create|get|enable|disable|update` — Email accounts
- `pilot mission list|create|get|update|delete|enable|disable|template` — Missions
- `pilot assignment list|create|get|cancel|delete` — Mission assignments
- `pilot contact list|create|get|update|delete|search|import_csv` — Contacts
- `pilot email list|get` — Email management
- `pilot execution list|get|cancel|retry` — Task executions
- `pilot task list|get` — Assignment tasks
- `pilot calendar create|list|get|update|delete|list_pending|respond` — Calendar events
- `pilot registration create|list|get|delete` — Inbound mission registrations
- `pilot workflow sync_emails|process_emails|execute_tasks` — Batch processing
- `pilot report get` — Assignment reports
- `pilot dev clean|poll` — Dev/test utilities

Use `pilot schema get` for full parameter details.

## Workflow

1. Ensure the GCE instance is running: `make gce-status` (start with `make gce-start` if stopped)
2. Run Phase 1 — `make ansible-vm-config` — fix any role failures before proceeding
3. Run Phase 2 — `make pilot-deploy` — fix any deployment failures
4. Verify success — `make pilot-status` — confirm pilot service is active and running
5. If all checks pass, output `LOOP_COMPLETE`

### Re-creating the VM from scratch

If the VM is in a broken state and needs a clean start, destroy and re-provision it:

```bash
# 1. Delete the GCE instance
make gce-delete

# 2. Re-provision infrastructure (creates new VM, disk, networking)
make terraform-apply

# 3. Run full deploy (VM config + Pilot)
make mailpilot-pilot-dev1
```

This gives you a fresh Ubuntu VM with an empty data disk — all Ansible roles will run from scratch.

## Troubleshooting

- SSH into the instance with `make gce-ssh` to inspect logs, services, and filesystem state
- Run ansible with `-vvv` for verbose output when debugging role failures
- Check `pilot server logs` on the remote host for application-level errors
- PostgreSQL logs: `journalctl -u postgresql`
- Pilot service logs: `journalctl -u pilot`
- Verify ZFS pools: `zpool status`, `zfs list`

## Rules

- Do NOT modify Terraform files — use `make gce-delete` and `make terraform-apply` to re-create the VM if needed
- Do NOT modify secrets — GPG-encrypted credentials are pre-configured
- Focus changes on `ansible/roles/` and `ansible/playbook-*.yaml` files
- Test each role incrementally — fix failures before moving to the next role
- Always verify the final state with `make pilot-status` before declaring success
