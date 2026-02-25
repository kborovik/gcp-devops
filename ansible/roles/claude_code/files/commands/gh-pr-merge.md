---
description: Merge current branch PR into main with release-ready commit message
argument-hint: [PR number]
---

Merge the current branch's PR into main with a detailed, release-note-ready commit message.

## gh pr merge Flags Reference

```
-s, --squash          Squash commits into one and merge
-m, --merge           Merge commits with base branch
-r, --rebase          Rebase commits onto base branch
-t, --subject TEXT    Subject/title for merge commit
-b, --body TEXT       Body text for merge commit
-F, --body-file FILE  Read body from file (use "-" for stdin)
-d, --delete-branch   Delete local and remote branch after merge
    --auto            Auto-merge when requirements are met (for merge queues)
    --disable-auto    Disable auto-merge for this PR
    --admin           Bypass merge requirements (admin only)
    --match-head-commit SHA  Verify HEAD matches before merging
```

## Process

1. **Identify the PR to merge:**
   - If $ARGUMENTS provided, use as PR number
   - Otherwise, get PR for current branch: `gh pr view --json number,title,body,url`
   - If no PR exists, inform user and exit

2. **Verify PR is ready to merge:**
   - Check remote status:
     - `gh pr checks` — CI status
     - `gh pr view --json mergeable` — merge conflicts
     - `gh pr view --json reviewDecision` — review approval
     - `gh pr view --json isDraft` — draft status
   - Run mandatory local gates (must both pass before proceeding):
     - `make check` — code quality (linting, formatting, types)
   - If either gate fails, inform user of failures and exit
   - If draft and all gates pass, ask user if they want to mark it ready: `gh pr ready`
   - If not ready (failing checks, unresolved conflicts, missing reviews), inform user of blockers and exit

3. **Analyze the changes:**
   - Get all commits in PR: `gh pr view --json commits`
   - Get files changed: `gh pr diff --name-only` or `git diff main..HEAD --stat`
   - Review the actual diff: `gh pr diff`
   - Identify the scope: bug fix, feature, enhancement, refactor, etc.

4. **Generate release-note-ready commit message:**
   - Title: Conventional Commits format from PR title with PR number -- `type(area): concise imperative description (#42)`
     - **type**: `fix`, `feat`, `refactor`, `chore`, `docs`, `test`
     - **area**: affected module (`gmail`, `missions`, `cli`, `e2e`, `server`, `contacts`, `calendar`, `schema`, `config`, `llm`)
     - Derive from the PR title; if the PR already uses this format, reuse it directly
   - Body sections:
     - **Summary**: 2-3 sentence description of what changed
     - **Changes**: Bulleted list of key changes
     - **Breaking Changes**: Note any breaking changes (if applicable)
   - Format for squash merge

5. **Post model insights as PR comment:**
   - Before merging, add a comment to the PR with any notable insights from the analysis
   - Use `gh pr comment <number> --body "$(cat <<'EOF'...EOF)"`
   - Include any of the following that apply:
     - Observations about code quality or patterns in the diff
     - Technical debt or risks noticed during review
     - Suggestions for follow-up work
     - Edge cases or considerations for the release
   - Keep the comment concise and actionable — skip this step if there are no meaningful insights

6. **Merge the PR:**
   - Use squash merge with `-d` to delete branch automatically:
     ```bash
     gh pr merge <number> -s -d -t "<title>" -b "$(cat <<'EOF'
     <body>
     EOF
     )"
     ```
   - Alternative merge strategies:
     - Merge commit: `gh pr merge <number> -m -d`
     - Rebase: `gh pr merge <number> -r -d`
   - For repos with merge queues, use `--auto` to queue when checks pass

7. **Clean up branches:**
   - The `-d` flag handles remote branch deletion
   - Switch to main: `git checkout main`
   - Pull latest: `git pull origin main`
   - Delete local branch if still exists: `git branch -d <branch-name>`
   - Prune stale remote refs: `git fetch --prune`

8. **Confirm completion:**
   - Show the merge commit: `git log -1`
   - Output the merged PR URL
   - Display the commit message for release notes

## Commit Message Format

```
feat(server): add user authentication system (#42)

## Summary
Implements JWT-based authentication replacing the session-based system.
Users can now log in and receive tokens that expire after 24 hours.

## Changes
- Add JWT token generation and validation
- Create login and registration endpoints
- Add middleware for protected routes
- Add token refresh endpoint

## Breaking Changes
- Session cookies are no longer supported
- API clients must include Authorization header
```

## Requirements

- Always use squash merge for clean history (unless repo prefers merge commits)
- Use Conventional Commits format with PR number: `type(area): description (#number)`
- Commit message must be suitable for release notes
- Use `-d` flag to clean up branches automatically
- Verify all checks pass before merging
- Never force merge if checks are failing
- For draft PRs, confirm with user before marking ready
