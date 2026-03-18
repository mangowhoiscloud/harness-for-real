# harness-for-real

**A competition-grade autonomous harness for Ralphton and AI agent hackathons.**

Your AI writes 100,000 lines of code while you sleep. This harness makes sure it writes the *right* code.

```
                    ┌─────────────┐
                    │  You write   │
                    │    specs     │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │    Phase 0: Socratic     │  Opus
              │  133+ Q&A rounds         │  "Is the spec clear enough?"
              │  Ambiguity → 0.05        │
              └────────────┬────────────┘
                           │ auto-transition when ambiguity < 0.10
              ┌────────────▼────────────┐
              │    Phase 1: Plan         │  Opus
              │  Analyze specs + code    │  "What needs to be built?"
              │  → IMPLEMENTATION_PLAN   │
              └────────────┬────────────┘
                           │ auto-transition when plan exists
              ┌────────────▼────────────┐
              │    Phase 2: Build        │  Sonnet (5x cheaper)
              │  1 item per iteration    │  "Build, test, commit."
              │  70% test code target    │
              └────────────┬────────────┘
                           │ auto-transition when all items DONE
              ┌────────────▼────────────┐
              │    Phase 3: Verify       │  Opus
              │  3-agent validation      │  "Does it actually work?"
              │  Validator+Coordinator   │
              │  +Packer                 │
              └────────────┬────────────┘
                           │
                     ┌─────▼─────┐
                     │   DONE    │
                     └───────────┘
```

---

## What is this?

This is a **harness** — a control structure that makes AI coding agents work reliably over long autonomous runs. Think of it as a flight computer for Claude Code: it handles navigation, course correction, and safety systems so the AI can focus on building.

### Background: Ralphton

[Ralphton](https://briandwjang.substack.com/p/8d3) is a new kind of hackathon where **humans design and AI agents code autonomously**. At Korea's first Ralphton (Feb 2026), the winning team:

- Had their AI write **100,000 lines of code**
- **70% was test code** (the AI verified its own work)
- Ran **133 rounds of Socratic Q&A** before coding to eliminate spec ambiguity
- Touched the keyboard **zero times** during the autonomous phase

This harness encodes those winning patterns into a reusable system.

### Why not just run `while true; do cat PROMPT.md | claude -p; done`?

That's the [original Ralph loop](https://ghuntley.com/ralph/) — and it works for small tasks. But for competition-scale projects, you need:

| Problem | Basic Ralph | This Harness |
|---------|------------|--------------|
| Spec ambiguity causes wrong code | Manual specs | Automated Socratic phase eliminates ambiguity |
| Agent gets stuck in a loop | Runs forever | Circuit breaker detects + recovers |
| Expensive API costs | One model for everything | Opus for thinking, Sonnet for building (5x savings) |
| Premature "I'm done!" | No detection | Dual-condition exit (marker + plan check) |
| No quality gates | Hope for the best | Hooks enforce typecheck + lint + tests |
| Manual phase switching | `./loop.sh plan` then `./loop.sh build` | Automatic phase transitions |
| Can't watch progress | Read logs | Real-time monitoring dashboard |

---

## Quick Start

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Git
- A project idea with specs

### 1. Clone

```bash
git clone https://github.com/mangowhoiscloud/harness-for-real.git
cd harness-for-real
```

### 2. Write your specs

Create spec files in the `specs/` directory. Each spec should describe one feature or concern:

```bash
# Good: one concern per file
specs/user-authentication.md
specs/data-model.md
specs/api-endpoints.md
specs/error-handling.md

# Bad: everything in one file
specs/everything.md
```

**The "one sentence test"**: if you need the word "and" to describe what a spec covers, split it into multiple files.

### 3. Initialize

```bash
bash init.sh
```

This auto-detects your project type (Node/Python/Rust/Go/Java) and configures build commands.

### 4. Run

```bash
bash loop.sh
```

That's it. The harness takes over from here:
- **Socratic phase** clarifies your specs (up to 150 rounds)
- **Plan phase** creates `IMPLEMENTATION_PLAN.md`
- **Build phase** implements one item per iteration with tests
- **Verify phase** runs 3-agent validation

### 5. Monitor (optional)

In a separate terminal:

```bash
bash scripts/monitor.sh
```

Shows real-time progress: current phase, items completed, ambiguity score, cost tracking.

---

## How It Works

### The Core Loop

```bash
while true; do
  cat PROMPT_${PHASE}.md | claude -p --model $MODEL --dangerously-skip-permissions
  # Check: should we transition to the next phase?
  # Check: is the agent stuck? (circuit breaker)
  # Push changes to git
done
```

Each iteration:
1. Starts with a **fresh context window** (no accumulated confusion)
2. Reads state from **files** (progress.txt, IMPLEMENTATION_PLAN.md, git history)
3. Does **one unit of work**
4. Persists results to **files + git**
5. Exits cleanly

The key insight: **memory lives in the filesystem, not the context window**. This lets the agent work for hours without degrading.

### Phase Transitions

Transitions happen automatically when conditions are met:

| From | To | Condition |
|------|-----|-----------|
| Socratic | Plan | `AMBIGUITY_SCORE < 0.10` in CLARITY_LOG.md |
| Plan | Build | IMPLEMENTATION_PLAN.md exists with items |
| Build | Verify | No `status: TODO` or `status: IN_PROGRESS` in plan |
| Verify | DONE | `HARNESS_COMPLETE` marker in progress.txt |
| Verify | Build | Verification failures → new items added to plan |

### Circuit Breaker

If the agent produces **no git commits for 5 consecutive iterations**:

1. If running Sonnet → escalate to Opus for one recovery attempt
2. If already Opus → force-transition to the next phase
3. If no next phase → stop and report

This prevents burning API credits on a stuck loop.

### Backpressure

Two hooks automatically enforce quality:

**`hooks/backpressure.sh`** — runs after every Write/Edit:
- Typecheck (tsc, mypy, cargo check, go vet)
- Lint (eslint, ruff, clippy, golangci-lint)
- Fails → agent automatically fixes the issue

**`hooks/pre-commit-gate.sh`** — runs before every commit:
- Full test suite must pass
- No skipped tests (it.skip, @pytest.mark.skip)
- Fails → agent must fix before committing

### Model Routing

| Phase | Model | Why |
|-------|-------|-----|
| Socratic | Opus | Deep reasoning for ambiguity analysis |
| Plan | Opus | Architecture decisions need careful thought |
| Build | Sonnet | Implementation is well-specified; speed + cost matter |
| Verify | Opus | Final validation needs thoroughness |

Estimated **5x cost reduction** vs. using Opus for everything.

---

## File Structure

```
harness-for-real/
├── loop.sh                 # Main orchestrator — 4-phase FSM
├── init.sh                 # Environment bootstrap (auto-detects project type)
├── CLAUDE.md               # Project rules (loaded every Claude session)
├── AGENTS.md               # Operational guide (<60 lines)
│
├── PROMPT_socratic.md      # Phase 0: Eliminate spec ambiguity
├── PROMPT_plan.md          # Phase 1: Generate implementation plan
├── PROMPT_build.md         # Phase 2: Build one item per iteration
├── PROMPT_verify.md        # Phase 3: 3-agent final verification
│
├── hooks/
│   ├── backpressure.sh     # Post-tool: typecheck + lint
│   └── pre-commit-gate.sh  # Pre-commit: test suite gate
│
├── scripts/
│   └── monitor.sh          # Live progress dashboard
│
├── specs/                  # Your spec files go here
│   └── .gitkeep
│
├── examples/
│   └── word-counter/       # Demo: Python CLI word frequency analyzer
│       ├── specs/
│       └── run-demo.sh
│
└── RESEARCH.md             # Full research behind the design
```

### Files the harness creates during execution

```
CLARITY_LOG.md              # Socratic Q&A rounds + ambiguity scores
IMPLEMENTATION_PLAN.md      # Prioritized task list with statuses
progress.txt                # Session-by-session progress log
.harness-logs/              # Per-iteration logs, cost tracking
```

---

## Configuration

All configuration is via environment variables:

```bash
# Phase iteration limits
MAX_SOCRATIC=150    # Default: 150 (winning team did 133)
MAX_PLAN=10         # Default: 10
MAX_BUILD=999       # Default: 999 (unlimited, circuit-breaker protected)
MAX_VERIFY=20       # Default: 20

# Circuit breaker
MAX_STUCK=5         # Consecutive no-progress iterations before recovery

# Model override
OPUS_MODEL=opus     # Or a specific model ID
SONNET_MODEL=sonnet

# Permission mode
PERMISSION_MODE="--dangerously-skip-permissions"  # For headless autonomous mode

# Output format
OUTPUT_FORMAT=stream-json  # For cost tracking; use "text" for simpler output
```

### Start from a specific phase

```bash
bash loop.sh socratic   # Full run (default)
bash loop.sh plan       # Skip socratic, start from planning
bash loop.sh build      # Skip to building (if you have a plan)
bash loop.sh verify     # Skip to verification (if build is done)
```

### Quick test with reduced iterations

```bash
MAX_SOCRATIC=3 MAX_PLAN=2 MAX_BUILD=10 MAX_VERIFY=2 bash loop.sh
```

---

## Examples

### Word Counter CLI (Python)

A minimal demo to see the harness in action:

```bash
cd examples/word-counter
bash run-demo.sh
```

Creates a Python word frequency analyzer from 2 spec files. Uses reduced iterations for a quick run.

### REODE Migration Target (Java)

A Java 1.8 + Spring Framework 4.3.4 legacy codebase for migration testing:

```bash
cd examples/reode-migration-target
bash run-demo.sh
```

Generates a realistic legacy Java project with intentional anti-patterns (circular dependencies, XML config, field injection) that migration tools can practice on.

---

## The Winning Formula

Based on analysis of the Ralphton winning team:

### 1. Minimize Ambiguity First

> The winning team ran 133 rounds of Socratic reasoning before writing a single line of code. Their ambiguity score dropped to 0.05.

The Socratic phase is the highest-leverage investment. Spending 30 minutes of compute clarifying specs saves hours of wrong implementation.

### 2. Test Everything

> 70,000 of 100,000 lines were test code.

The `PROMPT_build.md` targets 70% test code. Tests are the agent's self-verification mechanism — without them, errors compound across iterations.

### 3. One Item Per Iteration

> Each iteration handles exactly one task from the plan.

Scope creep is the #1 killer of autonomous loops. The harness enforces single-item iterations with fresh context.

### 4. Optimize Cost

> The 3rd-place team learned: expensive models early, cheap models later.

Opus for reasoning (Socratic, Plan, Verify), Sonnet for implementation (Build). Same quality, ~5x less cost.

### 5. Zero Keyboard Touch

> The winning team didn't touch the keyboard once during the autonomous phase.

If you're touching the keyboard, your harness isn't good enough. Fix the harness, not the code.

---

## How is this different from...

### [ghuntley/how-to-ralph-wiggum](https://github.com/ghuntley/how-to-ralph-wiggum)

The definitive Ralph playbook. This harness builds on it and adds:
- Automated Socratic pre-phase (ghuntley's Phase 1 is manual spec writing)
- Automatic phase transitions (ghuntley requires manual mode switching)
- Circuit breaker (not in the playbook)
- 3-agent verification phase

### [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)

Excellent Claude Code plugin with circuit breaker and exit detection. This harness differs by:
- 4-phase architecture (vs. single-phase loop)
- Socratic reasoning phase
- Model routing (Opus/Sonnet)
- Built as standalone scripts (no plugin installation needed)

### [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)

Plan→Work→Review→Release cycle with TypeScript guardrails. This harness:
- Adds Socratic pre-phase
- Uses bash (zero dependencies, works anywhere)
- Cost-optimized model routing
- Designed specifically for competition (Ralphton) context

---

## Research

See [RESEARCH.md](./RESEARCH.md) for the full research behind this harness, including:
- Ralphton winning team analysis
- Ralph loop history and evolution
- Harness engineering principles (Anthropic, HumanLayer, LangChain, OpenAI)
- Tool comparison matrix
- Industry benchmarks (Stripe Minions, OpenAI Codex, LangChain Terminal Bench)

---

## Acknowledgments

Built on the shoulders of:
- [Geoffrey Huntley](https://ghuntley.com/ralph/) — inventor of the Ralph loop
- [Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — long-running agent research
- [HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) — harness engineering best practices
- [Team Attention + Kakao Ventures](https://briandwjang.substack.com/p/8d3) — organizing Korea's first Ralphton
- The winning Ralphton team — proving that Socratic reasoning + 70% tests + zero keyboard = victory

---

## License

MIT
