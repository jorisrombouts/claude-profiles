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

# 4. Offer the guided account setup (interactive terminals only; logging in needs a browser).
run_setup=0
if [ -t 0 ] && [ -t 1 ]; then
  echo
  if command -v gum >/dev/null 2>&1; then
    gum confirm "Set up your two Claude accounts now?" && run_setup=1 || run_setup=0
  else
    printf "Set up your two Claude accounts now? [Y/n] "
    read -r _ans || _ans=""
    case "$_ans" in [Nn]*) run_setup=0 ;; *) run_setup=1 ;; esac
  fi
fi
if [ "$run_setup" = 1 ]; then
  # The functions are zsh; run the wizard in zsh, sourcing the file we just wired up.
  zsh -c "source '$REPO_DIR/claude-profiles.zsh'; claude-setup" || true
fi

cat <<EOF

Done — claude-profiles is wired into ~/.zshrc.

Set up or change your accounts anytime with the guided wizard:
  claude-setup     detects what's done, walks you through work + personal (a browser opens per login)

Everyday use:
  claude           menu: work / personal / status
  claude-work      work      (= the default ~/.claude; the IDE & scripts use this too)
  claude-personal  personal

(In a brand-new terminal, run 'source ~/.zshrc' first if the commands aren't found.)
EOF
