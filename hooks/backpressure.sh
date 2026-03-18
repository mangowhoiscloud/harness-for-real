#!/usr/bin/env bash
# Post-tool backpressure hook
# Runs after Write/Edit operations to catch issues early
# Exit 0 = success (silent), Exit 2 = error (agent re-enters to fix)

cd "${CLAUDE_PROJECT_DIR:-.}"

ERRORS=""

# Typecheck
if [ -f "tsconfig.json" ]; then
  OUTPUT=$(npx tsc --noEmit 2>&1) || ERRORS="${ERRORS}\n=== TypeCheck Errors ===\n${OUTPUT}\n"
fi
if [ -f "pyproject.toml" ] && command -v mypy &>/dev/null; then
  OUTPUT=$(mypy . --no-error-summary 2>&1 | head -20) || ERRORS="${ERRORS}\n=== MyPy Errors ===\n${OUTPUT}\n"
fi

# Lint
if [ -f "package.json" ] && grep -q '"lint"' package.json 2>/dev/null; then
  OUTPUT=$(npm run lint 2>&1 | tail -20) || ERRORS="${ERRORS}\n=== Lint Errors ===\n${OUTPUT}\n"
fi
if [ -f "pyproject.toml" ] && command -v ruff &>/dev/null; then
  OUTPUT=$(ruff check . 2>&1 | head -20) || ERRORS="${ERRORS}\n=== Ruff Errors ===\n${OUTPUT}\n"
fi

if [ -n "$ERRORS" ]; then
  echo -e "$ERRORS" >&2
  exit 2
fi

exit 0
