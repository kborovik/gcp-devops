# MailPilot Pilot

Google Cloud infrastructure for MailPilot — Terraform, Ansible, and Make-based deployment pipeline.

## Components

- **Terraform** — GCE instances, networking, DNS, service accounts, org policies
- **Ansible** — VM configuration (OS tools, ZFS, Tailscale, Google Ops Agent)
- **Secrets** — GPG-encrypted credentials with pass-style management

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://www.terraform.io/downloads)
- [Ansible](https://www.ansible.com/)
- GPG key for secrets decryption

## Usage

```bash
# Authenticate with Google Cloud
make google-auth

# Plan infrastructure changes (dev)
make terraform-plan

# Plan infrastructure changes (prod)
make terraform-plan google_project=mailpilot-org-prd1

# Full deployment (terraform + ansible)
make mailpilot-pilot-dev1
```
