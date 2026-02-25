---
description: Create, file, open, log, or track a GitHub issue, bug report, feature request, or ticket. Use when the user wants to report a bug, request a feature, propose a change, flag a problem, track work, or open any kind of issue against the repository.
argument-hint: <issue description>
---

Create a GitHub issue by investigating the codebase first to gather context.

## Process

1. **Parse the issue description from $ARGUMENTS**
   - If no description provided, ask user what issue they want to create

2. **Investigate the codebase based on the description:**
   - Search for relevant files using Grep/Glob
   - Read related code to understand current implementation
   - Check git log for recent changes in affected areas
   - Identify affected components/modules

3. **Gather issue details:**
   - Determine issue type: bug, feature, enhancement, refactor
   - Identify affected files and code paths
   - For bugs: look for error patterns, failing conditions
   - For features: identify where changes would be needed

4. **Ask clarifying questions if needed:**
   - Use AskUserQuestion for ambiguous requirements
   - Confirm scope if investigation reveals multiple approaches
   - Ask for reproduction steps if reporting a bug

5. **Generate issue content:**
   - Title: Conventional Commits format -- `type(area): concise imperative description`
     - **type**: `fix`, `feat`, `refactor`, `chore`, `docs`, `test`
     - **area**: affected module (`gmail`, `missions`, `cli`, `e2e`, `server`, `contacts`, `calendar`, `schema`, `config`, `llm`)
     - Examples:
       - `fix(gmail): Thread ID divergence breaking outbound assignment routing`
       - `feat(schema): Data deletion policy across schema and delete commands`
       - `refactor(e2e): Redesign fixtures as capability specs`
       - `chore(cli): Remove deprecated debug_modules setting`
   - Body sections:
     - **Summary**: 2-3 sentence description
     - **Context**: Relevant code paths and files found during investigation
     - **Proposed Solution** (if applicable): Based on codebase analysis
     - **Acceptance Criteria**: Clear, testable requirements
     - **Affected Files**: List of files that may need changes

6. **Create the issue:**
   - Use `gh issue create --title "..." --body "$(cat <<'EOF'...EOF)"`
   - Output the issue URL and number

7. **Post model insights as issue comment:**
   - After creating the issue, add a comment with any notable insights from the investigation
   - Use `gh issue comment <number> --body "$(cat <<'EOF'...EOF)"`
   - Include any of the following that apply:
     - Deeper architectural context discovered during investigation
     - Related code patterns or dependencies that may not be obvious
     - Potential risks or complexity that could affect implementation
     - Alternative approaches or considerations worth noting
   - Keep the comment concise and actionable — skip this step if there are no meaningful insights

## Requirements

- Investigate before asking questions - gather context first
- Keep investigation focused on the issue description
- Don't create overly long issues - be concise
- Use markdown formatting in issue body
- Reference specific files/line numbers when relevant
