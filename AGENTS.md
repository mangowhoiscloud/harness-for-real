# Operational Guide

## How to Run
<!-- init.sh will populate these -->
```bash
# Start dev server
# Run tests
# Run lint
# Run typecheck
```

## Architecture Decisions
<!-- Updated by agents during build phase -->

## Patterns to Follow
- Single source of truth: no adapters, no migrations
- Test-first: write test → implement → verify
- Atomic commits: one logical change per commit

## Anti-Patterns
- Don't duplicate utilities — check src/lib/ first
- Don't modify test assertions to make tests pass
- Don't leave console.log/print debugging statements
