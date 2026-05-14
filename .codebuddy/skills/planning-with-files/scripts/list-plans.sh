#!/usr/bin/env bash
# list-plans.sh - List all planning files in the current project
# Usage: ./list-plans.sh [--dir <plans_directory>] [--format <table|json|simple>] [--status <all|pending|complete|attested>]

set -euo pipefail

# Default values
PLANS_DIR=".plans"
FORMAT="table"
STATUS_FILTER="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      PLANS_DIR="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--dir <plans_directory>] [--format <table|json|simple>] [--status <all|pending|complete|attested>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Validate format
if [[ ! "$FORMAT" =~ ^(table|json|simple)$ ]]; then
  echo "Error: Invalid format '$FORMAT'. Must be one of: table, json, simple" >&2
  exit 1
fi

# Validate status filter
if [[ ! "$STATUS_FILTER" =~ ^(all|pending|complete|attested)$ ]]; then
  echo "Error: Invalid status '$STATUS_FILTER'. Must be one of: all, pending, complete, attested" >&2
  exit 1
fi

# Check if plans directory exists
if [[ ! -d "$PLANS_DIR" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo '{"plans": [], "total": 0, "directory": "'"$PLANS_DIR"'"}'
  else
    echo "No plans directory found at: $PLANS_DIR"
  fi
  exit 0
fi

# Collect plan files
PLAN_FILES=()
while IFS= read -r -d '' file; do
  PLAN_FILES+=("$file")
done < <(find "$PLANS_DIR" -maxdepth 2 -name "*.md" -print0 2>/dev/null | sort -z)

if [[ ${#PLAN_FILES[@]} -eq 0 ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo '{"plans": [], "total": 0, "directory": "'"$PLANS_DIR"'"}'
  else
    echo "No plan files found in: $PLANS_DIR"
  fi
  exit 0
fi

# Helper: detect plan status from file content
get_plan_status() {
  local file="$1"
  local content
  content=$(cat "$file" 2>/dev/null || echo "")

  if echo "$content" | grep -qi "status.*attested\|attested.*status"; then
    echo "attested"
  elif echo "$content" | grep -qi "status.*complete\|complete.*status\|## complete"; then
    echo "complete"
  else
    echo "pending"
  fi
}

# Helper: extract plan title from first H1 heading
get_plan_title() {
  local file="$1"
  local title
  title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || echo "")
  if [[ -z "$title" ]]; then
    title=$(basename "$file" .md)
  fi
  echo "$title"
}

# Build output
if [[ "$FORMAT" == "json" ]]; then
  echo -n '{"plans": ['
  first=true
  count=0
  for file in "${PLAN_FILES[@]}"; do
    status=$(get_plan_status "$file")
    if [[ "$STATUS_FILTER" != "all" && "$status" != "$STATUS_FILTER" ]]; then
      continue
    fi
    title=$(get_plan_title "$file")
    modified=$(date -r "$file" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "unknown")
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo -n ','
    fi
    echo -n "{\"file\": \"$file\", \"title\": \"$title\", \"status\": \"$status\", \"modified\": \"$modified\"}"
    ((count++)) || true
  done
  echo "], \"total\": $count, \"directory\": \"$PLANS_DIR\"}"
elif [[ "$FORMAT" == "table" ]]; then
  printf "%-50s %-12s %-20s\n" "FILE" "STATUS" "MODIFIED"
  printf "%s\n" "$(printf '%0.s-' {1..85})"
  count=0
  for file in "${PLAN_FILES[@]}"; do
    status=$(get_plan_status "$file")
    if [[ "$STATUS_FILTER" != "all" && "$status" != "$STATUS_FILTER" ]]; then
      continue
    fi
    modified=$(date -r "$file" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
    printf "%-50s %-12s %-20s\n" "$file" "$status" "$modified"
    ((count++)) || true
  done
  echo ""
  echo "Total: $count plan(s)"
else
  # simple format
  count=0
  for file in "${PLAN_FILES[@]}"; do
    status=$(get_plan_status "$file")
    if [[ "$STATUS_FILTER" != "all" && "$status" != "$STATUS_FILTER" ]]; then
      continue
    fi
    echo "$file [$status]"
    ((count++)) || true
  done
  echo "Total: $count"
fi
