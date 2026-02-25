---
description: Create a PR from an issue number or objective description
argument-hint: [issue number or PR objective]
---

Create a pull request from a GitHub issue number or a free-form objective description.

## gh pr create Flags Reference

```
-a, --assignee login       Assign people by their login (@me to self-assign)
-B, --base branch          The branch into which you want your code merged
-b, --body string          Body for the pull request
-F, --body-file file       Read body text from file (use "-" for stdin)
-d, --draft                Mark pull request as a draft
    --dry-run              Print details instead of creating the PR
-f, --fill                 Use commit info for title and body
    --fill-first           Use first commit info for title and body
    --fill-verbose         Use commits msg+body for description
-H, --head branch          The branch that contains commits for your PR (default: current branch)
-l, --label name           Add labels by name
-m, --milestone name       Add the PR to a milestone by name
    --no-maintainer-edit   Disable maintainer's ability to modify PR
-p, --project title        Add the PR to projects by title
-r, --reviewer handle      Request reviews from people or teams by handle
-T, --template file        Template file to use as starting body text
-t, --title string         Title for the pull request
-w, --web                  Open the web browser to create a PR
```

## Process

### Phase 1: Parse input and create PR

1. **Determine input type from $ARGUMENTS:**
   - If no argument provided: use AskUserQuestion to ask for a GitHub issue number to work on
   - If argument is a number: treat as GitHub issue number (go to step 2a)
   - If argument is text: treat as free-form objective (go to step 2b)

2a. **From issue number — fetch issue details:**

- Fetch issue: `gh issue view <number>`
- Extract issue title, body, and labels
- PR title: Conventional Commits format matching the issue -- `type(area): concise imperative description`
  - **type**: `fix`, `feat`, `refactor`, `chore`, `docs`, `test`
  - **area**: affected module (`gmail`, `missions`, `cli`, `e2e`, `server`, `contacts`, `calendar`, `schema`, `config`, `llm`)
  - Derive from the issue title; if the issue already uses this format, reuse it directly
- PR body: include `Resolves #<number>` to auto-close the issue
- Branch name format: `<issue-number>-<slugified-title>` (e.g., `42-add-rate-limiting`)
- Slugify: lowercase, replace spaces with hyphens, remove special chars, max 50 chars
- Create branch and PR:
  - Ensure starting from main: `git checkout main && git pull origin main`
  - Create branch: `git checkout -b <issue-number>-<slugified-title>`
  - Empty commit: `git commit --allow-empty -m "wip: <issue-title> (#<issue-number>)"`
  - Push: `git push -u origin <branch-name>`
  - Create regular PR: `gh pr create --title "..." --body "$(cat <<'EOF'...EOF)"`
  - Output the PR URL

2b. **From free-form objective:**

- Generate a PR title in Conventional Commits format from the objective -- `type(area): concise imperative description`
  - **type**: `fix`, `feat`, `refactor`, `chore`, `docs`, `test`
  - **area**: affected module (`gmail`, `missions`, `cli`, `e2e`, `server`, `contacts`, `calendar`, `schema`, `config`, `llm`)
- Do NOT investigate the codebase yet — derive the title directly from the objective
- Slugify title: lowercase, replace spaces with hyphens, remove special chars, max 50 chars
- Create branch and PR:
  - Ensure starting from main: `git checkout main && git pull origin main`
  - Create branch with temporary name: `git checkout -b <slugified-title>`
  - Empty commit: `git commit --allow-empty -m "wip: <PR title>"`
  - Push: `git push -u origin <slugified-title>`
  - Create regular PR: `gh pr create --title "..." --body "$(cat <<'EOF'...EOF)"`
  - Extract the PR number from the output URL

### Phase 2: Investigate and plan (after PR exists)

3. **Investigate the codebase:**
   - Search for relevant files using Grep/Glob
   - Read related code to understand current implementation
   - Check git log for recent changes in affected areas
   - Identify affected components/modules

4. **Create implementation plan:**
   - Write a detailed plan based on codebase investigation
   - Include: affected files, required changes, testing approach
   - Use EnterPlanMode to present the plan for user review

5. **Implement the plan:**
   - Start working immediately after plan approval — do not pause for confirmation
   - Follow the plan steps, writing tests first (TDD)
   - Commit progress incrementally

### Phase 3: Verify

6. **Run verification gate:**
   - Run `make check && make clean && make e2e` after major code changes
   - Must pass before the PR is considered complete
   - If the tests fail, diagnose from the output and fix until they pass

7. **Post model insights as PR comment:**
   - After implementation, add a comment to the PR with any notable insights discovered during the work
   - Use `gh pr comment <number> --body "$(cat <<'EOF'...EOF)"`
   - Include any of the following that apply:
     - Architectural observations or design decisions made
     - Technical debt discovered or trade-offs chosen
     - Edge cases identified and how they were handled
     - Alternative approaches considered and why they were rejected
     - Potential risks or areas that may need future attention
   - Keep the comment concise and actionable — skip this step if there are no meaningful insights

## Requirements

- Always create a regular PR (do not use `--draft`)
- Keep branch names concise but descriptive
- Investigation should be thorough before planning
- Plan must be actionable with clear steps
- When from an issue: always link PR with "Resolves #<number>" in the body
- When from an objective: PR body should contain enough context for reviewers
- Start implementing immediately after plan approval — no confirmation pauses
- Success is measured by `make check && make clean && make e2e` passing — this is the ultimate acceptance gate
