# SPEC.md

## §G

Provision ∧ configure GCP infra ∀ Pilot Apps. Terraform → infra (GCE, DNS, IAM, network). Ansible → VM cfg (ZFS, Postgres, Tailscale, ops agent). GPG → secrets. `make` ≡ sole driver.

## §C

- gcloud CLI ! authenticated (`make google-auth`)
- Terraform ≥ 1.0 ∧ < 2.0
- ansible-core ! pinned via uv venv (`pyproject.toml` ∧ `ansible/requirements.yml`)
- GPG key matching `secrets/.gpg_id` ! present
- TF state ∈ GCS bucket `terraform-<google_project>` (per-project)
- Postgres 18, `wal_level=minimal`, `max_wal_senders=0` → ⊥ streaming replication

## §I

|kind|name|shape|
|cmd|`make terraform-plan`|plan vs `config/<p>/terraform.tfvars`|
|cmd|`make terraform-apply`|apply ∧ refresh `terraform-output.json`|
|cmd|`make gce-configure`|run `playbook-vm-config.yaml`|
|cmd|`make leadpilot-deploy [leadpilot_version=<v>]`|run `playbook-leadpilot-deploy.yaml`|
|cmd|`make mailpilot-deploy [mailpilot_version=<v>]`|run `playbook-mailpilot-deploy.yaml`|
|cmd|`make deploy`|plan-check → bail on drift, else gce-configure + leadpilot-deploy + mailpilot-deploy|
|cmd|`make verify`|audit §V1 (secrets ⊥ plaintext) ∧ §V2 (inventory drift) ∧ §V6 (per-project files)|
|cmd|`make gce-{ssh,status,start,stop}` ∨ `make gce-exec cmd=…`|VM ops|
|env|`google_project`|default `lab5-mailpilot-prd1`|
|file|`config/<p>/terraform.tfvars`|TF vars per project|
|file|`config/<p>/terraform-output.json`|TF output → ansible inventory source|
|file|`config/<p>/ansible/inventory/group_vars/all.yaml`|optional per-project ansible overrides (slot; absence ⊥ drift)|
|file|`secrets/*.gpg`|GPG-encrypted; `secrets/.gpg_id` ≡ recipient|

## §V

- V1: ∀ secret ∈ `secrets/` → GPG-encrypted (`.gpg`); ⊥ plaintext committed
- V2: ansible inventory ! regenerated from `terraform-output.json` via `make ansible-inventory` — ⊥ hand-edit
- V3: ansible YAML strings ! single-quote — double-quote OK ∀ {`\n`/`\t`, embedded `'`}; embedded `'` ∈ single-quoted → `''`
- V4: VM cfg playbook role order ≡ zfs → tools → github_cli → gpg → tailscale → postgresql → sanoid → google_ops
- V5: `make deploy` ! plan-check before apply → exit 1 ∧ surface plan if pending TF changes
- V6: per-project cfg ∈ `config/<p>/` only — ⊥ ∈ `terraform/` ∨ `ansible/`
- V7: default `google_project` ≡ `lab5-mailpilot-prd1` (prod) → dev work ! pass `google_project=lab5-mailpilot-dev1` explicitly; DEV1 currently dormant (cost-suppressed; ~99% testing ∈ upstream app repos) — reactivate when data volume outgrows app-repo dev loops
- V8: prod deploy (`google_project ≡ lab5-mailpilot-prd1`) ! gated — `*-deploy` ∧ `deploy` targets ⊥ invoke ansible-playbook against prd unless explicit `confirm=prd1` ∨ interactive `yes`-typed confirm (literal "yes", ⊥ y/N); ∴ misconfig (incl. `make -n` under `.ONESHELL`, typo'd target, copy-paste shell history) ⊥ mutate prod
- V9: ∀ multi-line recipe under `.ONESHELL:` → fail-fast required (`set -e` ∨ global `SHELL := bash` ∧ `.SHELLFLAGS := -ec`); mid-recipe cmd failure ⊥ swallowed by trailing cleanup ∴ `make <target>` exit ≡ first-failure exit, ⊥ last-cmd exit
- V10: ∀ private-repo install via `uv tool install git+https://...` ∈ ansible role → auth ! threaded via in-URL form (`https://x-access-token:${TOKEN}@github.com/...`) ∨ git credential helper; env-only (`UV_GIT_TOKEN`) ⊥ sufficient — version- ∨ format-drift on remote silently breaks private-repo upgrade

## §T

|id|status|task|cites
|T1|x|add `make verify` → audits V1 (grep plaintext secrets), V2 (inventory drift vs `terraform-output.json`), V6 (no per-project files outside `config/`)|V1,V2,V6
|T2|x|document ZFS rollback restore-test cadence (smoke-test ≥ 1×/quarter on dev) ∈ README §Recovery|V?,I.cmd
|T3|x|add mailpilot deploy mirror — ansible role `mailpilot/`, `playbook-mailpilot-deploy.yaml`, Makefile `mailpilot-deploy` ∧ `mailpilot-status` targets, GitHub release fetch via `GITHUB_TOKEN`|V1,I.cmd
|T4|x|gate prod deploy — `*-deploy` ∧ `deploy` targets refuse to invoke ansible-playbook when `google_project=lab5-mailpilot-prd1` unless `confirm=prd1` set ∨ interactive y/N answered|V8
|T5|x|enforce V9 — set `SHELL := bash` ∧ `.SHELLFLAGS := -ec` ∈ Makefile head; verify ∀ multi-line recipe (`leadpilot-deploy`, `mailpilot-deploy`, `gce-configure`) propagates non-zero exit on mid-recipe failure|V9
|T6|.|patch `ansible/roles/leadpilot/tasks/main.yaml` — replace `UV_GIT_TOKEN` env w/ in-URL creds (`git+https://x-access-token:{{ leadpilot_github_token }}@github.com/kborovik/leadpilot@v{{ leadpilot_version }}`); re-run leadpilot-deploy → install task transitions `failed` → `ok` (changed only on actual upgrade)|V10,I.cmd

## §B

|id|date|cause|fix
|B1|2026-05-07|`make -n` under `.ONESHELL:` executed deploy recipe → mailpilot playbook ran on `mailpilot-prd1.lab5.ca` (db ∧ tool installed) when intended as dry-run preflight|V8
|B2|2026-05-07|`make leadpilot-deploy` exit 0 despite ansible task FAILED (private-repo `uv tool install` auth) — `.ONESHELL:` recipe @ Makefile:187-206 ⊥ `set -e` ∴ playbook nonzero ⊥ abort; trailing `make -C secrets clean` overrode exit code → `make deploy` masked failure ∧ continued to mailpilot-deploy|V9
|B3|2026-05-07|`uv tool install git+https://github.com/kborovik/leadpilot@vX` on remote GCE (uv 0.11.0) failed w/ `Password authentication is not supported` despite `UV_GIT_TOKEN` env set ∧ `leadpilot_github_token` correctly threaded from Makefile `--extra-vars`; role @ `ansible/roles/leadpilot/tasks/main.yaml:19-20` ⊥ embed creds ∈ URL → git invocation under uv lacks usable cred path. mailpilot ⊥ affected (public repo)|V10
