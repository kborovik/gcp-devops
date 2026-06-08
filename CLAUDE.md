# CLAUDE.md

## Source of truth: SPEC.md

Invariants, interfaces, and tasks live in `SPEC.md` (math-glyph, LLM-facing). Read it first. `/sdd:explain` decodes to prose; `/sdd:check` audits drift; `/sdd:spec` is the sole mutator. Do not hand-edit `SPEC.md`.

## Operational notes

### Secrets — Claude Code workflow
- Read: `pass show gcp-devops/<KEY>` (entries encrypted to recipient `E4AFCA7FBB19FC029D519A524AEBB5178D5E96C1` per `~/.password-store/gcp-devops/.gpg-id`)
- Write/rotate: `pass insert -m gcp-devops/<KEY>` (interactive; reads stdin until EOF)
- File-on-disk artifacts (`ssh.key`, `github-signing.key`) decrypt to `.cache/` via `make ansible-ready`; shredded by `make cache-clean` post-deploy
- Decrypt timing: `CLOUDFLARE_API_TOKEN` at TF runtime; `TAILSCALE_AUTH_KEY`, `POSTGRESQL_REMOTE_PASSWORD`, `LOGFIRE_READ_TOKEN`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN` at Ansible runtime via `gce-configure` / `mailpilot-deploy`

### Gotchas
- First setup: run `make terraform-apply` before `make gce-configure` — inventory regenerates from TF output
- GCE auto-stop schedules per `gce_schedule` tfvar: dev1=`stop_only` (20:00 ET stop), prd1=`none`
- Backups: ZFS snapshots via Sanoid (12h/7d/4w, local) + GCE disk snapshots (daily 02:00 UTC, 14d retention)
