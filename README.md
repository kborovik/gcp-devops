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

## Backup Architecture

PostgreSQL data is protected by four complementary backup layers:

| Layer         | Method                          | Schedule        | Retention     | Storage       |
| ------------- | ------------------------------- | --------------- | ------------- | ------------- |
| WAL Archive   | pgBackRest continuous archiving | Real-time       | 30 days       | GCS bucket    |
| Diff Backup   | pgBackRest differential         | Daily 19:30     | 7 versions    | GCS bucket    |
| Full Backup   | pgBackRest full                 | Sunday 19:00    | 2 versions    | GCS bucket    |
| ZFS Snapshot  | Sanoid auto-snapshot            | Hourly          | 12h / 7d / 4w | Local disk    |
| Disk Snapshot | GCE persistent disk snapshot    | Daily 02:00 UTC | 14 days       | GCP snapshots |

### pgBackRest (offsite, GCS)

pgBackRest backs up PostgreSQL to the GCS bucket `backups-<google_project>` under the `/pgbackrest` prefix. Backups use Zstandard compression (level 3). WAL segments are archived continuously via `archive_command`, enabling point-in-time recovery (PITR) to any moment within the 30-day GCS lifecycle window.

- **Stanza:** `main`
- **Config:** `/etc/pgbackrest/pgbackrest.conf`
- **Timers:** `pgbackrest-full.timer`, `pgbackrest-backup.timer`

### Sanoid ZFS Snapshots (local, on-disk)

Sanoid manages automatic ZFS snapshots for both the data and WAL datasets:

- `data/postgresql/data` — PostgreSQL data files (recordsize=8K)
- `data/postgresql/wal` — WAL files (recordsize=128K)

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

# Roll back both datasets (use matching snapshot timestamps)
sudo zfs rollback -r data/postgresql/data@autosnap_2026-02-16_12:00:00_hourly
sudo zfs rollback -r data/postgresql/wal@autosnap_2026-02-16_12:00:00_hourly

# Start PostgreSQL
sudo systemctl start postgresql
```

To recover individual files without a full rollback, access the `.zfs/snapshot` directory:

```bash
# Browse snapshot contents (no mount needed)
ls /var/lib/postgresql/18/main/.zfs/snapshot/
sudo cp /var/lib/postgresql/18/main/.zfs/snapshot/autosnap_2026-02-16_12:00:00_hourly/path/to/file /tmp/
```

### Scenario 2: Point-in-time recovery (pgBackRest PITR)

Best for: recovering to an exact moment in time, e.g. just before a bad migration.

```bash
# Check available backups and WAL archive status
sudo -u postgres pgbackrest --stanza=main info

# Stop PostgreSQL
sudo systemctl stop postgresql

# Clear the existing data directory
sudo -u postgres find /var/lib/postgresql/18/main -mindepth 1 -delete
sudo -u postgres find /var/lib/postgresql/18/wal -mindepth 1 -delete

# Restore to a specific point in time
sudo -u postgres pgbackrest --stanza=main \
  --type=time "--target=2026-02-16 15:30:00" \
  --target-action=promote \
  restore

# Start PostgreSQL (it will replay WAL up to the target time)
sudo systemctl start postgresql

# Verify recovery
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
# Should return 'f' (false) after promotion
```

### Scenario 3: Full restore from latest backup (pgBackRest)

Best for: complete data loss or corrupted cluster.

```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Clear the existing data directory
sudo -u postgres find /var/lib/postgresql/18/main -mindepth 1 -delete
sudo -u postgres find /var/lib/postgresql/18/wal -mindepth 1 -delete

# Restore latest backup and replay all archived WAL
sudo -u postgres pgbackrest --stanza=main \
  --type=default \
  --target-action=promote \
  restore

# Start PostgreSQL
sudo systemctl start postgresql
```

### Scenario 4: Restore from GCE disk snapshot

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
# pgBackRest backup status and WAL archive continuity
sudo -u postgres pgbackrest --stanza=main info

# List ZFS snapshots and verify Sanoid is running
sudo zfs list -t snapshot -r data/postgresql
systemctl status sanoid.timer

# pgBackRest backup timers
systemctl status pgbackrest-full.timer pgbackrest-backup.timer

# GCE disk snapshots (from local machine)
gcloud compute snapshots list --project=mailpilot-pilot-dev1 \
  --filter="sourceDisk:mailpilot-1-pgsql"
```
