#!/usr/bin/env bash
# show-plan.sh — Display the full contents of a specific plan file
# Usage: ./show-plan.sh <plan-name> [--format plain|markdown] [--plans-dir <dir>]

set -euo pipefail

# ──────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────
PLANS_DIR="${PLANS_DIR:-.plans}"
FORMAT="plain"
PLAN_NAME=""

# ──────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plans-dir)
      PLANS_DIR="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 <plan-name> [--format plain|markdown] [--plans-dir <dir>]"
      echo ""
      echo "Options:"
      echo "  --plans-dir DIR   Directory where plans are stored (default: .plans)"
      echo "  --format FORMAT   Output format: plain or markdown (default: plain)"
      echo "  --help            Show this help message"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      PLAN_NAME="$1"
      shift
      ;;
  esac
done

# ──────────────────────────────────────────────
# Validate inputs
# ──────────────────────────────────────────────
if [[ -z "$PLAN_NAME" ]]; then
  echo "Error: plan name is required." >&2
  echo "Usage: $0 <plan-name> [--format plain|markdown] [--plans-dir <dir>]" >&2
  exit 1
fi

if [[ ! -d "$PLANS_DIR" ]]; then
  echo "Error: plans directory '$PLANS_DIR' does not exist." >&2
  exit 1
fi

# ──────────────────────────────────────────────
# Resolve plan file path
# Strip .md extension if provided, then add it back
# ──────────────────────────────────────────────
PLAN_BASENAME="${PLAN_NAME%.md}"
PLAN_FILE="$PLANS_DIR/${PLAN_BASENAME}.md"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Error: plan '$PLAN_BASENAME' not found at '$PLAN_FILE'." >&2
  echo "" >&2
  echo "Available plans:" >&2
  if compgen -G "$PLANS_DIR/*.md" > /dev/null 2>&1; then
    for f in "$PLANS_DIR"/*.md; do
      echo "  - $(basename "$f" .md)" >&2
    done
  else
    echo "  (none)" >&2
  fi
  exit 1
fi

# ──────────────────────────────────────────────
# Display the plan
# ──────────────────────────────────────────────
case "$FORMAT" in
  markdown)
    # Output raw markdown content as-is
    cat "$PLAN_FILE"
    ;;
  plain)
    # Strip markdown formatting for a cleaner terminal read
    # Remove ATX headings markers, bold/italic markers, horizontal rules,
    # and list markers while preserving content
    sed \
      -e 's/^#{1,6}[[:space:]]*//' \
      -e 's/\*\*\([^*]*\)\*\*/\1/g' \
      -e 's/__\([^_]*\)__/\1/g' \
      -e 's/\*\([^*]*\)\*/\1/g' \
      -e 's/_\([^_]*\)_/\1/g' \
      -e 's/^[-*][[:space:]]\+/  • /' \
      -e 's/^[[:space:]]*[-*][[:space:]]\+/    ◦ /' \
      -e '/^---\+$/d' \
      -e '/^===\+$/d' \
      "$PLAN_FILE"
    ;;
  *)
    echo "Error: unknown format '$FORMAT'. Use 'plain' or 'markdown'." >&2
    exit 1
    ;;
esac

# ──────────────────────────────────────────────
# Print file metadata to stderr so it doesn't
# pollute piped output
# ──────────────────────────────────────────────
FILE_SIZE=$(wc -c < "$PLAN_FILE" | tr -d ' ')
LINE_COUNT=$(wc -l < "$PLAN_FILE" | tr -d ' ')
MOD_TIME=$(date -r "$PLAN_FILE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c '%y' "$PLAN_FILE" 2>/dev/null | cut -d'.' -f1)

echo "" >&2
echo "────────────────────────────────────────" >&2
echo "Plan   : $PLAN_BASENAME" >&2
echo "File   : $PLAN_FILE" >&2
echo "Lines  : $LINE_COUNT" >&2
echo "Size   : ${FILE_SIZE} bytes" >&2
echo "Modified: $MOD_TIME" >&2
echo "────────────────────────────────────────" >&2
