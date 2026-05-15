#!/usr/bin/env bash
# complete-step.sh - Mark a specific step in a plan as complete
# Usage: ./complete-step.sh <plan-name> <step-number> [--notes "completion notes"]

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
PLANS_DIR="${PLANS_DIR:-./plans}"
SCRIPT_NAME="$(basename "$0")"

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
die()  { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
info() { echo -e "${CYAN}INFO:  $*${NC}"; }
ok()   { echo -e "${GREEN}OK:    $*${NC}"; }
warn() { echo -e "${YELLOW}WARN:  $*${NC}"; }

usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $SCRIPT_NAME <plan-name> <step-number> [--notes "text"]

${BOLD}Arguments:${NC}
  plan-name     Name of the plan file (with or without .md extension)
  step-number   1-based index of the step to mark complete

${BOLD}Options:${NC}
  --notes TEXT  Optional completion note appended to the step line
  -h, --help    Show this help message

${BOLD}Examples:${NC}
  $SCRIPT_NAME my-feature 3
  $SCRIPT_NAME my-feature 3 --notes "deployed to staging"
EOF
  exit 0
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
[[ $# -lt 2 ]] && { usage; }

PLAN_NAME=""
STEP_NUMBER=""
NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --notes)
      [[ -z "${2:-}" ]] && die "--notes requires a value"
      NOTES="$2"
      shift 2
      ;;
    -*) die "Unknown option: $1" ;;
    *)
      if [[ -z "$PLAN_NAME" ]]; then
        PLAN_NAME="$1"
      elif [[ -z "$STEP_NUMBER" ]]; then
        STEP_NUMBER="$1"
      else
        die "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -z "$PLAN_NAME" ]]   && die "plan-name is required"
[[ -z "$STEP_NUMBER" ]] && die "step-number is required"

# Validate step number is a positive integer
[[ "$STEP_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "step-number must be a positive integer, got: $STEP_NUMBER"

# ─── Resolve Plan File ────────────────────────────────────────────────────────
PLAN_FILE="${PLANS_DIR}/${PLAN_NAME}"
[[ "$PLAN_FILE" != *.md ]] && PLAN_FILE="${PLAN_FILE}.md"

[[ -f "$PLAN_FILE" ]] || die "Plan file not found: $PLAN_FILE"

# ─── Find and Update the Target Step ─────────────────────────────────────────
# Steps are lines matching: - [ ] or - [x] (case-insensitive checkbox)
STEP_PATTERN='^[[:space:]]*- \[[ xX]\]'

# Count total steps
TOTAL_STEPS=$(grep -c "$STEP_PATTERN" "$PLAN_FILE" || true)
[[ "$TOTAL_STEPS" -eq 0 ]] && die "No checklist steps found in: $PLAN_FILE"
[[ "$STEP_NUMBER" -gt "$TOTAL_STEPS" ]] && \
  die "Step $STEP_NUMBER does not exist (plan has $TOTAL_STEPS steps)"

# Extract the target step line for display
TARGET_LINE=$(grep -n "$STEP_PATTERN" "$PLAN_FILE" | sed -n "${STEP_NUMBER}p")
LINE_NUM=$(echo "$TARGET_LINE" | cut -d: -f1)
LINE_CONTENT=$(echo "$TARGET_LINE" | cut -d: -f2-)

# Check if already complete
if echo "$LINE_CONTENT" | grep -qE '^[[:space:]]*- \[[xX]\]'; then
  warn "Step $STEP_NUMBER is already marked complete."
  echo -e "  ${YELLOW}${LINE_CONTENT}${NC}"
  exit 0
fi

# Build replacement line: swap [ ] for [x] and optionally append notes
if [[ -n "$NOTES" ]]; then
  NEW_LINE=$(echo "$LINE_CONTENT" | sed "s/\[ \]/[x]/" | sed "s/$/ — ${NOTES}/")
else
  NEW_LINE=$(echo "$LINE_CONTENT" | sed "s/\[ \]/[x]/")
fi

# Perform in-place substitution on the exact line number
TMP_FILE=$(mktemp)
awk -v lnum="$LINE_NUM" -v newline="$NEW_LINE" \
  'NR == lnum { print newline; next } { print }' \
  "$PLAN_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$PLAN_FILE"

# ─── Summary ──────────────────────────────────────────────────────────────────
COMPLETED=$(grep -c "^[[:space:]]*- \[[xX]\]" "$PLAN_FILE" || true)
REMAINING=$(( TOTAL_STEPS - COMPLETED ))

ok "Step $STEP_NUMBER marked complete in '${PLAN_NAME}'."
echo -e "  ${GREEN}${NEW_LINE}${NC}"
echo
info "Progress: ${COMPLETED}/${TOTAL_STEPS} steps complete, ${REMAINING} remaining."

[[ "$REMAINING" -eq 0 ]] && echo -e "\n${GREEN}${BOLD}All steps complete! Consider running check-complete.sh.${NC}"
