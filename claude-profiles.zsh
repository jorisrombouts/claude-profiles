# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude    (plain `claude`, `claude-work`, the IDE, scripts)
#   personal = ~/.claude-personal   (`claude-personal`)
# `command claude` always runs the real binary: bypasses this function, resolves via PATH.

claude-work()     { command claude "$@"; }                         # work = default ~/.claude

# Personal also pins the plugin root + seed dir to its own profile, a best-effort attempt to keep
# work's plugins (which live in the default ~/.claude) from seeding into personal. These vars are
# undocumented; if plugins ever misbehave, drop the two CLAUDE_CODE_PLUGIN_* lines.
claude-personal() {
  CLAUDE_CONFIG_DIR="$HOME/.claude-personal" \
  CLAUDE_CODE_PLUGIN_CACHE_DIR="$HOME/.claude-personal/plugins" \
  CLAUDE_CODE_PLUGIN_SEED_DIR="$HOME/.claude-personal/plugins" \
  command claude "$@"
}

# One-line login status for a profile ('' = work/default). Output is CAPTURED (stdout is a pipe,
# stdin /dev/null) so the claude TUI's OSC colour probe can't leak escape codes into the terminal;
# we summarise it as "<login method> (<email>)", or the "not logged in" message.
_claude_login_line() {
  local out
  if [[ -n $1 ]]; then
    out="$(CLAUDE_CONFIG_DIR=$1 command claude auth status --text </dev/null 2>/dev/null)"
  else
    out="$(command claude auth status --text </dev/null 2>/dev/null)"
  fi
  print -r -- "$out" | awk '
    /^[Ll]ogin method:/ { sub(/^[^:]*:[[:space:]]*/, ""); method=$0 }
    /^[Ee]mail:/        { sub(/^[^:]*:[[:space:]]*/, ""); email=$0 }
    tolower($0) ~ /not logged in/ { no=$0 }
    END {
      if (email != "")   print (method != "" ? method " (" email ")" : email)
      else if (no != "") print no
      else               print "unknown"
    }'
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
  # Menu ONLY for bare, no-arg, interactive use. Anything else -> real binary (= work), untouched.
  if (( $# > 0 )) || [[ ! -t 0 || ! -t 1 ]]; then command claude "$@"; return; fi
  command -v gum >/dev/null 2>&1 || { _claude_menu_plain; return; }   # graceful fallback, no gum needed
  local choice
  choice="$(gum choose --header="Claude Code profile:" \
    "work       (~/.claude)" \
    "personal   (~/.claude-personal)" \
    "status")" || return                 # ESC / Ctrl-C cancels, launches nothing
  case "$choice" in
    personal*) claude-personal ;;
    status)    _claude_status ;;          # show status once, then return to the shell
    *)         claude-work ;;             # work is the first/default item
  esac
}
