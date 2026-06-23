# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude   (bare `claude`, `claude-work`, the IDE)
#   personal = ~/.claude-personal  (`claude-personal`)
# `command claude` always runs the real binary: bypasses this function, resolves via PATH.

claude-work()     { command claude "$@"; }
claude-personal() { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" command claude "$@"; }
code-personal()   { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" code "$@"; }   # IDE with personal (plain `code` = work)

# Login status for both profiles (uses the built-in `claude auth status`).
_claude_status() {
  print -r -- ""
  print -r -- "work (~/.claude):";            claude-work     auth status --text 2>/dev/null || print -r -- "  not logged in"
  print -r -- "personal (~/.claude-personal):"; claude-personal auth status --text 2>/dev/null || print -r -- "  not logged in"
  print -r -- ""
}

# Plain typed menu — fallback when `gum` is not installed (keeps bare `claude` working anywhere).
_claude_menu_plain() {
  while true; do
    print -r -- "Claude Code profiles:"
    print -r -- "  1) work       (~/.claude)            [default]"
    print -r -- "  2) personal   (~/.claude-personal)"
    print -r -- "  s) status"
    local r; read "r?Launch [1=work, 2=personal, s=status] (Enter=work): "
    case "$r" in
      2) claude-personal; return ;;
      s) _claude_status ;;
      *) claude-work; return ;;
    esac
  done
}

claude() {
  # Menu ONLY for bare, no-arg, interactive use. Anything else -> real binary, untouched.
  if (( $# > 0 )) || [[ ! -t 0 || ! -t 1 ]]; then command claude "$@"; return; fi
  command -v gum >/dev/null 2>&1 || { _claude_menu_plain; return; }   # graceful fallback, no gum needed
  while true; do
    local choice
    choice="$(gum choose --header="Claude Code profile:" \
      "work       (~/.claude)" \
      "personal   (~/.claude-personal)" \
      "status")" || return                 # ESC / Ctrl-C cancels, launches nothing
    case "$choice" in
      personal*) claude-personal; return ;;
      status)    _claude_status ;;          # show status, then back to the menu
      *)         claude-work; return ;;      # work is the first/default item
    esac
  done
}
