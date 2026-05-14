#!/usr/bin/env bash
# update-plan.sh
# Updates an existing plan file by modifying task statuses or adding new tasks.
# Usage: ./update-plan.sh <plan-file> [options]
#
# Options:
#   --task <task-id>       Task ID to update (e.g., 1.1, 2.3)
#   --status <status>      New status: todo | in-progress | done | blocked
#   --add-task <title>     Add a new task under a section
#   --section <number>     Section number for new task (used with --add-task)
#   --notes <text>         Optional notes to append to the task

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "[update-plan] $*"
}

# ── argument parsing ─────────────────────────────────────────────────────────

PLAN_FILE=""
TASK_ID=""
NEW_STATUS=""
ADD_TASK=""
SECTION=""
NOTES=""

[[ $# -lt 1 ]] && usage

PLAN_FILE="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)    TASK_ID="$2";    shift 2 ;;
    --status)  NEW_STATUS="$2"; shift 2 ;;
    --add-task) ADD_TASK="$2"; shift 2 ;;
    --section) SECTION="$2";   shift 2 ;;
    --notes)   NOTES="$2";     shift 2 ;;
    *) error "Unknown option: $1" ;;
  esac
done

# ── validation ───────────────────────────────────────────────────────────────

[[ -f "$PLAN_FILE" ]] || error "Plan file not found: $PLAN_FILE"

VALID_STATUSES=("todo" "in-progress" "done" "blocked")

if [[ -n "$NEW_STATUS" ]]; then
  valid=false
  for s in "${VALID_STATUSES[@]}"; do
    [[ "$s" == "$NEW_STATUS" ]] && valid=true && break
  done
  $valid || error "Invalid status '$NEW_STATUS'. Must be one of: ${VALID_STATUSES[*]}"
fi

# ── status map ───────────────────────────────────────────────────────────────
# Maps status names to checkbox markdown tokens

status_to_checkbox() {
  case "$1" in
    todo)        echo "- [ ]" ;;
    in-progress) echo "- [~]" ;;
    done)        echo "- [x]" ;;
    blocked)     echo "- [!]" ;;
  esac
}

# ── update task status ───────────────────────────────────────────────────────

update_task_status() {
  local task_id="$1"
  local new_status="$2"
  local new_checkbox
  new_checkbox=$(status_to_checkbox "$new_status")

  # Escape dots in task ID for use in regex
  local escaped_id
  escaped_id=$(echo "$task_id" | sed 's/\./\\./g')

  # Match lines like: - [ ] **1.2** Some task title
  if ! grep -qE "^- \[.\] \*\*${escaped_id}\*\*" "$PLAN_FILE"; then
    error "Task '$task_id' not found in $PLAN_FILE"
  fi

  # Perform in-place replacement of the checkbox token
  sed -i.bak -E "s|^- \[.\] (\*\*${escaped_id}\*\*)|${new_checkbox} \1|" "$PLAN_FILE"
  rm -f "${PLAN_FILE}.bak"

  info "Task $task_id status updated to '$new_status'."

  if [[ -n "$NOTES" ]]; then
    # Append notes as an indented comment below the task line
    sed -i.bak -E "/^- \[.\] \*\*${escaped_id}\*\*/a\\  > Note: ${NOTES}" "$PLAN_FILE"
    rm -f "${PLAN_FILE}.bak"
    info "Notes appended to task $task_id."
  fi
}

# ── add new task ─────────────────────────────────────────────────────────────

add_task() {
  local title="$1"
  local section="$2"

  # Find the last task ID in the target section to derive the next ID
  local last_id
  last_id=$(grep -oE "\*\*${section}\.[0-9]+\*\*" "$PLAN_FILE" | tail -1 | grep -oE "[0-9]+\.[0-9]+")

  local next_num=1
  if [[ -n "$last_id" ]]; then
    local last_num
    last_num=$(echo "$last_id" | cut -d'.' -f2)
    next_num=$(( last_num + 1 ))
  fi

  local new_task_id="${section}.${next_num}"
  local new_task_line="- [ ] **${new_task_id}** ${title}"

  # Append the new task after the last task in the section
  if [[ -n "$last_id" ]]; then
    local escaped_last
    escaped_last=$(echo "$last_id" | sed 's/\./\\./g')
    sed -i.bak "/\*\*${escaped_last}\*\*/a\\${new_task_line}" "$PLAN_FILE"
    rm -f "${PLAN_FILE}.bak"
  else
    # No existing tasks in section — append after section header
    local escaped_section
    escaped_section=$(echo "$section" | sed 's/\./\\./g')
    sed -i.bak "/^## ${escaped_section}/a\\${new_task_line}" "$PLAN_FILE"
    rm -f "${PLAN_FILE}.bak"
  fi

  info "Added task $new_task_id: '$title' to section $section."
}

# ── main ─────────────────────────────────────────────────────────────────────

if [[ -n "$TASK_ID" && -n "$NEW_STATUS" ]]; then
  update_task_status "$TASK_ID" "$NEW_STATUS"
elif [[ -n "$ADD_TASK" && -n "$SECTION" ]]; then
  add_task "$ADD_TASK" "$SECTION"
else
  error "Provide either --task + --status, or --add-task + --section."
fi

info "Plan file updated: $PLAN_FILE"
