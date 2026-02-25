---
description: Commit staged changes with a descriptive message
argument-hint: [commit message hint]
---

Commit the currently staged changes with a well-crafted commit message.

## Process

1. **Check for staged changes:**
   - Run `git diff --cached --stat` to see what's staged
   - If nothing staged, inform user and exit
   - If $ARGUMENTS provided, use it as context/hint for commit message

2. **Analyze the changes:**
   - Run `git diff --staged` to review actual code changes
   - Identify what was added, modified, or removed
   - Understand the purpose and scope of changes

3. **Check repository commit style:**
   - Run `git log --oneline -10` to see recent commit message patterns
   - Match the existing style (prefixes, capitalization, format)

4. **Generate commit message:**
   - Title: Conventional Commits format -- `type(area): concise imperative description`
     - **type**: `fix`, `feat`, `refactor`, `chore`, `docs`, `test`
     - **area**: affected module (`gmail`, `missions`, `cli`, `e2e`, `server`, `contacts`, `calendar`, `schema`, `config`, `llm`)
   - Keep title under 72 characters
   - For complex changes, add body after blank line with details

5. **Create the commit:**
   - Use heredoc format for proper formatting:
     ```
     git commit -m "$(cat <<'EOF'
     <title>

     <optional body>
     EOF
     )"
     ```

6. **Verify the commit:**
   - Run `git status` to confirm clean state
   - Run `git log -1` to show the created commit

## Commit Message Format

Simple change:
```
fix(server): add validation for email input
```

Complex change with body:
```
refactor(server): replace session-based auth with JWT tokens

- Replace session-based auth with JWT
- Add token refresh endpoint
- Update middleware to validate tokens
- Add tests for token expiration
```

## Requirements

- Use Conventional Commits format: `type(area): imperative description`
- Title should complete: "This commit will..."
- Only commit what's already staged (don't stage additional files)
- Don't push unless explicitly requested
- Match existing repository commit style when possible
- Reference issue numbers if relevant (e.g., "fix login bug (#42)")
