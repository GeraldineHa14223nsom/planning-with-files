#!/usr/bin/env bash
# create-plan.sh
# Creates a new planning file with the standard structure and metadata.
# Usage: ./create-plan.sh <plan-name> [output-dir]

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
  echo "Usage: $0 <plan-name> [output-dir]"
  echo ""
  echo "  plan-name   Short identifier for the plan (e.g. 'add-auth-module')"
  echo "  output-dir  Directory to write the plan file (default: ./plans)"
  echo ""
  echo "Example:"
  echo "  $0 add-auth-module ./plans"
  exit 1
}

log()  { echo "[create-plan] $*"; }
err()  { echo "[create-plan] ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
[[ $# -lt 1 ]] && usage

PLAN_NAME="$1"
OUTPUT_DIR="${2:-./plans}"

# Sanitise plan name: lowercase, replace spaces/underscores with hyphens
SAFE_NAME=$(echo "$PLAN_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd '[:alnum:]-')
[[ -z "$SAFE_NAME" ]] && err "Plan name '${PLAN_NAME}' produced an empty safe name after sanitisation."

# ---------------------------------------------------------------------------
# Derived values
# ---------------------------------------------------------------------------
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_PREFIX=$(date -u +"%Y%m%d")
FILENAME="${DATE_PREFIX}-${SAFE_NAME}.md"
OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

# ---------------------------------------------------------------------------
# Ensure output directory exists
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR" || err "Could not create output directory: ${OUTPUT_DIR}"

# Refuse to overwrite an existing plan
[[ -f "$OUTPUT_PATH" ]] && err "Plan file already exists: ${OUTPUT_PATH}"

# ---------------------------------------------------------------------------
# Write the plan template
# ---------------------------------------------------------------------------
cat > "$OUTPUT_PATH" <<EOF
---
title: ${PLAN_NAME}
created: ${TIMESTAMP}
status: draft
attested: false
completed: false
---

# ${PLAN_NAME}

## Overview

<!-- Describe the goal and motivation for this plan. -->

## Steps

<!-- List each actionable step. Use checkboxes so check-complete.sh can track progress. -->

- [ ] Step 1 — Define requirements
- [ ] Step 2 — Design solution
- [ ] Step 3 — Implement changes
- [ ] Step 4 — Write / update tests
- [ ] Step 5 — Review and merge

## Acceptance Criteria

<!-- What must be true for this plan to be considered complete? -->

- All steps above are checked off.
- Tests pass in CI.
- Documentation is updated.

## Notes

<!-- Any additional context, links, or decisions recorded here. -->
EOF

log "Plan created: ${OUTPUT_PATH}"
log "Next steps:"
log "  1. Edit the plan:  \$EDITOR ${OUTPUT_PATH}"
log "  2. Attest the plan: ./attest-plan.sh ${OUTPUT_PATH}"
log "  3. Track progress:  ./check-complete.sh ${OUTPUT_PATH}"
