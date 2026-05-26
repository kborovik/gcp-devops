# Pilot Apps Deployment

Google Cloud infrastructure for Pilot Apps — Terraform, Ansible, and Make-based deployment pipeline.

## Components

- **Terraform** — GCE instances, networking, DNS, service accounts, org policies
- **Ansible** — VM configuration (OS tools, ZFS, Tailscale, Google Ops Agent)
- **Secrets** — `pass(1)` password store (GPG-backed); entries under `gcp-devops/*`

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://www.terraform.io/downloads)
- [Ansible](https://www.ansible.com/)
- [`pass(1)`](https://www.passwordstore.org/) initialized with a GPG key (store entries under `gcp-devops/*`)

## Usage

```bash
# Authenticate with Google Cloud
make google-auth

# Plan infrastructure changes (prod — default)
make terraform-plan

# Plan infrastructure changes (dev)
make terraform-plan google_project=lab5-mailpilot-dev1

# Full deployment (terraform + ansible); prod requires `confirm=prd1`
make deploy confirm=prd1
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
gcloud compute snapshots list --project=lab5-mailpilot-prd1 \
  --filter="sourceDisk:mailpilot-1-pgsql" --sort-by=~creationTimestamp

# Create a new disk from snapshot
gcloud compute disks create mailpilot-1-pgsql \
  --project=lab5-mailpilot-prd1 \
  --zone=us-east5-b \
  --source-snapshot=<SNAPSHOT_NAME> \
  --type=pd-balanced

# Re-run Terraform and Ansible to rebuild the instance with the restored disk
make terraform-apply
make gce-configure
```

### Verifying Backups

```bash
# List ZFS snapshots and verify Sanoid is running
sudo zfs list -t snapshot -r data/postgresql
systemctl status sanoid.timer

# GCE disk snapshots (from local machine)
gcloud compute snapshots list --project=lab5-mailpilot-prd1 \
  --filter="sourceDisk:mailpilot-1-pgsql"
```

### Restore Smoke-Test Cadence

Run a full ZFS rollback restore drill on **dev** (`lab5-mailpilot-dev1`) at least once per quarter. Untested backups are unreliable backups — a quarterly drill confirms the snapshot pipeline still produces a recoverable PostgreSQL state end-to-end.

Procedure:

1. Connect: `make gce-ssh google_project=lab5-mailpilot-dev1`
2. Pick a recent non-critical snapshot from `sudo zfs list -t snapshot -r data/postgresql`
3. Walk **Scenario 1** above (stop PostgreSQL → `zfs rollback` → start PostgreSQL)
4. Confirm the service comes back healthy and recent rows are visible

Record the drill date and outcome in the team runbook. If two quarters pass without a successful drill, treat the backup chain as unverified and escalate before relying on it.

## tmux on GCE Hosts

The `tools` Ansible role installs `tmux` and drops a baseline `~/.tmux.conf` on the `ubuntu` user (`ansible/roles/tools/files/tmux/tmux.conf`). The config targets the iTerm2 → SSH → tmux → Claude Code path on Ubuntu 24.04 (tmux 3.4).

### iTerm2 client setup

The `set-clipboard on` directive uses OSC 52 to push tmux copy-mode selections to the macOS pasteboard through iTerm2. Enable the matching iTerm2 permission once per workstation:

**iTerm2 → Preferences → General → Selection → "Applications in terminal may access clipboard"**

Without this toggle, `prefix [` then `y` in tmux will not reach the macOS clipboard.

### Applying config changes

After `make gce-configure` updates `~/.tmux.conf`:

- `default-terminal "tmux-256color"` only takes effect on a fresh tmux server. Run `tmux kill-server` and reattach to pick it up.
- All other settings (`set-clipboard`, `mouse`, `history-limit`, etc.) apply live via `tmux source-file ~/.tmux.conf` in any attached session.

### Authoring gotchas

When editing `roles/tools/files/tmux/tmux.conf`:

- Do **not** remap `C-c` or `C-d` — Claude Code uses them to interrupt the agent and exit the session.
- Do **not** enable `remain-on-exit` globally — it leaves zombie panes when `/exit` runs.
- Keep the default `C-b` prefix. Remapping to `C-a` collides with readline `beginning-of-line` in Claude Code's input box.
- tmux 3.4 (the Ubuntu 24.04 apt version) ships with all directives the baseline uses — no version-gating needed.
