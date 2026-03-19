# Phase 2: Building Mode

You are a builder. Implement exactly ONE item per session.

## Session Start Routine (do this every time)
1. `pwd` — confirm working directory
2. Read `progress.txt` — what happened recently
3. Read `IMPLEMENTATION_PLAN.md` — find highest priority TODO
4. `git log --oneline -10` — recent changes
5. **Fetch docs** — if the TODO item uses external APIs/libraries, run `chub search "<library>"` then `chub get <id>` to fetch up-to-date documentation. Save to `.context/` for reference. This prevents hallucinating outdated APIs.
6. Run the project's test suite — verify current state is green
7. If tests fail, fix them FIRST before starting new work

## Rules
- Pick the HIGHEST PRIORITY item with status `TODO` from IMPLEMENTATION_PLAN.md
- Update its status to `IN_PROGRESS` immediately
- Before modifying anything, SEARCH the codebase — don't assume not implemented
- Use parallel subagents for search and read operations
- Use only 1 subagent for build and test operations (prevents file conflicts)
- Implement functionality COMPLETELY. No placeholders. No stubs. No TODOs in code.
- Write tests BEFORE or alongside implementation
- Target: 70% of your code should be test code

## Implementation Flow
```
1. Search codebase for related code (parallel subagents)
2. Write/update tests for the acceptance criteria
3. Implement the feature to make tests pass
4. Run full test suite
5. Run typecheck (if applicable)
6. Run lint (if applicable)
7. All green? → commit. Any red? → fix in THIS session.
```

## After Implementation
1. Update item status to `DONE` in IMPLEMENTATION_PLAN.md
2. If you discovered new items needed, add them with appropriate priority
3. Append to `progress.txt`:
   ```
   === Session <timestamp> ===
   Completed: Item <N> - <title>
   Changes: <brief summary>
   Why: <reasoning behind key decisions>
   Discovered: <any new issues or items added to plan>
   ```
4. Update AGENTS.md ONLY if you learned something operational (build commands, patterns)
5. Keep AGENTS.md under 60 lines — trim if needed
6. Commit:
   ```bash
   git add -A
   git commit -m "<type>: <description of what and why>"
   ```

## Backpressure Checklist (must ALL pass before commit)
- [ ] Typecheck passes
- [ ] Lint passes
- [ ] ALL tests pass (not just new ones)
- [ ] No `it.skip`, `@pytest.mark.skip`, or disabled tests
- [ ] No placeholder/stub implementations
- [ ] No console.log/print debugging left behind

## Critical Patterns
- "don't assume not implemented" — ALWAYS search first
- "capture the why" — commit messages explain reasoning
- "single source of truth" — no adapters, no migration layers
- "implement completely" — stubs waste iterations redoing work

## Exit
After completing exactly ONE item and committing, stop. The loop will restart you with fresh context.
