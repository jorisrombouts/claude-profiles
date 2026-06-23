# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude   (bare `claude`, `claude-work`, the IDE)
#   personal = ~/.claude-personal  (`claude-personal`)
# `command claude` always runs the real binary: bypasses this function, resolves via PATH.

claude-work()     { command claude "$@"; }
claude-personal() { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" command claude "$@"; }
code-personal()   { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" code "$@"; }   # IDE with personal (plain `code` = work)

# One-line login status for a profile ('' = work/default). Output is CAPTURED (stdout is a pipe,
# stdin /dev/null) so the claude TUI's OSC background-colour probe can't leak escape codes into the
# terminal. `claude auth status` prints a base-URL line + a status line and exits 1 when logged out,
# so we pick the line mentioning "logged in" rather than the first line or the exit code.
_claude_login_line() {
  local out
  if [[ -n $1 ]]; then
    out="$(CLAUDE_CONFIG_DIR=$1 command claude auth status --text </dev/null 2>/dev/null)"
  else
    out="$(command claude auth status --text </dev/null 2>/dev/null)"
  fi
  print -r -- "$out" | awk '
    tolower($0) ~ /logged in/ { hit=$0 }
    NF                        { last=$0 }
    END { print (hit != "" ? hit : (last != "" ? last : "unknown")) }'
}

_claude_status() {
  print -r -- ""
  print -r -- "Claude Code login status:"
  print -r -- "  work      (~/.claude)            $(_claude_login_line '')"
  print -r -- "  personal  (~/.claude-personal)   $(_claude_login_line "$HOME/.claude-personal")"
  print -r -- ""
}

# Plain typed menu — fallback when `gum` is not installed (keeps bare `claude` working anywhere).
_claude_menu_plain() {
  print -r -- "Claude Code profiles:"
  print -r -- "  1) work       (~/.claude)            [default]"
  print -r -- "  2) personal   (~/.claude-personal)"
  print -r -- "  s) status"
  local r; read "r?Launch [1=work, 2=personal, s=status] (Enter=work): "
  case "$r" in
    2) claude-personal ;;
    s) _claude_status ;;
    *) claude-work ;;
  esac
}

claude() {
  # Menu ONLY for bare, no-arg, interactive use. Anything else -> real binary, untouched.
  if (( $# > 0 )) || [[ ! -t 0 || ! -t 1 ]]; then command claude "$@"; return; fi
  command -v gum >/dev/null 2>&1 || { _claude_menu_plain; return; }   # graceful fallback, no gum needed
  local choice
  choice="$(gum choose --header="Claude Code profile:" \
    "work       (~/.claude)" \
    "personal   (~/.claude-personal)" \
    "status")" || return                 # ESC / Ctrl-C cancels, launches nothing
  case "$choice" in
    personal*) claude-personal ;;
    status)    _claude_status ;;          # show status once, then return to the shell (no menu loop)
    *)         claude-work ;;             # work is the first/default item
  esac
}
