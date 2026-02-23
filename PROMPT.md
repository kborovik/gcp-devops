# Objective

- Update Ansible role 'pilot' by move entire '/home/ubuntu' home folder to zfs filesystem.
- Configure ZFS snapshot backup (Sanoid) for `/home/ubuntu` dataset.
- Deploy MailPilot Python application into Google Cloud Ubuntu VM.

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

### Objective 1 — Move `/home/ubuntu` to ZFS

1. `make gce-exec cmd="zfs list data/home"` — `/home/ubuntu` is a ZFS dataset
2. `make gce-exec cmd="stat -f -c %T /home/ubuntu"` — home folder is on ZFS filesystem
3. `make gce-exec cmd="ls -la /home/ubuntu/.config/fish/"` — user config files are on ZFS
4. `make gce-exec cmd="ls -la /home/ubuntu/.local/bin/uv"` — user local binaries are on ZFS

### Objective 2 — Configure ZFS snapshot backup for `/home/ubuntu`

1. `make gce-exec cmd="cat /etc/sanoid/sanoid.conf"` — `data/home` dataset has Sanoid snapshot policy
2. `make gce-exec cmd="systemctl is-active sanoid.timer"` — Sanoid timer is active
3. `make gce-exec cmd="sanoid --cron --verbose"` — snapshot creation succeeds
4. `make gce-exec cmd="zfs list -t snapshot -r data/home"` — snapshots exist for home dataset

### Objective 3 — Deploy MailPilot application

1. `make gce-exec cmd="pilot setup get"` — Anthropic API key is set
2. `make gce-exec cmd="pilot setup validate"` — all services must pass validation
3. `make gce-exec cmd="pilot server logs"` — server logs are viewable
