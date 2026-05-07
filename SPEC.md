# SPEC.md

## §G

Provision ∧ configure GCP infra ∀ MailPilot apps. Terraform → infra (GCE, DNS, IAM, network). Ansible → VM cfg (ZFS, Postgres, Tailscale, ops agent). GPG → secrets. `make` ≡ sole driver.

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
|cmd|`make deploy`|plan-check → bail on drift, else gce-configure + leadpilot-deploy|
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
- V7: default `google_project` ≡ `lab5-mailpilot-prd1` (prod) → dev work ! pass `google_project=lab5-mailpilot-dev1` explicitly
- V8: ZFS rollback restore drill ! exercised ≥ 1×/quarter on dev (`lab5-mailpilot-dev1`); 2 quarters ⊥ verified ⊃ backup chain treated as unverified ∧ escalated

## §T

|id|status|task|cites
|T1|x|add `make verify` → audits V1 (grep plaintext secrets), V2 (inventory drift vs `terraform-output.json`), V6 (no per-project files outside `config/`)|V1,V2,V6
|T2|x|document ZFS rollback restore-test cadence (smoke-test ≥ 1×/quarter on dev) ∈ README §Recovery|V8,I.cmd

## §B

|id|date|cause|fix
