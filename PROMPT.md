# Objective

Deploy MailPilot Python application into Google Cloud Ubuntu VM.

## Context

This repo provisions GCE infrastructure (Terraform) and configures VMs (Ansible) for the Python application MailPilot.

## MailPilot Source Code

The MailPilot application source code is available at `/Users/kb/github/pilot`. Review it when you need to understand MailPilot's expected behavior, configuration, CLI commands, database schema, or service setup.

If MailPilot source code needs to be changed because it does not account for Ubuntu VM deployment, create a GitHub issue and document what needs to be changed.

## The MailPilot deployment phases

**Phase 1 — Infrastructure Provisioning** (`terraform/`):
Terraform provisions GCE instance, persistent data disk, static IP, Cloudflare DNS, VPC firewall rules, service account with IAM roles, GCS backup bucket, disk snapshot policy, and Secret Manager. Outputs `terraform/output.json` which feeds Ansible inventory.

**Phase 2 — VM Configuration** (`ansible/playbook-vm-config.yaml`):
Roles execute in order: `zfs` → `tools` → `postgresql` → `sanoid` → `google_ops`

**Phase 3 — Pilot Deployment** (`ansible/playbook-pilot-deploy.yaml`):
Role: `pilot` (requires `pilot_version`, `pilot_anthropic_api_key`, `pilot_github_token` as extra vars)

## Deployment Commands

```bash
# Infrastructure provisioning (Phase 1)
make terraform-apply

# VM configuration (Phase 2)
make ansible-vm-config

# Deploy Pilot application (Phase 3) — auto-detects latest release version
make pilot-deploy

# Check Pilot service status on remote host
make pilot-status

# Execute remote command on GCE instance (for automation/LLM agents)
make gce-exec cmd="pilot setup validate"

# SSH into GCE instance for manual inspection (interactive, humans only)
make gce-ssh
```

## Pilot CLI Reference

Use `pilot schema get` for full parameter details.

## Definition of Success

1. `make gce-exec cmd="pilot server logs"` — server logs are viewable
2. `make gce-exec cmd="pilot setup get"` — Anthropic API key is set
3. `make gce-exec cmd="pilot setup validate"` — all services must pass validation
