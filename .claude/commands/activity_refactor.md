Perform a full code quality review of the project codebase, then produce an actionable refactoring report.

## Phase 1: Review

Systematically read through ALL GDScript files in the project (use the `critic` agent for the heavy lifting). Look for:

- **Copy-paste duplication**: identical or near-identical logic repeated across files
- **Bad architecture**: classes doing too much, wrong inheritance, circular dependencies, god objects
- **Dead code**: unused functions, unreachable branches, commented-out blocks left behind
- **Naming issues**: inconsistent naming conventions, misleading names, abbreviations that obscure meaning
- **Coupling problems**: systems that reach into each other's internals instead of using clean interfaces
- **Anti-patterns**: signals connected but never used, excessive type casting, stringly-typed APIs
- **Violation of project conventions**: things that break the patterns documented in CLAUDE.md (e.g. UI created in code instead of scenes, pushing items instead of pulling)

Be thorough. Read every `.gd` file. Don't skim.

## Phase 2: Report

Run `date` to get today's date, then create a report file at:

```
docs/refactoring/YYYY-MM-DD.md
```

Format the report as a numbered list of findings. Each finding must include:

1. **Title** — short description of the problem
2. **Location** — file path(s) and line numbers
3. **Problem** — what's wrong and why it matters
4. **Proposed fix** — concrete solution (not vague advice)
5. **Risk** — low/medium/high, what could break
6. **Effort** — small/medium/large

Group findings by category (duplication, architecture, dead code, etc.). Put the highest-impact items first within each category.

End the report with a summary: total findings count, breakdown by risk and effort, and a recommended order of operations.

## Phase 3: Wait for user review

After creating the report, tell the user:
- The report path
- A brief summary (e.g. "Found 12 issues: 3 high-risk, 5 medium, 4 low")
- Ask them to review and tell you which items to fix

Do NOT start refactoring until the user explicitly approves specific items.

## Phase 4: Refactor (after user approval)

When the user says which items to fix:
1. Fix them one at a time, committing after each
2. Run the parse check after each change
3. Run relevant simulations/scenarios to verify nothing broke
4. Update the report file: mark completed items with a checkmark
