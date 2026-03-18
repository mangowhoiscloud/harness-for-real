#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════╗
# ║  Ralphton Harness — 4-Phase Autonomous Loop                  ║
# ║  Phases: Socratic → Plan → Build → Verify → DONE             ║
# ╚═══════════════════════════════════════════════════════════════╝

# ─── Configuration ───────────────────────────────────────────────
PHASE="${1:-socratic}"          # Starting phase: socratic|plan|build|verify
MAX_STUCK="${MAX_STUCK:-5}"     # Circuit breaker: consecutive no-progress iterations
OPUS_MODEL="opus"
SONNET_MODEL="sonnet"
PERMISSION_MODE="${PERMISSION_MODE:---dangerously-skip-permissions}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-stream-json}"
BUDGET_USD="${MAX_BUDGET_USD:-0}"  # 0 = unlimited
LOG_DIR=".harness-logs"
COST_LOG="$LOG_DIR/cost.log"
PHASE_LOG="$LOG_DIR/phase.log"

# ─── State ───────────────────────────────────────────────────────
ITERATION=0
TOTAL_ITERATION=0
STUCK_COUNT=0
LAST_COMMIT=""
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
START_TIME=$(date +%s)

# ─── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Setup ───────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

# ─── Phase → Model mapping ──────────────────────────────────────
get_model() {
  case "$1" in
    socratic) echo "$OPUS_MODEL" ;;
    plan)     echo "$OPUS_MODEL" ;;
    build)    echo "$SONNET_MODEL" ;;
    verify)   echo "$OPUS_MODEL" ;;
    *)        echo "$SONNET_MODEL" ;;
  esac
}

# ─── Phase → Max iterations ─────────────────────────────────────
get_max_iter() {
  case "$1" in
    socratic) echo "${MAX_SOCRATIC:-150}" ;;
    plan)     echo "${MAX_PLAN:-10}" ;;
    build)    echo "${MAX_BUILD:-999}" ;;
    verify)   echo "${MAX_VERIFY:-20}" ;;
    *)        echo 10 ;;
  esac
}

# ─── Phase → Display emoji ──────────────────────────────────────
get_phase_icon() {
  case "$1" in
    socratic) echo "[?]" ;;
    plan)     echo "[P]" ;;
    build)    echo "[B]" ;;
    verify)   echo "[V]" ;;
    *)        echo "[.]" ;;
  esac
}

# ─── Next phase ──────────────────────────────────────────────────
next_phase() {
  case "$1" in
    socratic) echo "plan" ;;
    plan)     echo "build" ;;
    build)    echo "verify" ;;
    verify)   echo "DONE" ;;
    *)        echo "DONE" ;;
  esac
}

# ─── Transition conditions ───────────────────────────────────────
should_transition() {
  case "$PHASE" in
    socratic)
      # Transition when ambiguity score < 0.10 or PHASE_0_COMPLETE marker
      if [ -f "CLARITY_LOG.md" ]; then
        grep -q "PHASE_0_COMPLETE" CLARITY_LOG.md 2>/dev/null && return 0
        # Check if ambiguity score is below threshold
        local score
        score=$(grep 'AMBIGUITY_SCORE:' CLARITY_LOG.md 2>/dev/null | tail -1 | sed 's/.*AMBIGUITY_SCORE:[[:space:]]*//' | grep -o '[0-9.]*')
        if [ -n "$score" ]; then
          echo "$score" | awk '{exit ($1 < 0.10) ? 0 : 1}' && return 0
        fi
      fi
      return 1
      ;;
    plan)
      # Transition when IMPLEMENTATION_PLAN.md exists with items
      if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        grep -q "PHASE_1_COMPLETE" IMPLEMENTATION_PLAN.md 2>/dev/null && return 0
        # At least one item exists with status field
        grep -cq "status:" IMPLEMENTATION_PLAN.md 2>/dev/null && return 0
      fi
      return 1
      ;;
    build)
      # Transition when no TODO or IN_PROGRESS items remain
      if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        # Check for remaining work
        local remaining
        remaining=$(grep -c "status: TODO\|status: IN_PROGRESS" IMPLEMENTATION_PLAN.md 2>/dev/null || echo "0")
        [ "$remaining" -eq 0 ] && return 0
      fi
      return 1
      ;;
    verify)
      # Transition when HARNESS_COMPLETE marker exists
      [ -f "progress.txt" ] && grep -q "HARNESS_COMPLETE" progress.txt 2>/dev/null && return 0
      return 1
      ;;
  esac
  return 1
}

# ─── Circuit breaker ────────────────────────────────────────────
check_circuit_breaker() {
  local current_commit
  current_commit=$(git rev-parse HEAD 2>/dev/null || echo "none")

  if [ "$current_commit" = "$LAST_COMMIT" ]; then
    STUCK_COUNT=$((STUCK_COUNT + 1))
  else
    STUCK_COUNT=0
    LAST_COMMIT="$current_commit"
  fi

  if [ "$STUCK_COUNT" -ge "$MAX_STUCK" ]; then
    return 1  # Circuit tripped
  fi
  return 0
}

# ─── Circuit breaker recovery ────────────────────────────────────
recover_from_stuck() {
  local model
  model=$(get_model "$PHASE")

  echo -e "${RED}[CIRCUIT BREAKER]${NC} Stuck for $STUCK_COUNT iterations in phase: $PHASE"
  log_phase "CIRCUIT_BREAKER" "Stuck $STUCK_COUNT iterations, phase=$PHASE"

  if [ "$model" = "$SONNET_MODEL" ]; then
    # Escalate to Opus for one recovery iteration
    echo -e "${YELLOW}  → Escalating to Opus for recovery iteration${NC}"
    RECOVERY_MODEL="$OPUS_MODEL"
    STUCK_COUNT=0

    cat "PROMPT_${PHASE}.md" | claude -p \
      $PERMISSION_MODE \
      --output-format "$OUTPUT_FORMAT" \
      --model "$RECOVERY_MODEL" \
      --verbose 2>&1 | tee -a "$LOG_DIR/recovery_$(date +%Y%m%d_%H%M%S).log"

    # Check if recovery helped
    local new_commit
    new_commit=$(git rev-parse HEAD 2>/dev/null || echo "none")
    if [ "$new_commit" != "$LAST_COMMIT" ]; then
      echo -e "${GREEN}  → Recovery successful, progress made${NC}"
      LAST_COMMIT="$new_commit"
      return 0
    fi
  fi

  # If still stuck (or was already Opus), force phase transition
  echo -e "${YELLOW}  → Forcing transition to next phase${NC}"
  local next
  next=$(next_phase "$PHASE")
  if [ "$next" = "DONE" ]; then
    echo -e "${RED}  → Cannot advance further. Harness stopping.${NC}"
    return 1
  fi
  PHASE="$next"
  ITERATION=0
  STUCK_COUNT=0
  return 0
}

# ─── Cost tracking ───────────────────────────────────────────────
track_cost() {
  local log_file="$1"
  # Extract token usage from stream-json output (if available)
  if [ -f "$log_file" ]; then
    local input_tokens output_tokens
    input_tokens=$(grep '"input_tokens"' "$log_file" 2>/dev/null | tail -1 | sed 's/.*"input_tokens":[[:space:]]*//' | grep -o '[0-9]*' | head -1 || echo "0")
    output_tokens=$(grep '"output_tokens"' "$log_file" 2>/dev/null | tail -1 | sed 's/.*"output_tokens":[[:space:]]*//' | grep -o '[0-9]*' | head -1 || echo "0")

    if [ -n "$input_tokens" ] && [ "$input_tokens" -gt 0 ]; then
      TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + input_tokens))
      TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + output_tokens))

      local model cost_input cost_output
      model=$(get_model "$PHASE")
      if [ "$model" = "$OPUS_MODEL" ]; then
        cost_input=$(echo "$input_tokens * 0.000015" | bc 2>/dev/null || echo "?")
        cost_output=$(echo "$output_tokens * 0.000075" | bc 2>/dev/null || echo "?")
      else
        cost_input=$(echo "$input_tokens * 0.000003" | bc 2>/dev/null || echo "?")
        cost_output=$(echo "$output_tokens * 0.000015" | bc 2>/dev/null || echo "?")
      fi

      echo "$(date -Iseconds) phase=$PHASE iter=$ITERATION in=$input_tokens out=$output_tokens cost_in=$cost_input cost_out=$cost_output" >> "$COST_LOG"
    fi
  fi
}

# ─── Phase logging ───────────────────────────────────────────────
log_phase() {
  echo "$(date -Iseconds) event=$1 $2" >> "$PHASE_LOG"
}

# ─── Banner ──────────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║          RALPHTON HARNESS — Autonomous Loop              ║${NC}"
  echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo -e "  Phase:    ${BOLD}$PHASE${NC}"
  echo -e "  Model:    ${BOLD}$(get_model "$PHASE")${NC}"
  echo -e "  Branch:   ${BOLD}$BRANCH${NC}"
  echo -e "  Max iter: ${BOLD}$(get_max_iter "$PHASE")${NC}"
  echo -e "  Stuck:    ${BOLD}$MAX_STUCK${NC} (circuit breaker)"
  [ "$BUDGET_USD" != "0" ] && echo -e "  Budget:   ${BOLD}\$${BUDGET_USD}${NC}"
  echo ""
}

# ─── Iteration display ──────────────────────────────────────────
print_iteration_header() {
  local elapsed=$(($(date +%s) - START_TIME))
  local hours=$((elapsed / 3600))
  local minutes=$(( (elapsed % 3600) / 60 ))
  local icon
  icon=$(get_phase_icon "$PHASE")

  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e " ${icon} Phase: ${BOLD}${PHASE}${NC} | Iter: ${BOLD}${ITERATION}${NC}/$( get_max_iter "$PHASE") | Total: ${BOLD}${TOTAL_ITERATION}${NC} | Stuck: ${STUCK_COUNT}/${MAX_STUCK}"
  echo -e " Time: ${hours}h ${minutes}m | Model: $(get_model "$PHASE")"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo ""
}

# ─── Validate prerequisites ──────────────────────────────────────
validate_phase() {
  local prompt_file="PROMPT_${PHASE}.md"
  if [ ! -f "$prompt_file" ]; then
    echo -e "${RED}ERROR: $prompt_file not found${NC}"
    exit 1
  fi

  # Phase-specific prerequisite checks
  case "$PHASE" in
    socratic)
      if [ ! -d "specs" ] || [ -z "$(ls -A specs/ 2>/dev/null)" ]; then
        echo -e "${RED}ERROR: specs/ directory is empty. Write your specs first!${NC}"
        echo "  Create files like: specs/feature-name.md"
        echo "  Each spec should pass the 'one sentence test'"
        exit 1
      fi
      ;;
    plan)
      if [ ! -f "CLARITY_LOG.md" ]; then
        echo -e "${YELLOW}WARNING: No CLARITY_LOG.md found. Starting plan without Socratic phase.${NC}"
      fi
      ;;
    build)
      if [ ! -f "IMPLEMENTATION_PLAN.md" ]; then
        echo -e "${YELLOW}WARNING: No IMPLEMENTATION_PLAN.md found. Starting build without plan.${NC}"
      fi
      ;;
  esac
}

# ─── Main loop ───────────────────────────────────────────────────
print_banner
validate_phase
log_phase "START" "phase=$PHASE"

# Initialize last commit
LAST_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "none")

while true; do
  # ─── Check phase completion ────────────────────────────────
  if [ "$PHASE" = "DONE" ]; then
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                    HARNESS COMPLETE                       ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    ELAPSED=$(($(date +%s) - START_TIME))
    echo -e "  Total iterations: ${BOLD}${TOTAL_ITERATION}${NC}"
    echo -e "  Total time:       ${BOLD}$((ELAPSED / 3600))h $(( (ELAPSED % 3600) / 60 ))m${NC}"
    echo -e "  Total tokens:     ${BOLD}in=${TOTAL_INPUT_TOKENS} out=${TOTAL_OUTPUT_TOKENS}${NC}"
    log_phase "COMPLETE" "total_iter=$TOTAL_ITERATION"
    break
  fi

  # ─── Check iteration limit ─────────────────────────────────
  MAX_ITER_CUR=$(get_max_iter "$PHASE")
  if [ "$ITERATION" -ge "$MAX_ITER_CUR" ]; then
    echo -e "${YELLOW}[MAX ITER] Reached $MAX_ITER_CUR iterations in phase: $PHASE${NC}"
    log_phase "MAX_ITER" "phase=$PHASE iter=$ITERATION"
    PHASE=$(next_phase "$PHASE")
    ITERATION=0
    STUCK_COUNT=0
    validate_phase
    continue
  fi

  # ─── Print header ──────────────────────────────────────────
  print_iteration_header

  # ─── Run Claude ─────────────────────────────────────────────
  CUR_MODEL=$(get_model "$PHASE")
  CUR_PROMPT="PROMPT_${PHASE}.md"
  CUR_LOG="$LOG_DIR/${PHASE}_iter${ITERATION}_$(date +%Y%m%d_%H%M%S).log"

  cat "$CUR_PROMPT" | claude -p \
    $PERMISSION_MODE \
    --output-format "$OUTPUT_FORMAT" \
    --model "$CUR_MODEL" \
    --verbose 2>&1 | tee "$CUR_LOG"

  ITERATION=$((ITERATION + 1))
  TOTAL_ITERATION=$((TOTAL_ITERATION + 1))

  # ─── Track cost ─────────────────────────────────────────────
  track_cost "$CUR_LOG"

  # ─── Check transition ──────────────────────────────────────
  if should_transition; then
    NEXT_P=$(next_phase "$PHASE")
    echo -e "${GREEN}[TRANSITION] ${PHASE} → ${NEXT_P}${NC}"
    log_phase "TRANSITION" "from=$PHASE to=$NEXT_P iter=$ITERATION"
    PHASE="$NEXT_P"
    ITERATION=0
    STUCK_COUNT=0
    if [ "$PHASE" != "DONE" ]; then
      validate_phase
    fi
    continue
  fi

  # ─── Circuit breaker ───────────────────────────────────────
  if ! check_circuit_breaker; then
    if ! recover_from_stuck; then
      echo -e "${RED}[HARNESS] Unable to recover. Stopping.${NC}"
      log_phase "ABORT" "unrecoverable stuck"
      break
    fi
    continue
  fi

  # ─── Push changes ──────────────────────────────────────────
  git push origin "$BRANCH" 2>/dev/null || true

done

echo ""
echo -e "${BOLD}Logs: $LOG_DIR/${NC}"
echo -e "${BOLD}Cost: cat $COST_LOG${NC}"
