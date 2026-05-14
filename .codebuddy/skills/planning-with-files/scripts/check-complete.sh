#!/usr/bin/env bash
# check-complete.sh
# Checks whether all tasks in a plan file are marked as complete.
# Usage: ./check-complete.sh <plan-file>
#
# Exit codes:
#   0 - All tasks are complete
#   1 - One or more tasks are incomplete
#   2 - Invalid arguments or file not found

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $0 <plan-file>" >&2
  echo "  plan-file  Path to the Markdown plan file to check" >&2
  exit 2
}

error() {
  echo "[ERROR] $*" >&2
}

info() {
  echo "[INFO]  $*"
}

# ── Argument validation ───────────────────────────────────────────────────────

if [[ $# -ne 1 ]]; then
  usage
fi

PLAN_FILE="$1"

if [[ ! -f "$PLAN_FILE" ]]; then
  error "Plan file not found: $PLAN_FILE"
  exit 2
fi

# ── Task counting ─────────────────────────────────────────────────────────────

# Completed tasks:  lines matching '- [x]' or '- [X]'
# Incomplete tasks: lines matching '- [ ]'
COMPLETE_COUNT=$(grep -cE '^\s*- \[[xX]\]' "$PLAN_FILE" || true)
INCOMPLETE_COUNT=$(grep -cE '^\s*- \[ \]' "$PLAN_FILE" || true)
TOTAL_COUNT=$(( COMPLETE_COUNT + INCOMPLETE_COUNT ))

# ── Report ────────────────────────────────────────────────────────────────────

info "Plan file  : $PLAN_FILE"
info "Total tasks: $TOTAL_COUNT"
info "Complete   : $COMPLETE_COUNT"
info "Incomplete : $INCOMPLETE_COUNT"

if [[ $TOTAL_COUNT -eq 0 ]]; then
  error "No tasks found in plan file. Is this a valid plan?"
  exit 2
fi

if [[ $INCOMPLETE_COUNT -gt 0 ]]; then
  echo ""
  echo "Incomplete tasks:"
  grep -nE '^\s*- \[ \]' "$PLAN_FILE" | while IFS=: read -r lineno content; do
    printf "  Line %-4s %s\n" "$lineno" "$content"
  done
  echo ""
  error "Plan is NOT complete. $INCOMPLETE_COUNT task(s) remaining."
  exit 1
fi

echo ""
info "All $TOTAL_COUNT task(s) are complete. ✓"
exit 0
