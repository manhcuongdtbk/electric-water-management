#!/usr/bin/env bash
# Block SendUserFile for video files. Use markdown links instead.
# Hook: PreToolUse matcher=SendUserFile

if jq -r '.tool_input.files[]? // empty' | grep -qiE '\.(webm|mp4|mov|avi|mkv)$'; then
  echo 'BLOCKED: Do not use SendUserFile for video files. Provide a markdown link instead: [filename](relative/path/to/file)' >&2
  exit 2
fi
