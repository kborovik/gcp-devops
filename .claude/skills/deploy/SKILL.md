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
V6: post-deploy → ! `make gce-status` ∧ `make mailpilot-status`.
V7: ∀ deploy failure (lint fail, plan-check exit 2, gce-configure fail, mailpilot-deploy fail, post-deploy verify fail) → ! auto-invoke `/sdd:spec bug:` w/ failing stage + observed symptom + cmd output excerpt before surfacing fix to user. ⊥ retry ∨ patch silently. Backprop skill decides if new §V invariant prevents recurrence.
V8: prod gate is var-driven, ⊥ stdin-driven. Makefile `require_prd_confirm` reads `confirm=prd1` ∧ fires once per submake (`deploy`, `gce-configure`, `mailpilot-deploy`). ∴ ∀ non-interactive prod deploy → `make deploy confirm=prd1` (propagates to all submakes). ⊥ `echo yes | make deploy` — outer gate eats the single yes ∧ inner submake gate starves @ EOF.

## TASKS

|id|status|task|cites
|T1|.|read working tree state (git status, branch)|V1
|T2|.|run `make settings` → echo project to user|V2
|T3|.|run `make lint` → ! exit 0; ⊥ proceed otherwise|V5
|T4|.|ask user confirmation w/ project name + change summary|V3
|T5|.|run `make deploy confirm=prd1` (∨ `make deploy google_project=<name> confirm=prd1` for prod; omit `confirm` for non-prod)|V4,V8
|T6|.|run `make gce-status` ∧ `make mailpilot-status` → emit summary|V6
|T7|.|on any failure in T3/T5/T6 → invoke `/sdd:spec bug: <stage> — <symptom>` w/ cmd output excerpt; ⊥ skip on transient/retry-class fail (spec skill triages)|V7

## SECRETS PREFLIGHT

`make deploy` reads via `pass(1)` (GPG-backed) → ! gpg-agent unlocked. Required entries ∈ `~/.password-store/gcp-devops/`:

|secret|used by
|`gcp-devops/CLOUDFLARE_API_TOKEN`|terraform DNS
|`gcp-devops/TAILSCALE_AUTH_KEY`|gce-configure
|`gcp-devops/POSTGRESQL_REMOTE_PASSWORD`|gce-configure
|`gcp-devops/GITHUB_TOKEN`|mailpilot-deploy
|`gcp-devops/ssh.key`|ansible-ready
|`gcp-devops/github-signing.key`|ansible-ready

`pass show gcp-devops/<K> >/dev/null` → fast probe; fail → ask user to unlock gpg-agent ∨ check pass store.

## FRICTIONS (outstanding)

⊥ outstanding @ time of writing. Append new entries here as discovered.

### Resolved

- **2026-05-07 — stdin-yes prod gate starvation**: skill ran `echo yes | make deploy` to satisfy prod confirm; outer `deploy` recipe ate the single yes, inner `leadpilot-deploy` submake's gate hit EOF ∧ bailed w/ `aborted: pass confirm=prd1 to skip prompt`. Recovered via `make leadpilot-deploy confirm=prd1`. Backpropped ≡ §V8 ∧ T5 update ∧ INTERFACES update ∧ DECISION TREE update. Lesson: Makefile §V8 (`require_prd_confirm`) is var-driven ∧ fires per-submake, ⊥ stdin-driven once.

## INTERFACES

```
cmd: make deploy confirm=prd1 [google_project=<name>]  → terraform-apply + gce-configure + mailpilot-deploy (prod ! `confirm=prd1` per V8; non-prod omits)
cmd: make lint                                → terraform-validate + ansible-lint
cmd: make settings                            → echo project/region/zone/config_dir
cmd: make gce-status                          → gcloud instances list
cmd: make mailpilot-status                    → ansible all -m shell ...
cmd: make gce-exec cmd='<sh>'                 → ansible adhoc shell
cmd: make gce-ssh                             → ssh ubuntu@<dns>
cmd: make terraform-plan                      → preview infra delta
env: google_project ?= lab5-mailpilot-prd1    → override per-invocation
```

## SCOPE BOUNDARIES

- Code edits to roles/playbooks ∈ scope of caller (user ∨ prior agent turn). /deploy ⊥ author code; runs cycle.
- ⊥ touch `terraform/` HCL, `ansible/roles/*/tasks/`, `Makefile` from this skill.
- Secrets edits ∉ scope; ! handled out-of-band via `pass insert -m gcp-devops/<KEY>` (rotate) ∨ `pass show gcp-devops/<KEY>` (read).
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
  ├─ make deploy confirm=prd1 [google_project=<name>]   (confirm=prd1 ∀ prod per V8; omit ∀ non-prod)
  │   ├─ plan-check exit 2 (changes pending) → invoke `/sdd:spec bug: tf-plan-drift — <resources>` → bail; user runs `make terraform-apply` then re-runs deploy
  │   ├─ fail @ gce-configure → invoke `/sdd:spec bug: gce-configure — <task> <handler>` w/ ansible output excerpt → render handler, ask
  │   └─ fail @ mailpilot-deploy → invoke `/sdd:spec bug: mailpilot-deploy — <stage>` w/ excerpt → check GitHub API auth (token decrypt), fallback to explicit `mailpilot_version=`
  └─ make gce-status ∧ make mailpilot-status
      ├─ pass → emit summary
      └─ fail (timer ⊥ active, version mismatch, instance ⊥ RUNNING) → invoke `/sdd:spec bug: post-deploy-verify — <symptom>` w/ status excerpt → surface to user
```

## POST-DEPLOY VERIFY

Render to user:
- gce instance status (RUNNING)
- mailpilot version installed (`mailpilot --version`)
- mailpilot service state (`systemctl is-active mailpilot.service`)
- last 5 lines of mailpilot journal (`journalctl -u mailpilot --no-pager -n 5`)

## RELATED

- §V/§T citation style ≡ /sdd:glyph
- commit ∀ post-deploy diff via /gh:commit
- prod deploy gate enforced @ `~/.claude/settings.json` permission rules; this skill cooperates, ⊥ bypasses.
- ∀ deploy-cycle failure → /sdd:spec bug: (per V7) → routes via /sdd:backprop → §B append + decide if new §V catches recurrence. ⊥ patch silently. Skip iff fail ≡ pure-mechanical (typo, one-off retry-class) per backprop skill triage.
