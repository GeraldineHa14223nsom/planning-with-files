#!/usr/bin/env bash
# add-step.sh - Add a new step to an existing plan
# Usage: ./add-step.sh <plan-name> <step-description> [--position <pos>] [--notes <notes>]

set -euo pipefail

# Default values
PLANS_DIR="${PLANS_DIR:-.plans}"
POSITION=""
NOTES=""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <plan-name> <step-description> [--position <pos>] [--notes <notes>]"
    echo ""
    echo "Arguments:"
    echo "  plan-name          Name of the plan to add a step to"
    echo "  step-description   Description of the new step"
    echo ""
    echo "Options:"
    echo "  --position <pos>   Insert step at position (default: append to end)"
    echo "  --notes <notes>    Additional notes for the step"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 my-plan \"Write unit tests\""
    echo "  $0 my-plan \"Write unit tests\" --position 2"
    echo "  $0 my-plan \"Write unit tests\" --notes \"Use pytest framework\""
    exit 1
}

log_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_info() {
    echo -e "${BLUE}$1${NC}"
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    usage
fi

PLAN_NAME="$1"
STEP_DESCRIPTION="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --position)
            POSITION="$2"
            shift 2
            ;;
        --notes)
            NOTES="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate plan name
if [[ -z "$PLAN_NAME" ]]; then
    log_error "Plan name cannot be empty"
    exit 1
fi

# Validate step description
if [[ -z "$STEP_DESCRIPTION" ]]; then
    log_error "Step description cannot be empty"
    exit 1
fi

PLAN_FILE="${PLANS_DIR}/${PLAN_NAME}.md"

# Check if plan exists
if [[ ! -f "$PLAN_FILE" ]]; then
    log_error "Plan '${PLAN_NAME}' not found at ${PLAN_FILE}"
    exit 1
fi

# Count existing steps
EXISTING_STEPS=$(grep -c '^- \[' "$PLAN_FILE" 2>/dev/null || echo 0)

# Validate position if provided
if [[ -n "$POSITION" ]]; then
    if ! [[ "$POSITION" =~ ^[0-9]+$ ]]; then
        log_error "Position must be a positive integer"
        exit 1
    fi
    if [[ "$POSITION" -lt 1 ]]; then
        log_error "Position must be at least 1"
        exit 1
    fi
    if [[ "$POSITION" -gt $((EXISTING_STEPS + 1)) ]]; then
        log_error "Position ${POSITION} exceeds available range (1-$((EXISTING_STEPS + 1)))"
        exit 1
    fi
fi

# Build the new step line
NEW_STEP="- [ ] ${STEP_DESCRIPTION}"
if [[ -n "$NOTES" ]]; then
    NEW_STEP="${NEW_STEP} <!-- ${NOTES} -->"
fi

# Create a temp file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

if [[ -z "$POSITION" ]]; then
    # Append step before the closing section or at end of steps
    awk -v new_step="$NEW_STEP" '
        /^## / && found_steps { print new_step; appended=1 }
        /^- \[/ { found_steps=1 }
        { print }
        END { if (!appended) print new_step }
    ' "$PLAN_FILE" > "$TMP_FILE"
else
    # Insert at specific position
    STEP_COUNT=0
    awk -v new_step="$NEW_STEP" -v pos="$POSITION" '
        /^- \[/ {
            step_count++
            if (step_count == pos) { print new_step }
        }
        { print }
        END { if (pos > step_count) print new_step }
    ' "$PLAN_FILE" > "$TMP_FILE"
fi

# Replace original file with updated content
cp "$TMP_FILE" "$PLAN_FILE"

NEW_TOTAL=$(grep -c '^- \[' "$PLAN_FILE" 2>/dev/null || echo 0)

log_success "Step added to plan '${PLAN_NAME}' successfully"
log_info "  Step: ${STEP_DESCRIPTION}"
[[ -n "$NOTES" ]] && log_info "  Notes: ${NOTES}"
[[ -n "$POSITION" ]] && log_info "  Position: ${POSITION}" || log_info "  Position: ${NEW_TOTAL} (appended)"
log_info "  Total steps: ${NEW_TOTAL}"
