# Pilot Applications Deployment

Google Cloud infrastructure for Pilot Applications — Terraform, Ansible, and Make-based deployment pipeline.

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

## Backup Architecture

PostgreSQL data is protected by two complementary backup layers:

| Layer         | Method                       | Schedule        | Retention     | Storage       |
| ------------- | ---------------------------- | --------------- | ------------- | ------------- |
| ZFS Snapshot  | Sanoid auto-snapshot         | Hourly          | 12h / 7d / 4w | Local disk    |
| Disk Snapshot | GCE persistent disk snapshot | Daily 02:00 UTC | 14 days       | GCP snapshots |

### Sanoid ZFS Snapshots (local, on-disk)

Sanoid manages automatic ZFS snapshots for the PostgreSQL data dataset:

- `data/postgresql/data` — PostgreSQL data files (recordsize=8K)

Retention: 12 hourly, 7 daily, 4 weekly. Managed by `sanoid.timer`.

### GCE Persistent Disk Snapshots (infrastructure-level)

The `mailpilot-1-pgsql` data disk has a GCE snapshot policy (`data-disk-daily-snapshots`) that takes a daily snapshot at 02:00 UTC, retained for 14 days. Snapshots persist even if the disk is deleted.

## Recovery Procedures

All recovery commands run on the GCE instance. Connect with `make gce-ssh`.

### Scenario 1: Recover recent changes (ZFS rollback)

Best for: accidental data loss within the last few hours/days. Fastest recovery method.

```bash
# List available snapshots
sudo zfs list -t snapshot -r data/postgresql

# Stop PostgreSQL
sudo systemctl stop postgresql

# Roll back the data dataset
sudo zfs rollback -r data/postgresql/data@autosnap_2026-02-16_12:00:00_hourly

# Start PostgreSQL
sudo systemctl start postgresql
```

To recover individual files without a full rollback, access the `.zfs/snapshot` directory:

```bash
# Browse snapshot contents (no mount needed)
ls /var/lib/postgresql/18/main/.zfs/snapshot/
sudo cp /var/lib/postgresql/18/main/.zfs/snapshot/autosnap_2026-02-16_12:00:00_hourly/path/to/file /tmp/
```

### Scenario 2: Restore from GCE disk snapshot

Best for: disk failure or full infrastructure rebuild.

```bash
# From your local machine — list available snapshots
gcloud compute snapshots list --project=mailpilot-pilot-dev1 \
  --filter="sourceDisk:mailpilot-1-pgsql" --sort-by=~creationTimestamp

# Create a new disk from snapshot
gcloud compute disks create mailpilot-1-pgsql \
  --project=mailpilot-pilot-dev1 \
  --zone=us-east5-b \
  --source-snapshot=<SNAPSHOT_NAME> \
  --type=pd-balanced

# Re-run Terraform and Ansible to rebuild the instance with the restored disk
make terraform-apply
make ansible
```

### Verifying Backups

```bash
# List ZFS snapshots and verify Sanoid is running
sudo zfs list -t snapshot -r data/postgresql
systemctl status sanoid.timer

# GCE disk snapshots (from local machine)
gcloud compute snapshots list --project=mailpilot-pilot-dev1 \
  --filter="sourceDisk:mailpilot-1-pgsql"
```
