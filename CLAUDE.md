# CLAUDE.md

## Source of truth: SPEC.md

Invariants, interfaces, and tasks live in `SPEC.md` (math-glyph, LLM-facing). Read it first. `/sdd:explain` decodes to prose; `/sdd:check` audits drift; `/sdd:spec` is the sole mutator. Do not hand-edit `SPEC.md`.

## Operational notes

### Secrets — Claude Code workflow
- Decrypt: `gpg -d secrets/<f>.gpg`
- Re-encrypt: `gpg -e -r $(cat secrets/.gpg_id) -o secrets/<f>.gpg secrets/<f>`
- Humans use `make -C secrets decrypt|encrypt|clean`
- Decrypt timing: `CLOUDFLARE_API_TOKEN` at TF runtime; `TAILSCALE_AUTH_KEY`, `POSTGRESQL_REMOTE_PASSWORD`, `GITHUB_TOKEN` at Ansible runtime via `gce-configure` / `leadpilot-deploy` / `mailpilot-deploy`

### Gotchas
- First setup: run `make terraform-apply` before `make gce-configure` — inventory regenerates from TF output
- GCE auto-stop schedules per `gce_schedule` tfvar: dev1=`stop_only` (20:00 ET stop), prd1=`none`
- Backups: ZFS snapshots via Sanoid (12h/7d/4w, local) + GCE disk snapshots (daily 02:00 UTC, 14d retention)
