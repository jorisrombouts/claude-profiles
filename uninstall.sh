#!/usr/bin/env bash
# Reverse claude-profiles: remove the ~/.zshrc block and (optionally) move personal back to default.
set -euo pipefail

ZSHRC="$HOME/.zshrc"
DEFAULT="$HOME/.claude"
PERSONAL="$HOME/.claude-personal"
MARK_BEGIN="# >>> claude-profiles >>>"
MARK_END="# <<< claude-profiles <<<"

if [ -n "${CLAUDECODE:-}" ]; then
  echo "Refusing to run inside a Claude Code session. Close all sessions and run from a plain terminal." >&2
  exit 1
fi

# 1. Remove the ~/.zshrc block (between markers, inclusive).
if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  tmp="$(mktemp)"
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0==b {skip=1} skip==0 {print} $0==e {skip=0}
  ' "$ZSHRC" > "$tmp" && mv "$tmp" "$ZSHRC"
  echo "- Removed claude-profiles block from $ZSHRC"
else
  echo "- No claude-profiles block in $ZSHRC"
fi

# 2. Optionally reverse the migration (personal -> default).
echo
printf "Move %s back to %s (make personal the default again)? [y/N] " "$PERSONAL" "$DEFAULT"
read -r ans
if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
  if [ ! -d "$PERSONAL" ]; then
    echo "- $PERSONAL not found; nothing to move."
    exit 0
  fi
  if [ -d "$DEFAULT" ]; then
    if [ -z "$(ls -A "$DEFAULT" 2>/dev/null)" ]; then
      rmdir "$DEFAULT"
    else
      echo "- $DEFAULT is not empty (work profile has data)."
      echo "  Move it aside first:  mv \"$DEFAULT\" \"${DEFAULT}-work\"   then re-run."
      exit 1
    fi
  fi
  mv "$PERSONAL" "$DEFAULT"
  [ -f "$DEFAULT/.claude.json" ] && mv "$DEFAULT/.claude.json" "$HOME/.claude.json"
  echo "- Restored $DEFAULT as the default profile (your personal setup)."
else
  echo "- Left directories untouched (removed only the ~/.zshrc block)."
fi
