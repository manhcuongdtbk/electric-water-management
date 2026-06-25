#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): warn when Vietnamese docs contain English
# jargon "per" outside code fences/backticks. Fail-open: errors → silent exit.
# Only checks .md files under docs/ (not code, not specs/plans history).
set -uo pipefail

# Read tool input from stdin (JSON with file_path + old_string/new_string or content)
input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || exit 0
[[ -n "$file_path" ]] || exit 0

# Only check docs .md files (not code, not frozen specs/plans)
case "$file_path" in
  */docs/*.md) : ;;
  *CONTRIBUTING.md|*AGENTS.md) : ;;
  *) exit 0 ;;
esac

# Get the new content: for Write it's .content, for Edit it's .new_string
new_text="$(printf '%s' "$input" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)" || exit 0
[[ -n "$new_text" ]] || exit 0

# Strip code fences and backtick spans before checking
clean="$(printf '%s' "$new_text" | sed '/^```/,/^```/d' | sed 's/`[^`]*`//g')"

# Check for standalone "per" as Vietnamese jargon (word boundary)
if printf '%s' "$clean" | grep -qiE '\bper\b'; then
  # Extract the offending line(s) for context
  matches="$(printf '%s' "$clean" | grep -iE '\bper\b' | head -3)"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"JARGON ALERT: Vietnamese text contains English word 'per'. Use 'theo từng' or 'mỗi' instead. Offending line(s): ${matches}\"}}"
fi
