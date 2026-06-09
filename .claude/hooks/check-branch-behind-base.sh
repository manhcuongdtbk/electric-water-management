#!/usr/bin/env bash
# PreToolUse(Bash) guard: before `git push`, ensure the current branch is not
# behind its base branch. If behind, DENY the push and tell Claude to integrate
# the base first. Fail-OPEN: any uncertainty (no git repo, no network, base
# undetectable) -> allow the push, never lock the user out.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only act on `git push` (matches compound commands like `cd x && git push`).
printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push' || exit 0

br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
# Never guard a push of the integration branches themselves, or detached HEAD.
case "$br" in develop|main|HEAD|"") exit 0 ;; esac

# Determine the base per Git Flow.
case "$br" in
  release/*|hotfix/*) base=main ;;
  *)
    base=$(gh pr view "$br" --json baseRefName -q .baseRefName 2>/dev/null)
    [ -z "$base" ] && base=develop
    ;;
esac

git fetch -q origin "$base" 2>/dev/null || exit 0
behind=$(git rev-list --count "HEAD..origin/$base" 2>/dev/null)
[ -z "$behind" ] && exit 0

if [ "$behind" -gt 0 ]; then
  reason="Branch '$br' is $behind commit(s) behind origin/$base. Standing instruction: integrate the base BEFORE pushing — run 'git merge origin/$base' (or rebase), resolve any conflicts (ask the user if non-trivial), re-check hot files such as the release spec and renumber versions/changelog if they collide, then push again."
  jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
fi
exit 0
