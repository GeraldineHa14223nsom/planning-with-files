#!/usr/bin/env bash
# delete-plan.sh — Remove a plan file and its associated attestation
# Usage: delete-plan.sh <plan-id> [--force]

set -euo pipefail

# ──────────────────────────────────────────────
# Defaults & constants
# ──────────────────────────────────────────────
PLANS_DIR="${PLANS_DIR:-.plans}"
ATTEST_DIR="${ATTEST_DIR:-${PLANS_DIR}/.attestations}"
FORCE=false
PLAN_ID=""

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────
usage() {
  echo "Usage: $(basename "$0") <plan-id> [--force]"
  echo ""
  echo "Arguments:"
  echo "  plan-id   The identifier of the plan to delete (filename without extension)"
  echo ""
  echo "Options:"
  echo "  --force   Skip confirmation prompt"
  echo "  --help    Show this help message"
  exit 1
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "[delete-plan] $*"
}

# ──────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --help)  usage ;;
    -*) error "Unknown option: $arg" ;;
    *)
      if [[ -z "$PLAN_ID" ]]; then
        PLAN_ID="$arg"
      else
        error "Unexpected argument: $arg"
      fi
      ;;
  esac
done

[[ -z "$PLAN_ID" ]] && error "plan-id is required."

# ──────────────────────────────────────────────
# Locate plan file
# ──────────────────────────────────────────────
PLAN_FILE="${PLANS_DIR}/${PLAN_ID}.md"

if [[ ! -f "$PLAN_FILE" ]]; then
  # Try with .txt extension as fallback
  PLAN_FILE_TXT="${PLANS_DIR}/${PLAN_ID}.txt"
  if [[ -f "$PLAN_FILE_TXT" ]]; then
    PLAN_FILE="$PLAN_FILE_TXT"
  else
    error "Plan not found: '${PLAN_ID}' (looked in ${PLANS_DIR}/)"
  fi
fi

# ──────────────────────────────────────────────
# Locate optional attestation file
# ──────────────────────────────────────────────
ATTEST_FILE="${ATTEST_DIR}/${PLAN_ID}.json"
HAS_ATTEST=false
if [[ -f "$ATTEST_FILE" ]]; then
  HAS_ATTEST=true
fi

# ──────────────────────────────────────────────
# Confirmation prompt
# ──────────────────────────────────────────────
if [[ "$FORCE" == false ]]; then
  echo "You are about to delete:"
  echo "  Plan      : $PLAN_FILE"
  if [[ "$HAS_ATTEST" == true ]]; then
    echo "  Attestation: $ATTEST_FILE"
  fi
  echo ""
  read -r -p "Are you sure? [y/N] " confirm
  case "$confirm" in
    [yY][eE][sS]|[yY]) ;;
    *)
      info "Deletion cancelled."
      exit 0
      ;;
  esac
fi

# ──────────────────────────────────────────────
# Delete plan file
# ──────────────────────────────────────────────
rm -f "$PLAN_FILE"
info "Deleted plan: $PLAN_FILE"

# ──────────────────────────────────────────────
# Delete attestation file if present
# ──────────────────────────────────────────────
if [[ "$HAS_ATTEST" == true ]]; then
  rm -f "$ATTEST_FILE"
  info "Deleted attestation: $ATTEST_FILE"
fi

info "Plan '${PLAN_ID}' successfully removed."
