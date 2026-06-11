#!/usr/bin/env bash
# PostToolUse(Edit|Write) reminder: when a versioned docs/ file is edited,
# remind to bump its version + changelog in the same commit (ADR-002).
# Reminder only — never blocks. Fail-OPEN on any uncertainty.
set -u

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)
[ -z "$f" ] && exit 0

# Only files under a docs/ directory.
case "$f" in
  */docs/*|docs/*) ;;
  *) exit 0 ;;
esac

# Only files that actually carry a version header (skip un-versioned docs).
grep -Eq '(\*\*Phiên bản:\*\*|^version:)' "$f" 2>/dev/null || exit 0

jq -nc '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Bạn vừa sửa một tài liệu docs/ có version. Theo ADR-002: bump version + thêm một entry changelog trong CÙNG commit. (File meta gốc — AGENTS.md/CONTRIBUTING.md/README.md/CLAUDE.md — KHÔNG versioned.)"}}'
exit 0
