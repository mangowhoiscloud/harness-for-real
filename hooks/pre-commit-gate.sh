#!/usr/bin/env bash
# Pre-commit gate — blocks commits with failing tests
# Exit 0 = allow commit, Exit 2 = block (agent must fix)

cd "${CLAUDE_PROJECT_DIR:-.}"

echo "[gate] Running pre-commit checks..."

# Run tests
if [ -f "package.json" ]; then
  npm test 2>&1 || { echo "[gate] Tests failed" >&2; exit 2; }
elif [ -f "pyproject.toml" ]; then
  uv run pytest 2>&1 || { echo "[gate] Tests failed" >&2; exit 2; }
elif [ -f "Cargo.toml" ]; then
  cargo test 2>&1 || { echo "[gate] Tests failed" >&2; exit 2; }
elif [ -f "go.mod" ]; then
  go test ./... 2>&1 || { echo "[gate] Tests failed" >&2; exit 2; }
fi

# Check for skip markers
SKIP_MARKERS=$(grep -rn "it\.skip\|describe\.skip\|@pytest\.mark\.skip" src/ tests/ 2>/dev/null | head -5)
if [ -n "$SKIP_MARKERS" ]; then
  echo "[gate] WARNING: Skipped tests found:" >&2
  echo "$SKIP_MARKERS" >&2
fi

echo "[gate] All checks passed"
exit 0
