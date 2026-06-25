#!/usr/bin/env bash
# Remove the claude-profiles wiring from ~/.zshrc. Profile directories are left untouched.
set -euo pipefail

ZSHRC="$HOME/.zshrc"
MARK_BEGIN="# >>> claude-profiles >>>"
MARK_END="# <<< claude-profiles <<<"

if [ -n "${CLAUDECODE:-}" ]; then
  echo "Refusing to run inside a Claude Code session (CLAUDECODE is set). Run from a plain terminal." >&2
  exit 1
fi

if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  tmp="$(mktemp)"
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0==b { skip=1 }
    !skip { print }
    $0==e { skip=0 }
  ' "$ZSHRC" > "$tmp" && mv "$tmp" "$ZSHRC"
  echo "Removed the claude-profiles block from $ZSHRC."
else
  echo "No claude-profiles block found in $ZSHRC."
fi

# Offer to remove the OAuth tokens this tool stored in the macOS Keychain (profile dirs stay intact).
_cp_have_token() { security find-generic-password -s claude-profiles -a "$1" >/dev/null 2>&1; }
if _cp_have_token work || _cp_have_token personal; then
  printf '\nThis tool stored profile token(s) in the macOS Keychain (service "claude-profiles").\n'
  read -r -p "Remove them too? [y/N] " ans || ans=""
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    for p in work personal; do
      _cp_have_token "$p" || continue
      security delete-generic-password -s claude-profiles -a "$p" >/dev/null 2>&1 \
        && echo "  removed claude-profiles/$p" || true
    done
  else
    echo "  Left Keychain tokens in place (remove later: security delete-generic-password -s claude-profiles -a personal)."
  fi
fi

cat <<EOF

Done. Your profile directories are untouched:
  ~/.claude            (work / default)
  ~/.claude-personal   (personal)
Delete them yourself if you want them gone, e.g.:
  rm -rf ~/.claude-personal
EOF
