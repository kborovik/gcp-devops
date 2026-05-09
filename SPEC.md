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
- V11: mailpilot ≡ systemd service (∴ ⊥ cron) — `mailpilot.service` Type=simple, ExecStart=`mailpilot run`, User=ubuntu, Restart=on-failure (RestartSec=5), After=postgresql.service ∧ network-online.target, WantedBy=multi-user.target; deploy ⇒ daemon-reload + enable + restart on unit ∨ config change. Why: mailpilot ≡ daemon-shaped per upstream §V.3 (wakeup_event-driven, run_interval ≡ upper-bound fallback); cron model ⊥ accommodates Pub/Sub push wakeups ∧ ⊥ leadpilot batch shape
- V12: mailpilot DB bootstrap — postgres role `ubuntu` (LOGIN CREATEDB) ∧ database `mailpilot` (owner ubuntu, public schema owner ubuntu) provisioned by `roles/mailpilot`; schema init via `mailpilot status` pre-systemd-start. Runtime config (`~ubuntu/.mailpilot/*`) ⊥ this repo's responsibility — mailpilot upstream defaults apply, ⊥ render config.json, ⊥ provision credentials JSON, ⊥ thread API keys as `--extra-vars`. Systemd unit ∧ restart-on-change per V11

## §T

|id|status|task|cites
|T1|x|add `make verify` → audits V1 (grep plaintext secrets), V2 (inventory drift vs `terraform-output.json`), V6 (no per-project files outside `config/`)|V1,V2,V6
|T2|x|document ZFS rollback restore-test cadence (smoke-test ≥ 1×/quarter on dev) ∈ README §Recovery|V?,I.cmd
|T3|x|add mailpilot deploy mirror — ansible role `mailpilot/`, `playbook-mailpilot-deploy.yaml`, Makefile `mailpilot-deploy` ∧ `mailpilot-status` targets, GitHub release fetch via `GITHUB_TOKEN`|V1,I.cmd
|T4|x|gate prod deploy — `*-deploy` ∧ `deploy` targets refuse to invoke ansible-playbook when `google_project=lab5-mailpilot-prd1` unless `confirm=prd1` set ∨ interactive y/N answered|V8
|T5|x|enforce V9 — set `SHELL := bash` ∧ `.SHELLFLAGS := -ec` ∈ Makefile head; verify ∀ multi-line recipe (`leadpilot-deploy`, `mailpilot-deploy`, `gce-configure`) propagates non-zero exit on mid-recipe failure|V9
|T6|x|patch `ansible/roles/leadpilot/tasks/main.yaml` ∧ `ansible/roles/mailpilot/tasks/main.yaml` — replace `UV_GIT_TOKEN` env w/ in-URL creds (`git+https://x-access-token:{{ <app>_github_token }}@github.com/kborovik/<app>@v{{ <app>_version }}`); re-run leadpilot-deploy → install task transitions `failed` → `ok`; re-run mailpilot-deploy → install task ⊥ regress. mailpilot patch ≡ symmetry, ⊥ V10-required currently (public repo); future-proofs against visibility flip|V10,I.cmd
|T7|x|add `ansible/roles/mailpilot/templates/mailpilot.service.j2` ∧ ansible task `template:` → /etc/systemd/system/mailpilot.service (Type=simple, ExecStart={{ mailpilot_home }}/.local/bin/mailpilot run, Restart=on-failure, RestartSec=5, User={{ mailpilot_user }}, After=postgresql.service network-online.target, WantedBy=multi-user.target); handler `systemctl daemon-reload + enable + restart mailpilot`; keep `Initialize database schema` task as pre-start guard|V11
|T8|x|(superseded by T10) added ANTHROPIC_API_KEY decrypt + ansible tasks render `config.json.j2` ∧ copy google-credentials.json + thread API keys as `--extra-vars`; `secrets/LOGFIRE_TOKEN.gpg` ∧ `secrets/MAILPILOT_GOOGLE_CREDENTIALS.json.gpg` ⊥ landed; entire impl dropped in T10 per amended §V12 (DB-bootstrap only)|V11,V12
|T9|x|extend Makefile `mailpilot-status` — replace adhoc `mailpilot status` w/ `systemctl is-active mailpilot.service ; mailpilot --version ; journalctl -u mailpilot --no-pager -n 5`; aligns w/ /deploy V6 post-deploy verify|V11,I.cmd
|T10|x|sync code to amended V12 — drop `ansible/roles/mailpilot/templates/config.json.j2`, drop `Render mailpilot config.json` ∧ `Install mailpilot google service-account credentials` tasks ∈ `roles/mailpilot/tasks/main.yaml`, drop `mailpilot_anthropic_api_key`/`mailpilot_logfire_token`/`mailpilot_logfire_environment`/`mailpilot_google_credentials_path` ∈ `roles/mailpilot/defaults/main.yaml`, drop ANTHROPIC_API_KEY/LOGFIRE_TOKEN/MAILPILOT_GOOGLE_CREDENTIALS decrypt ∧ `--extra-vars` threading ∈ `makefile` `mailpilot-deploy`|V12
|T11|.|patch `ansible/roles/tools/tasks/main.yaml` — append task `uv self update` as ubuntu user (`/home/ubuntu/.local/bin/uv self update`), idempotent (`changed_when` keys off "Upgraded" ∈ stdout); ∴ ∀ `gce-configure` run brings uv → latest stable, ⊥ pinning. Single uv install on host (`leadpilot_home ≡ mailpilot_home ≡ /home/ubuntu`) → ⊥ duplicate ∈ app roles|I.cmd

## §B

|id|date|cause|fix
|B1|2026-05-07|`make -n` under `.ONESHELL:` executed deploy recipe → mailpilot playbook ran on `mailpilot-prd1.lab5.ca` (db ∧ tool installed) when intended as dry-run preflight|V8
|B2|2026-05-07|`make leadpilot-deploy` exit 0 despite ansible task FAILED (private-repo `uv tool install` auth) — `.ONESHELL:` recipe @ Makefile:187-206 ⊥ `set -e` ∴ playbook nonzero ⊥ abort; trailing `make -C secrets clean` overrode exit code → `make deploy` masked failure ∧ continued to mailpilot-deploy|V9
|B3|2026-05-07|`uv tool install git+https://github.com/kborovik/leadpilot@vX` on remote GCE (uv 0.11.0) failed w/ `Password authentication is not supported` despite `UV_GIT_TOKEN` env set ∧ `leadpilot_github_token` correctly threaded from Makefile `--extra-vars`; role @ `ansible/roles/leadpilot/tasks/main.yaml:19-20` ⊥ embed creds ∈ URL → git invocation under uv lacks usable cred path. mailpilot ⊥ affected (public repo)|V10
|B4|2026-05-08|V12 amend (commit 9c07904) narrowed scope to DB-bootstrap-only ∧ explicitly forbade config.json render + google-credentials provisioning + API-key `--extra-vars` threading; impl ⊥ synced in same commit ∴ `ansible/roles/mailpilot/{tasks,templates,defaults}` ∧ `makefile mailpilot-deploy` still execute the now-forbidden flow|V12
