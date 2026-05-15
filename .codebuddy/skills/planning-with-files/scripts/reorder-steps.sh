#!/usr/bin/env bash
# reorder-steps.sh - Reorder steps within an existing plan
# Usage: ./reorder-steps.sh <plan-id> <step-number> <new-position>

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
PLANS_DIR="${PLANS_DIR:-./plans}"
SCRIPT_NAME="$(basename "$0")"

# ── Helpers ──────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <plan-id> <step-number> <new-position>

Reorder a step within an existing plan by moving it to a new position.
All other steps are renumbered automatically.

Arguments:
  plan-id       The unique identifier of the plan (e.g. plan-20240101-abc123)
  step-number   The current 1-based step number to move
  new-position  The target 1-based position to move the step to

Environment:
  PLANS_DIR     Directory where plan files are stored (default: ./plans)

Examples:
  $SCRIPT_NAME plan-20240101-abc123 3 1   # Move step 3 to position 1
  $SCRIPT_NAME plan-20240101-abc123 1 4   # Move step 1 to position 4
EOF
  exit 1
}

err() { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }

# ── Argument validation ───────────────────────────────────────────────────────
[[ $# -lt 3 ]] && usage

PLAN_ID="$1"
STEP_NUM="$2"
NEW_POS="$3"

[[ "$STEP_NUM" =~ ^[0-9]+$ ]] || err "step-number must be a positive integer, got: '$STEP_NUM'"
[[ "$NEW_POS"  =~ ^[0-9]+$ ]] || err "new-position must be a positive integer, got: '$NEW_POS'"
[[ "$STEP_NUM" -ge 1 ]]       || err "step-number must be >= 1"
[[ "$NEW_POS"  -ge 1 ]]       || err "new-position must be >= 1"
[[ "$STEP_NUM" -ne "$NEW_POS" ]] || err "step-number and new-position are the same ($STEP_NUM); nothing to do"

# ── Locate plan file ──────────────────────────────────────────────────────────
PLAN_FILE="$PLANS_DIR/$PLAN_ID.md"
[[ -f "$PLAN_FILE" ]] || err "Plan file not found: $PLAN_FILE"

# ── Parse steps from the plan file ───────────────────────────────────────────
# Steps are expected to follow the pattern:  ## Step N: <title>
# Collect line numbers where each step header begins.
mapfile -t STEP_LINES < <(grep -n '^## Step [0-9]\+:' "$PLAN_FILE" | cut -d: -f1)
TOTAL_STEPS=${#STEP_LINES[@]}

[[ "$TOTAL_STEPS" -ge 1 ]]         || err "No steps found in plan '$PLAN_ID'"
[[ "$STEP_NUM" -le "$TOTAL_STEPS" ]] || err "step-number $STEP_NUM exceeds total steps ($TOTAL_STEPS)"
[[ "$NEW_POS"  -le "$TOTAL_STEPS" ]] || err "new-position $NEW_POS exceeds total steps ($TOTAL_STEPS)"

TOTAL_LINES=$(wc -l < "$PLAN_FILE")

# ── Extract each step's content block ────────────────────────────────────────
# Returns lines [start, end) for step index (0-based)
step_block() {
  local idx=$1
  local start=${STEP_LINES[$idx]}
  local end
  if [[ $((idx + 1)) -lt "$TOTAL_STEPS" ]]; then
    end=$(( STEP_LINES[$((idx + 1))] - 1 ))
  else
    end=$TOTAL_LINES
  fi
  sed -n "${start},${end}p" "$PLAN_FILE"
}

# ── Build reordered steps array ───────────────────────────────────────────────
# Convert to 0-based indices
SRC_IDX=$(( STEP_NUM - 1 ))
DST_IDX=$(( NEW_POS  - 1 ))

# Build ordered list of 0-based indices after the move
ORDER=()
for (( i=0; i<TOTAL_STEPS; i++ )); do
  [[ $i -ne $SRC_IDX ]] && ORDER+=("$i")
done
# Insert source at destination
ORDER=("${ORDER[@]:0:$DST_IDX}" "$SRC_IDX" "${ORDER[@]:$DST_IDX}")

# ── Write reordered plan to a temp file ───────────────────────────────────────
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

# Copy everything before the first step header
HEADER_END=$(( STEP_LINES[0] - 1 ))
[[ "$HEADER_END" -ge 1 ]] && sed -n "1,${HEADER_END}p" "$PLAN_FILE" >> "$TMP_FILE"

# Append each step block with renumbered header
NEW_STEP_NUM=1
for idx in "${ORDER[@]}"; do
  # Read the block, replace the step number in the header line
  step_block "$idx" | sed "1s/^## Step [0-9]\+:/## Step ${NEW_STEP_NUM}:/" >> "$TMP_FILE"
  (( NEW_STEP_NUM++ ))
done

# ── Atomic replace ────────────────────────────────────────────────────────────
mv "$TMP_FILE" "$PLAN_FILE"

info "Moved step $STEP_NUM to position $NEW_POS in plan '$PLAN_ID'"
info "Steps renumbered 1–$TOTAL_STEPS"
