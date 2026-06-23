# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude   (bare `claude`, `claude-work`, the IDE)
#   personal = ~/.claude-personal  (`claude-personal`)
# `command claude` always runs the real binary: bypasses this function, resolves via PATH.

claude-work()     { command claude "$@"; }
claude-personal() { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" command claude "$@"; }
code-personal()   { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" code "$@"; }   # IDE with personal (plain `code` = work)

claude() {
  # Menu ONLY for bare, no-arg, interactive use. Anything else -> real binary, untouched.
  if (( $# > 0 )) || [[ ! -t 0 || ! -t 1 ]]; then command claude "$@"; return; fi
  while true; do
    print -r -- "Claude Code profiles:"
    print -r -- "  1) work       (~/.claude)            [default]"
    print -r -- "  2) personal   (~/.claude-personal)"
    print -r -- "  s) status"
    local r; read "r?Launch [1=work, 2=personal, s=status] (Enter=work): "
    case "$r" in
      2) claude-personal; return ;;
      s) print -r -- ""
         print -r -- "work:";     claude-work     auth status --text 2>/dev/null || print -r -- "  not logged in"
         print -r -- "personal:"; claude-personal auth status --text 2>/dev/null || print -r -- "  not logged in"
         print -r -- "" ;;
      *) claude-work; return ;;
    esac
  done
}
