#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════╗
# ║  Ralphton Harness — Environment Bootstrap                    ║
# ║  Detects project type and configures build/test commands      ║
# ╚═══════════════════════════════════════════════════════════════╝

echo "=== Ralphton Harness Init ==="

# ─── Git init ────────────────────────────────────────────────────
if [ ! -d ".git" ]; then
  echo "[init] Initializing git repository..."
  git init
  git add -A
  git commit -m "init: project bootstrap" --allow-empty
fi

# ─── Detect project type ────────────────────────────────────────
PROJECT_TYPE="unknown"
BUILD_CMD=""
TEST_CMD=""
LINT_CMD=""
TYPECHECK_CMD=""

if [ -f "package.json" ]; then
  PROJECT_TYPE="node"
  # Detect package manager
  if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
    PKG_MGR="bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    PKG_MGR="pnpm"
  elif [ -f "yarn.lock" ]; then
    PKG_MGR="yarn"
  else
    PKG_MGR="npm"
  fi

  BUILD_CMD="$PKG_MGR run build"
  TEST_CMD="$PKG_MGR test"
  LINT_CMD="$PKG_MGR run lint"

  # Check for TypeScript
  if [ -f "tsconfig.json" ]; then
    TYPECHECK_CMD="npx tsc --noEmit"
  fi

elif [ -f "pyproject.toml" ]; then
  PROJECT_TYPE="python-uv"
  BUILD_CMD="uv build"
  TEST_CMD="uv run pytest"
  LINT_CMD="uv run ruff check ."
  TYPECHECK_CMD="uv run mypy ."

elif [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
  PROJECT_TYPE="python-pip"
  BUILD_CMD="pip install -e ."
  TEST_CMD="pytest"
  LINT_CMD="ruff check . 2>/dev/null || flake8 ."
  TYPECHECK_CMD="mypy . 2>/dev/null || true"

elif [ -f "Cargo.toml" ]; then
  PROJECT_TYPE="rust"
  BUILD_CMD="cargo build"
  TEST_CMD="cargo test"
  LINT_CMD="cargo clippy -- -D warnings"
  TYPECHECK_CMD="cargo check"

elif [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
  BUILD_CMD="go build ./..."
  TEST_CMD="go test ./..."
  LINT_CMD="golangci-lint run"
  TYPECHECK_CMD="go vet ./..."

elif [ -f "pom.xml" ]; then
  PROJECT_TYPE="java-maven"
  BUILD_CMD="mvn compile"
  TEST_CMD="mvn test"
  LINT_CMD="mvn checkstyle:check 2>/dev/null || true"
  TYPECHECK_CMD="mvn compile"

elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  PROJECT_TYPE="java-gradle"
  BUILD_CMD="./gradlew build"
  TEST_CMD="./gradlew test"
  LINT_CMD="./gradlew check"
  TYPECHECK_CMD="./gradlew compileJava"
fi

echo "[init] Detected project type: $PROJECT_TYPE"

# ─── Update CLAUDE.md with detected commands ─────────────────────
if [ -f "CLAUDE.md" ]; then
  sed -i.bak "s|<!-- HARNESS:BUILD_CMD=.* -->|<!-- HARNESS:BUILD_CMD=$BUILD_CMD -->|" CLAUDE.md
  sed -i.bak "s|<!-- HARNESS:TEST_CMD=.* -->|<!-- HARNESS:TEST_CMD=$TEST_CMD -->|" CLAUDE.md
  sed -i.bak "s|<!-- HARNESS:LINT_CMD=.* -->|<!-- HARNESS:LINT_CMD=$LINT_CMD -->|" CLAUDE.md
  sed -i.bak "s|<!-- HARNESS:TYPECHECK_CMD=.* -->|<!-- HARNESS:TYPECHECK_CMD=$TYPECHECK_CMD -->|" CLAUDE.md
  rm -f CLAUDE.md.bak
  echo "[init] Updated CLAUDE.md with build commands"
fi

# ─── Update AGENTS.md with commands ──────────────────────────────
if [ -f "AGENTS.md" ]; then
  cat > AGENTS.md << AGENTS_EOF
# Operational Guide

## How to Run
\`\`\`bash
# Build
$BUILD_CMD

# Run tests
$TEST_CMD

# Lint
$LINT_CMD

# Typecheck
$TYPECHECK_CMD
\`\`\`

## Project Type
$PROJECT_TYPE

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
AGENTS_EOF
  echo "[init] Updated AGENTS.md with commands"
fi

# ─── Create initial files ───────────────────────────────────────
if [ ! -f "progress.txt" ]; then
  echo "=== Harness initialized: $(date -Iseconds) ===" > progress.txt
  echo "Project type: $PROJECT_TYPE" >> progress.txt
  echo "[init] Created progress.txt"
fi

# ─── Create specs directory ──────────────────────────────────────
mkdir -p specs
if [ -z "$(ls -A specs/ 2>/dev/null)" ]; then
  echo "[init] WARNING: specs/ is empty. Write your specs before running the harness!"
  echo "  Example: specs/my-feature.md"
fi

# ─── Write backpressure hooks ────────────────────────────────────
mkdir -p hooks

cat > hooks/backpressure.sh << 'HOOK_EOF'
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
HOOK_EOF
chmod +x hooks/backpressure.sh

cat > hooks/pre-commit-gate.sh << 'HOOK_EOF'
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
SKIP_MARKERS=$(grep -rn "it\.skip\|describe\.skip\|@pytest\.mark\.skip\|#.*noqa.*skip" src/ tests/ 2>/dev/null | head -5)
if [ -n "$SKIP_MARKERS" ]; then
  echo "[gate] WARNING: Skipped tests found:" >&2
  echo "$SKIP_MARKERS" >&2
fi

echo "[gate] All checks passed"
exit 0
HOOK_EOF
chmod +x hooks/pre-commit-gate.sh

echo "[init] Created hook scripts"

# ─── Create log directory ────────────────────────────────────────
mkdir -p .harness-logs
echo "[init] Created .harness-logs/"

# ─── .gitignore for harness ─────────────────────────────────────
if ! grep -q ".harness-logs" .gitignore 2>/dev/null; then
  echo ".harness-logs/" >> .gitignore
  echo "[init] Added .harness-logs/ to .gitignore"
fi

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "=== Init Complete ==="
echo "  Project:    $PROJECT_TYPE"
echo "  Build:      $BUILD_CMD"
echo "  Test:       $TEST_CMD"
echo "  Lint:       $LINT_CMD"
echo "  Typecheck:  $TYPECHECK_CMD"
echo ""
echo "Next steps:"
echo "  1. Write specs in specs/ directory"
echo "  2. Run: bash loop.sh"
echo "     (or: bash loop.sh socratic|plan|build|verify)"
