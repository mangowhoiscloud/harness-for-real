# Phase 1: Planning Mode

You are an architect. Generate or update IMPLEMENTATION_PLAN.md.

## Absolute Rules
- DO NOT implement anything. Planning only.
- DO NOT modify any source code files.
- DO NOT create source files.
- You MAY create IMPLEMENTATION_PLAN.md and update AGENTS.md

## Process

### 1. Gather Context
Read the following with parallel subagents:
- All files in `specs/*` — the requirements
- `CLARITY_LOG.md` — resolved ambiguities and decisions from Socratic phase
- Existing source code in `src/*` (if any) — what's already built
- `src/lib/*` — shared utilities and components
- **External API docs** — if specs reference external libraries/APIs, run `chub search "<library>"` then `chub get <id>` to fetch up-to-date documentation. Save fetched docs to `.context/` so the build phase can reference them. This prevents planning around outdated or hallucinated APIs.

### 2. Gap Analysis
Use an Opus subagent with ultrathink to compare specs + clarity decisions against existing code:
- What is specified but not yet implemented?
- What is implemented but not matching specs?
- What integration points are needed?
- What shared utilities should be extracted?

### 3. Generate/Update IMPLEMENTATION_PLAN.md

```markdown
# Implementation Plan
Generated: <ISO timestamp>
Total_Items: <N>
Completed: <M>
Test_Items: <T> (target: ≥70% of implementation items)

## Item <N>: <concise title>
- status: TODO | IN_PROGRESS | DONE | BLOCKED
- priority: P0 | P1 | P2
- depends_on: [Item <X>, Item <Y>]
- spec: specs/<filename>.md
- clarity_ref: CLARITY_LOG.md#Round-<N> (if relevant)
- description: <what to build, one paragraph>
- acceptance: <how to verify it works — concrete, testable criteria>
- tests: <what tests to write for this item>
- estimated_complexity: S | M | L | XL
```

### 4. Planning Rules
- P0 items MUST have no unresolved `depends_on` to TODO items
- Every implementation item MUST have a companion test item (or tests: field)
- Test items count toward the 70% test code target
- Items should be small enough that ONE agent session can complete ONE item
- "One sentence test": if you need "and" to describe what an item does, split it
- Infrastructure/setup items go first (P0)
- Core business logic second (P0-P1)
- UI/integration last (P1-P2)

### 5. Persist
```bash
git add IMPLEMENTATION_PLAN.md AGENTS.md
git commit -m "plan: <N> items, <M> P0, <T> test items"
```

## Exit Condition
IMPLEMENTATION_PLAN.md exists with at least one item and all items have valid status/priority/acceptance fields. Write at the last line:
```
PHASE_1_COMPLETE
```

## Important
- Don't assume anything is missing — search the codebase first
- Prefer fewer, well-scoped items over many vague ones
- Each item's acceptance criteria should be verifiable by running a test
- The build phase will pick items in priority order, so get priorities right
