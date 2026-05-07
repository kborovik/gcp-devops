---
name: deploy
description: |
  Run deployment cycle for gcp-lab5-apps repo: lint → confirm → `make deploy` →
  verify. Triggers when user says "/deploy", "deploy", "ship", "push to prd",
  "apply changes to GCE". Default target = `lab5-mailpilot-prd1` (production);
  override via `google_project=<name>`. Skill handles preflight, prod
  confirmation gate, secret presence, post-deploy verify.
---

# /deploy — apply repo changes → GCE

Audience: LLM agent operating this repo. Skill ≡ deployment runbook compressed for fast re-load.

## INVARIANTS

V1: ∀ deploy → working tree clean ∨ user ack dirty state. ⊥ deploy unstaged surprises.
V2: ∀ deploy → target project named in confirmation prompt. ⊥ implicit prod.
V3: prod (`lab5-mailpilot-prd1`) → ! explicit user "yes deploy to prod" before `make deploy`. Hook will block otherwise (correct behavior).
V4: deploy ≡ `make deploy` ∴ submakes inherit `google_project` via `.EXPORT_ALL_VARIABLES`. ⊥ pass per-submake.
V5: ∀ deploy → `make lint` ! exit 0 first. lint failure ≡ deploy bail. fix all violations (∨ scope-suppress in `.ansible-lint`) ∧ retry; ⊥ proceed dirty.
V6: post-deploy → ! `make gce-status` ∧ `make leadpilot-status` (∨ `gce-exec cmd='systemctl status leadpilot.timer'`).
V7: ∀ deploy failure (lint fail, plan-check exit 2, gce-configure fail, leadpilot-deploy fail, post-deploy verify fail) → ! auto-invoke `/sdd:spec bug:` w/ failing stage + observed symptom + cmd output excerpt before surfacing fix to user. ⊥ retry ∨ patch silently. Backprop skill decides if new §V invariant prevents recurrence.

## TASKS

|id|status|task|cites
|T1|.|read working tree state (git status, branch)|V1
|T2|.|run `make settings` → echo project to user|V2
|T3|.|run `make lint` → ! exit 0; ⊥ proceed otherwise|V5
|T4|.|ask user confirmation w/ project name + change summary|V3
|T5|.|run `make deploy` (∨ `make deploy google_project=<name>`)|V4
|T6|.|run `make gce-status` ∧ `make leadpilot-status` → emit summary|V6
|T7|.|on any failure in T3/T5/T6 → invoke `/sdd:spec bug: <stage> — <symptom>` w/ cmd output excerpt; ⊥ skip on transient/retry-class fail (spec skill triages)|V7

## SECRETS PREFLIGHT

`make deploy` decrypts via gpg → ! gpg-agent unlocked. Required:

|secret|used by
|`secrets/CLOUDFLARE_API_TOKEN.gpg`|terraform DNS
|`secrets/TAILSCALE_AUTH_KEY.gpg`|gce-configure
|`secrets/POSTGRESQL_REMOTE_PASSWORD.gpg`|gce-configure
|`secrets/GITHUB_TOKEN.gpg`|leadpilot-deploy
|`secrets/ssh.key.gpg`|ansible-ready
|`secrets/github-signing.key.gpg`|ansible-ready

`gpg -d secrets/<f>.gpg >/dev/null` → fast probe; fail → ask user to unlock gpg-agent.

## FRICTIONS (outstanding)

⊥ outstanding @ time of writing. Append new entries here as discovered.

## INTERFACES

```
cmd: make deploy [google_project=<name>]      → terraform-apply + gce-configure + leadpilot-deploy
cmd: make lint                                → terraform-validate + ansible-lint
cmd: make settings                            → echo project/region/zone/config_dir
cmd: make gce-status                          → gcloud instances list
cmd: make leadpilot-status                    → ansible all -m shell ...
cmd: make gce-exec cmd='<sh>'                 → ansible adhoc shell
cmd: make gce-ssh                             → ssh ubuntu@<dns>
cmd: make terraform-plan                      → preview infra delta
env: google_project ?= lab5-mailpilot-prd1    → override per-invocation
```

## SCOPE BOUNDARIES

- Code edits to roles/playbooks ∈ scope of caller (user ∨ prior agent turn). /deploy ⊥ author code; runs cycle.
- ⊥ touch `terraform/` HCL, `ansible/roles/*/tasks/`, `Makefile` from this skill.
- Secrets edits ∉ scope; ! handled out-of-band via `make -C secrets {decrypt,encrypt,clean}`.
- Rollback ≡ revert commit + re-deploy. ⊥ in-place rollback target since pilot removed.

## DECISION TREE

```
user: "/deploy"
  ├─ git status dirty?
  │   ├─ yes → ask: stash ∨ commit ∨ proceed dirty?
  │   └─ no → continue
  ├─ make settings → render project
  ├─ user-target = prod (lab5-mailpilot-prd1)?
  │   ├─ yes → ask: "deploy to prod (lab5-mailpilot-prd1)? yes/no"
  │   │         ├─ no → bail
  │   │         └─ yes → continue
  │   └─ no → continue (dev/non-prod ⊥ require extra ack)
  ├─ make lint
  │   ├─ pass (exit 0) → continue
  │   └─ fail → invoke `/sdd:spec bug: lint — <rule_id> @ <file>:<line>` w/ excerpt → fix violations (∨ scope-suppress in `.ansible-lint`) ∧ retry. ⊥ proceed.
  ├─ secrets preflight → all gpg-decrypt OK?
  │   ├─ no → ask user to unlock gpg-agent → retry
  │   └─ yes → continue
  ├─ make deploy [google_project=<name>]
  │   ├─ plan-check exit 2 (changes pending) → invoke `/sdd:spec bug: tf-plan-drift — <resources>` → bail; user runs `make terraform-apply` then re-runs deploy
  │   ├─ fail @ gce-configure → invoke `/sdd:spec bug: gce-configure — <task> <handler>` w/ ansible output excerpt → render handler, ask
  │   └─ fail @ leadpilot-deploy → invoke `/sdd:spec bug: leadpilot-deploy — <stage>` w/ excerpt → check GitHub API auth (token decrypt), fallback to explicit `leadpilot_version=`
  └─ make gce-status ∧ make leadpilot-status
      ├─ pass → emit summary
      └─ fail (timer ⊥ active, version mismatch, instance ⊥ RUNNING) → invoke `/sdd:spec bug: post-deploy-verify — <symptom>` w/ status excerpt → surface to user
```

## POST-DEPLOY VERIFY

Render to user:
- gce instance status (RUNNING)
- leadpilot version installed (`leadpilot --version`)
- leadpilot timer state (`systemctl status leadpilot.timer`)
- last 5 lines of leadpilot log (`tail -5 ~/.local/state/leadpilot/server.log` ∨ equivalent)

## RELATED

- §V/§T citation style ≡ /sdd:glyph
- commit ∀ post-deploy diff via /gh:commit
- prod deploy gate enforced @ `~/.claude/settings.json` permission rules; this skill cooperates, ⊥ bypasses.
- ∀ deploy-cycle failure → /sdd:spec bug: (per V7) → routes via /sdd:backprop → §B append + decide if new §V catches recurrence. ⊥ patch silently. Skip iff fail ≡ pure-mechanical (typo, one-off retry-class) per backprop skill triage.
