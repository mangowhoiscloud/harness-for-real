#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════╗
# ║  Ralphton Harness — 4-Phase Autonomous Loop                  ║
# ║  Phases: Socratic → Plan → Build → Verify → DONE             ║
# ╚═══════════════════════════════════════════════════════════════╝

# ─── Load shared config ─────────────────────────────────────────
CONFIG_FILE=".harness-config"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# ─── Configuration (env vars override config) ───────────────────
PHASE="${1:-socratic}"
MAX_STUCK="${MAX_STUCK:-5}"
OPUS_MODEL="${OPUS_MODEL:-opus}"
SONNET_MODEL="${SONNET_MODEL:-sonnet}"
PERMISSION_MODE="${PERMISSION_MODE:---dangerously-skip-permissions}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-stream-json}"
BUDGET_USD="${MAX_BUDGET_USD:-0}"
AMBIGUITY_THRESHOLD="${AMBIGUITY_THRESHOLD:-0.10}"
LOG_DIR=".harness-logs"
COST_LOG="$LOG_DIR/cost.log"
PHASE_LOG="$LOG_DIR/phase.log"
STATE_FILE="$LOG_DIR/harness-state.json"

# Pricing from config or defaults
OPUS_INPUT_PRICE="${OPUS_INPUT_PRICE:-0.000015}"
OPUS_OUTPUT_PRICE="${OPUS_OUTPUT_PRICE:-0.000075}"
SONNET_INPUT_PRICE="${SONNET_INPUT_PRICE:-0.000003}"
SONNET_OUTPUT_PRICE="${SONNET_OUTPUT_PRICE:-0.000015}"

# ─── State ───────────────────────────────────────────────────────
ITERATION=0
TOTAL_ITERATION=0
STUCK_COUNT=0
LAST_COMMIT=""
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
ESTIMATED_COST=0
START_TIME=$(date +%s)

# ─── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Setup ───────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$BRANCH" = "unknown" ]; then
  echo -e "${YELLOW}WARNING: Could not detect git branch. Using 'unknown'.${NC}"
fi

# ─── Checkpoint: resume from saved state ─────────────────────────
load_checkpoint() {
  if [ -f "$STATE_FILE" ] && [ "$PHASE" = "socratic" ]; then
    # Only auto-resume if user didn't specify a phase explicitly
    if [ "${2:-}" != "--fresh" ]; then
      local saved_phase saved_iter saved_total
      saved_phase=$(grep -o '"phase":"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | cut -d'"' -f4)
      saved_iter=$(grep -o '"iteration":[0-9]*' "$STATE_FILE" 2>/dev/null | head -1 | cut -d: -f2)
      saved_total=$(grep -o '"total_iteration":[0-9]*' "$STATE_FILE" 2>/dev/null | head -1 | cut -d: -f2)
      if [ -n "$saved_phase" ] && [ "$saved_phase" != "DONE" ]; then
        echo -e "${CYAN}[RESUME] Restoring from checkpoint: phase=$saved_phase iter=$saved_iter${NC}"
        PHASE="$saved_phase"
        ITERATION="${saved_iter:-0}"
        TOTAL_ITERATION="${saved_total:-0}"
      fi
    fi
  fi
}

save_checkpoint() {
  cat > "$STATE_FILE" << CKPT_EOF
{"phase":"$PHASE","iteration":$ITERATION,"total_iteration":$TOTAL_ITERATION,"timestamp":"$(date -Iseconds)","stuck_count":$STUCK_COUNT}
CKPT_EOF
}

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

get_phase_icon() {
  case "$1" in
    socratic) echo "[?]" ;;
    plan)     echo "[P]" ;;
    build)    echo "[B]" ;;
    verify)   echo "[V]" ;;
    *)        echo "[.]" ;;
  esac
}

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
      if [ -f "CLARITY_LOG.md" ]; then
        grep -q "PHASE_0_COMPLETE" CLARITY_LOG.md 2>/dev/null && return 0
        local score
        score=$(grep 'AMBIGUITY_SCORE:' CLARITY_LOG.md 2>/dev/null | tail -1 | sed 's/.*AMBIGUITY_SCORE:[[:space:]]*//' | grep -o '[0-9]*\.[0-9]*' | head -1)
        if [ -n "$score" ]; then
          awk -v s="$score" -v t="$AMBIGUITY_THRESHOLD" 'BEGIN {exit (s < t) ? 0 : 1}' && return 0
        fi
      fi
      return 1
      ;;
    plan)
      if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        grep -q "PHASE_1_COMPLETE" IMPLEMENTATION_PLAN.md 2>/dev/null && return 0
        grep -cq "status:" IMPLEMENTATION_PLAN.md 2>/dev/null && return 0
      fi
      return 1
      ;;
    build)
      if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        local remaining
        remaining=$(grep -c "status: TODO\|status: IN_PROGRESS" IMPLEMENTATION_PLAN.md 2>/dev/null || echo "0")
        [ "$remaining" -eq 0 ] && return 0
      fi
      return 1
      ;;
    verify)
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

  [ "$STUCK_COUNT" -ge "$MAX_STUCK" ] && return 1
  return 0
}

# ─── Circuit breaker recovery (symmetric for all models) ─────────
recover_from_stuck() {
  local model
  model=$(get_model "$PHASE")

  echo -e "${RED}[CIRCUIT BREAKER]${NC} Stuck for $STUCK_COUNT iterations in phase: $PHASE"
  log_phase "CIRCUIT_BREAKER" "Stuck $STUCK_COUNT iterations, phase=$PHASE, model=$model"

  # Step 1: Try escalation (Sonnet→Opus, or Opus with different prompt strategy)
  local recovery_model
  if [ "$model" = "$SONNET_MODEL" ]; then
    recovery_model="$OPUS_MODEL"
    echo -e "${YELLOW}  -> Escalating Sonnet to Opus for recovery${NC}"
  else
    recovery_model="$OPUS_MODEL"
    echo -e "${YELLOW}  -> Retrying with Opus + fresh context${NC}"
  fi

  STUCK_COUNT=0

  # Prepend recovery context to give the agent awareness of the stuck state
  RECOVERY_LOG="$LOG_DIR/recovery_$(date +%Y%m%d_%H%M%S).log"
  {
    echo "RECOVERY MODE: The harness detected $MAX_STUCK consecutive iterations with no git commits in phase '$PHASE'."
    echo "Try a DIFFERENT approach than previous iterations. Check git log and progress.txt for what was already attempted."
    echo "If blocked, document the blocker in progress.txt and exit."
    echo "---"
    cat "PROMPT_${PHASE}.md"
  } | claude -p \
    $PERMISSION_MODE \
    --output-format "$OUTPUT_FORMAT" \
    --model "$recovery_model" \
    --verbose 2>&1 | tee -a "$RECOVERY_LOG" || true

  local new_commit
  new_commit=$(git rev-parse HEAD 2>/dev/null || echo "none")
  if [ "$new_commit" != "$LAST_COMMIT" ]; then
    echo -e "${GREEN}  -> Recovery successful${NC}"
    LAST_COMMIT="$new_commit"
    return 0
  fi

  # Step 2: Force phase transition
  echo -e "${YELLOW}  -> Recovery failed, forcing transition to next phase${NC}"
  local next
  next=$(next_phase "$PHASE")
  if [ "$next" = "DONE" ]; then
    echo -e "${RED}  -> Cannot advance further. Harness stopping.${NC}"
    return 1
  fi
  PHASE="$next"
  ITERATION=0
  STUCK_COUNT=0
  return 0
}

# ─── Cost tracking (reads prices from config) ───────────────────
track_cost() {
  local log_file="$1"
  if [ ! -f "$log_file" ]; then return; fi

  local input_tokens output_tokens
  input_tokens=$(grep '"input_tokens"' "$log_file" 2>/dev/null | tail -1 | sed 's/.*"input_tokens":[[:space:]]*//' | grep -o '[0-9]*' | head -1 || echo "0")
  output_tokens=$(grep '"output_tokens"' "$log_file" 2>/dev/null | tail -1 | sed 's/.*"output_tokens":[[:space:]]*//' | grep -o '[0-9]*' | head -1 || echo "0")

  if [ -z "$input_tokens" ] || [ "$input_tokens" = "0" ]; then return; fi

  TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + input_tokens))
  TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + output_tokens))

  local model price_in price_out iter_cost
  model=$(get_model "$PHASE")
  if [ "$model" = "$OPUS_MODEL" ]; then
    price_in="$OPUS_INPUT_PRICE"
    price_out="$OPUS_OUTPUT_PRICE"
  else
    price_in="$SONNET_INPUT_PRICE"
    price_out="$SONNET_OUTPUT_PRICE"
  fi

  iter_cost=$(awk -v it="$input_tokens" -v pi="$price_in" -v ot="$output_tokens" -v po="$price_out" \
    'BEGIN {printf "%.4f", it * pi + ot * po}' 2>/dev/null || echo "0")
  ESTIMATED_COST=$(awk -v ec="$ESTIMATED_COST" -v ic="$iter_cost" \
    'BEGIN {printf "%.4f", ec + ic}' 2>/dev/null || echo "0")

  echo "$(date -Iseconds) phase=$PHASE iter=$ITERATION model=$model in=$input_tokens out=$output_tokens cost=\$$iter_cost cumulative=\$$ESTIMATED_COST" >> "$COST_LOG"
}

# ─── Budget enforcement ──────────────────────────────────────────
check_budget() {
  if [ "$BUDGET_USD" = "0" ]; then return 0; fi

  # Check if budget exceeded
  if awk -v ec="$ESTIMATED_COST" -v bu="$BUDGET_USD" 'BEGIN {exit (ec >= bu) ? 0 : 1}' 2>/dev/null; then
    echo -e "${RED}[BUDGET] Exceeded \$${BUDGET_USD} budget (spent: \$${ESTIMATED_COST}). Stopping.${NC}"
    log_phase "BUDGET_EXCEEDED" "budget=$BUDGET_USD spent=$ESTIMATED_COST"
    return 1
  fi

  # Warn at 80%
  if awk -v ec="$ESTIMATED_COST" -v bu="$BUDGET_USD" 'BEGIN {exit (ec >= bu * 0.8) ? 0 : 1}' 2>/dev/null; then
    echo -e "${YELLOW}[BUDGET] Warning: \$${ESTIMATED_COST} / \$${BUDGET_USD} (80%+ used)${NC}"
  fi

  return 0
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
  [ -f "$CONFIG_FILE" ] && echo -e "  Config:   ${BOLD}$CONFIG_FILE${NC}"
  echo ""
}

print_iteration_header() {
  local elapsed=$(($(date +%s) - START_TIME))
  local hours=$((elapsed / 3600))
  local minutes=$(( (elapsed % 3600) / 60 ))
  local secs=$((elapsed % 60))
  local icon
  icon=$(get_phase_icon "$PHASE")

  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e " ${icon} Phase: ${BOLD}${PHASE}${NC} | Iter: ${BOLD}${ITERATION}${NC}/$(get_max_iter "$PHASE") | Total: ${BOLD}${TOTAL_ITERATION}${NC} | Stuck: ${STUCK_COUNT}/${MAX_STUCK}"
  echo -e " Time: ${hours}h${minutes}m${secs}s | Model: $(get_model "$PHASE") | Cost: \$${ESTIMATED_COST}"
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

  case "$PHASE" in
    socratic)
      if [ ! -d "specs" ] || [ -z "$(ls -A specs/ 2>/dev/null)" ]; then
        echo -e "${RED}ERROR: specs/ directory is empty. Write your specs first!${NC}"
        exit 1
      fi
      ;;
    plan)
      [ ! -f "CLARITY_LOG.md" ] && echo -e "${YELLOW}WARNING: No CLARITY_LOG.md found.${NC}"
      ;;
    build)
      [ ! -f "IMPLEMENTATION_PLAN.md" ] && echo -e "${YELLOW}WARNING: No IMPLEMENTATION_PLAN.md found.${NC}"
      ;;
  esac
}

# ─── Main ────────────────────────────────────────────────────────
load_checkpoint "$@"
print_banner
validate_phase
log_phase "START" "phase=$PHASE"
LAST_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "none")

while true; do
  # ─── Save checkpoint every iteration ────────────────────────
  save_checkpoint

  # ─── Check phase completion ────────────────────────────────
  if [ "$PHASE" = "DONE" ]; then
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                    HARNESS COMPLETE                       ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    ELAPSED=$(($(date +%s) - START_TIME))
    echo -e "  Total iterations: ${BOLD}${TOTAL_ITERATION}${NC}"
    echo -e "  Total time:       ${BOLD}$((ELAPSED / 3600))h $(( (ELAPSED % 3600) / 60 ))m $((ELAPSED % 60))s${NC}"
    echo -e "  Total tokens:     ${BOLD}in=${TOTAL_INPUT_TOKENS} out=${TOTAL_OUTPUT_TOKENS}${NC}"
    echo -e "  Estimated cost:   ${BOLD}\$${ESTIMATED_COST}${NC}"
    log_phase "COMPLETE" "total_iter=$TOTAL_ITERATION cost=$ESTIMATED_COST"
    rm -f "$STATE_FILE"
    break
  fi

  # ─── Check budget ──────────────────────────────────────────
  if ! check_budget; then
    save_checkpoint
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
    --verbose 2>&1 | tee "$CUR_LOG" || true

  ITERATION=$((ITERATION + 1))
  TOTAL_ITERATION=$((TOTAL_ITERATION + 1))

  # ─── Track cost ─────────────────────────────────────────────
  track_cost "$CUR_LOG"

  # ─── Check transition ──────────────────────────────────────
  if should_transition; then
    NEXT_P=$(next_phase "$PHASE")
    echo -e "${GREEN}[TRANSITION] ${PHASE} -> ${NEXT_P}${NC}"
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
      save_checkpoint
      break
    fi
    continue
  fi

  # ─── Push changes ──────────────────────────────────────────
  git push origin "$BRANCH" 2>/dev/null || true

done

echo ""
echo -e "${BOLD}Logs:  $LOG_DIR/${NC}"
echo -e "${BOLD}Cost:  cat $COST_LOG${NC}"
echo -e "${BOLD}State: cat $STATE_FILE${NC}"
