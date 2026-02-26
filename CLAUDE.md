# CLAUDE.md

## Overview

Google Cloud infrastructure for MailPilot. Terraform provisions GCE instances, networking, DNS (Cloudflare), and service accounts. Ansible configures VMs (ZFS, PostgreSQL, Google Ops Agent, tools). Secrets are GPG-encrypted.

## Architecture

```
terraform/          Terraform configs (GCS backend per project)
├── *.tf            Resource definitions
├── *.tfvars        Per-environment variables
└── output.json     Terraform output (feeds Ansible inventory)
ansible/
├── playbook-vm-config.yaml   VM infrastructure config
├── playbook-pilot-deploy.yaml Pilot app deployment
├── inventory/                Auto-generated from Terraform output
└── roles/                    zfs → tools → github_cli → postgresql → sanoid → google_ops → claude_code
secrets/            GPG-encrypted credentials (ssh.key, CLOUDFLARE_API_TOKEN)
```

## Prerequisites

- gcloud CLI (authenticated: `make google-auth`)
- Terraform >= 1.0, < 2.0
- Ansible
- GPG key matching `secrets/.gpg_id` for decrypting secrets

## Verification

- **After changing Terraform files:** run `make terraform-apply` to apply and verify changes succeed
- **After changing Ansible VM config roles:** run `make pilot-configure` to apply and verify changes succeed
- **After changing Pilot deployment role:** run `make pilot-deploy` to apply and verify changes succeed

## Terraform

- Run `make terraform-plan` to validate and plan changes
- Run `make terraform-apply` to apply changes
- Target production with `google_project=mailpilot-pilot-prd1` (e.g. `make terraform-plan google_project=mailpilot-pilot-prd1`)
- Default target: `mailpilot-pilot-dev1` (us-east5)
- State stored in GCS bucket `terraform-<google_project>`

## Ansible

- **YAML strings:** Always use single quotes. Never use double quotes unless the value requires YAML escape sequences (`\n`, `\t`). Escape embedded single quotes by doubling them (`''`). Leave shell commands with embedded double quotes as unquoted YAML strings.
- VM config roles run in order: zfs → tools → github_cli → postgresql → sanoid → google_ops → claude_code
- Pilot app deployed separately via `make pilot-deploy` (uses `playbook-pilot-deploy.yaml`)
- Inventory is auto-generated from `terraform/output.json` via `make ansible-inventory`
- SSH key at `secrets/ssh.key` (decrypted on-the-fly from `.gpg`)

## Operations

- `make gce-ssh` — SSH into the GCE instance
- `make gce-status` — List GCE instances
- `make gce-start` / `make gce-stop` — Start/stop instances
- `make gce-exec cmd="..."` — Run remote command on GCE instance
- `make mailpilot-pilot-dev1` — Full deploy (terraform-apply + pilot-configure + pilot-deploy) for dev
- `make pilot-configure` — Run VM infrastructure playbook
- `make pilot-deploy` — Deploy Pilot app (auto-detects latest release, or `pilot_version=X.Y.Z`)
- `make pilot-rollback` — Rollback Pilot to previous release
- `make pilot-status` — Check Pilot service status

## Secrets

- Claude Code: use `gpg -d secrets/<file>.gpg` to decrypt, `gpg -e -r $(cat secrets/.gpg_id) -o secrets/<file>.gpg secrets/<file>` to encrypt
- Humans: `make -C secrets decrypt` / `encrypt` / `clean`
- GPG recipient ID in `secrets/.gpg_id`
- `CLOUDFLARE_API_TOKEN` is decrypted at Terraform runtime from GPG

## Gotchas

- Ansible inventory is generated from Terraform output — run `make terraform-apply` before `make ansible` on first setup
- GCE instances have auto-stop schedules (20:00 ET daily); dev has stop-only, prod has start+stop
- The `google_project` variable defaults to `mailpilot-pilot-dev1` — always pass it explicitly for prod (`mailpilot-pilot-prd1`)
- Backups: ZFS snapshots via Sanoid (hourly/daily/weekly, local) + GCE disk snapshots (daily, 14-day retention)
- PostgreSQL 18 with `wal_level=minimal` and `max_wal_senders=0` — no streaming replication
