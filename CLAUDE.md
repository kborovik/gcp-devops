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
├── playbook-vm-config.yaml   Main playbook
├── inventory/                Auto-generated from Terraform output
└── roles/                    zfs → tools → postgresql → google_ops
secrets/            GPG-encrypted credentials (ssh.key, CLOUDFLARE_API_TOKEN)
```

## Prerequisites

- gcloud CLI (authenticated: `make google-auth`)
- Terraform >= 1.0, < 2.0
- Ansible
- GPG key matching `secrets/.gpg_id` for decrypting secrets

## Verification

- **After changing Terraform files:** run `make terraform-apply` to apply and verify changes succeed
- **After changing Ansible files:** run `make ansible` to apply and verify changes succeed

## Terraform

- Run `make terraform-plan` to validate and plan changes
- Run `make terraform-apply` to apply changes
- Target production with `google_project=mailpilot-org-prd1` (e.g. `make terraform-plan google_project=mailpilot-org-prd1`)
- Default target: `mailpilot-pilot-dev1` (us-east5)
- State stored in GCS bucket `terraform-<google_project>`

## Ansible

- Roles run in order: zfs → tools → postgresql → google_ops
- Inventory is auto-generated from `terraform/output.json` via `make ansible-inventory`
- SSH key at `secrets/ssh.key` (decrypted on-the-fly from `.gpg`)

## Operations

- `make gce-ssh` — SSH into the GCE instance
- `make gce-status` — List GCE instances
- `make gce-start` / `make gce-stop` — Start/stop instances
- `make mailpilot-pilot-dev1` — Full deploy (terraform-apply + ansible) for dev

## Secrets

- Managed via `secrets/makefile` — `make -C secrets decrypt` / `encrypt` / `clean`
- GPG recipient ID in `secrets/.gpg_id`
- `CLOUDFLARE_API_TOKEN` is decrypted at Terraform runtime from GPG

## Gotchas

- Ansible inventory is generated from Terraform output — run `make terraform-apply` before `make ansible` on first setup
- GCE instances have auto-stop schedules (20:00 ET daily); dev has stop-only, prod has start+stop
- The `google_project` variable defaults to `mailpilot-pilot-dev1` — always pass it explicitly for prod
