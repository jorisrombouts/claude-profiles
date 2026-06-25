#!/usr/bin/env bash
# Set up isolated Claude Code profiles: work (default ~/.claude) + personal (~/.claude-personal).
# Your existing ~/.claude stays the default ("work"); personal is a separate config dir you log into.
# Idempotent. Safe to re-run.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
PERSONAL="$HOME/.claude-personal"
MARK_BEGIN="# >>> claude-profiles >>>"
MARK_END="# <<< claude-profiles <<<"

# Safety: never run inside a live Claude Code session.
if [ -n "${CLAUDECODE:-}" ]; then
  echo "Refusing to run inside a Claude Code session (CLAUDECODE is set)." >&2
  echo "Quit ALL Claude Code sessions and the IDE extension, then run this from a plain terminal." >&2
  exit 1
fi

# Warn (don't fail) if Claude Code isn't installed yet — these profiles just wrap it.
command -v claude >/dev/null 2>&1 || \
  echo "Warning: 'claude' is not on your PATH. Install Claude Code first: https://claude.com/claude-code" >&2

echo "claude-profiles installer"
echo "  repo:     $REPO_DIR"
echo "  work:     $HOME/.claude        (default — your existing config)"
echo "  personal: $PERSONAL"
echo

# 1. Ensure the personal config dir exists (you log into it separately).
if [ -d "$PERSONAL" ]; then
  echo "- $PERSONAL exists."
else
  mkdir -p "$PERSONAL"
  echo "- Created $PERSONAL."
fi

# 2. Wire ~/.zshrc to source the functions (idempotent, marker-guarded).
if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  echo "- ~/.zshrc already sources claude-profiles."
else
  {
    echo ""
    echo "$MARK_BEGIN"
    echo "[ -f \"$REPO_DIR/claude-profiles.zsh\" ] && source \"$REPO_DIR/claude-profiles.zsh\""
    echo "$MARK_END"
  } >> "$ZSHRC"
  echo "- Added source block to $ZSHRC"
fi

# 3. Install gum for the menu (optional; the menu falls back to plain text without it).
if command -v gum >/dev/null 2>&1; then
  echo "- gum already installed."
elif command -v brew >/dev/null 2>&1; then
  echo "- Installing gum (Homebrew)..."
  brew install gum || echo "  (gum install failed; the menu will use a plain-text fallback)"
else
  echo "- Homebrew not found; skipping gum. The menu uses a plain-text fallback."
fi

cat <<EOF

Done. In a NEW terminal:
  source ~/.zshrc

Set up two accounts that stay logged in at the SAME time (macOS):
  1) claude-work                  -> /login as your WORK (Enterprise) account   (shared Keychain)
  2) claude-set-token personal    -> mint + store a token for your PERSONAL account
  (On macOS the login lives in one shared Keychain item, so the personal profile needs its own token
   to stay signed in alongside work. Skip step 2 to just switch accounts with /login instead.)

Usage:
  claude              menu: work / personal / status   (pick "status" to see both logins)
  claude-work         straight into work     (= the default ~/.claude; the IDE & scripts use this too)
  claude-personal     straight into personal
  claude-set-token p  one-time: store a token so profile p stays logged in (default personal)
EOF
