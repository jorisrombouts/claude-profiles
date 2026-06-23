#!/usr/bin/env bash
# Set up isolated Claude Code profiles: work (default ~/.claude) + personal (~/.claude-personal).
# Idempotent. Safe to re-run.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
DEFAULT="$HOME/.claude"
PERSONAL="$HOME/.claude-personal"
MARK_BEGIN="# >>> claude-profiles >>>"
MARK_END="# <<< claude-profiles <<<"

# Safety: never run inside a live Claude Code session — the migration moves ~/.claude
# out from under it (shell snapshots, session state) and can corrupt it.
if [ -n "${CLAUDECODE:-}" ]; then
  echo "Refusing to run inside a Claude Code session (CLAUDECODE is set)." >&2
  echo "Quit ALL Claude Code sessions and the IDE extension, then run this from a plain terminal." >&2
  exit 1
fi

echo "claude-profiles installer"
echo "  repo:     $REPO_DIR"
echo "  default:  $DEFAULT  -> WORK"
echo "  personal: $PERSONAL"
echo

# 1. Migrate existing ~/.claude -> ~/.claude-personal (only once; never clobber).
if [ -e "$PERSONAL" ]; then
  echo "- $PERSONAL already exists -> skipping migration."
elif [ -d "$DEFAULT" ] && [ ! -L "$DEFAULT" ]; then
  echo "- Migrating $DEFAULT -> $PERSONAL"
  if [ -f "$HOME/.claude.json" ]; then
    cp "$HOME/.claude.json" "$HOME/.claude.json.bak"
    echo "    backed up ~/.claude.json -> ~/.claude.json.bak"
  fi
  mv "$DEFAULT" "$PERSONAL"                                   # atomic rename within $HOME
  if [ -f "$HOME/.claude.json" ]; then
    mv "$HOME/.claude.json" "$PERSONAL/.claude.json"          # personal keeps its MCP/trust/theme state
    echo "    moved ~/.claude.json -> $PERSONAL/.claude.json"
  fi
  echo "    moved existing setup into personal."
else
  echo "- No real $DEFAULT directory to migrate."
fi

# Ensure the work default dir exists (blank).
mkdir -p "$DEFAULT"

# 2. Wire ~/.zshrc to source the functions (idempotent, marker-guarded).
if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  echo "- ~/.zshrc already sources claude-profiles -> leaving as is."
else
  {
    echo ""
    echo "$MARK_BEGIN"
    echo "[ -f \"$REPO_DIR/claude-profiles.zsh\" ] && source \"$REPO_DIR/claude-profiles.zsh\""
    echo "$MARK_END"
  } >> "$ZSHRC"
  echo "- Added source block to $ZSHRC"
fi

# 3. Install gum for the polished menu (optional; menu falls back to plain text without it).
if command -v gum >/dev/null 2>&1; then
  echo "- gum already installed."
elif command -v brew >/dev/null 2>&1; then
  echo "- Installing gum (Homebrew) for the profile menu..."
  brew install gum || echo "  (gum install failed — the menu will use a plain-text fallback)"
else
  echo "- Homebrew not found; skipping gum. The menu uses a plain-text fallback."
  echo "  For the polished menu later: brew install gum"
fi

cat <<EOF

Done. Next steps in a NEW terminal:
  1) source ~/.zshrc
  2) claude-work       -> then in-session:  /logout   then   /login   (your WORK / enterprise account)
  3) claude-personal   -> then in-session:  /login    (your personal account)

After that:
  - bare 'claude'    shows the profile menu (default = work); press 's' for login status
  - claude-work      launches work (the default ~/.claude)
  - claude-personal  launches personal (~/.claude-personal)
  - code-personal .  opens VS Code using the personal profile (plain 'code' = work)
EOF
