# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude            (plain `claude`, `claude-work`, the IDE, scripts)
#   personal = ~/.claude-personal           (`claude-personal`)
#
# CLAUDE_CONFIG_DIR isolates settings / history / sessions / MCP servers per profile. On macOS the one
# thing it does NOT isolate is the *login*: the OAuth credential lives in a single shared Keychain item
# (file-based credentials are Linux/Windows only). So to stay signed into BOTH accounts at once we
# inject a per-profile CLAUDE_CODE_OAUTH_TOKEN — auth precedence #5, above the shared Keychain (#6).
# Tokens are minted with `claude setup-token` and stored in the Keychain (service "claude-profiles");
# set one up with `claude-profiles set-token personal`. Without a stored token a profile just falls
# back to the shared Keychain login, so nothing breaks before you set it up.
#
# `command claude` always runs the real binary untouched (it bypasses the menu function below).

# --- token store (macOS Keychain, service "claude-profiles") --------------------------------------

# Print the stored OAuth token for a profile (work|personal), or nothing if none is set.
_cp_token() { security find-generic-password -s claude-profiles -a "$1" -w 2>/dev/null; }

# --- profile launchers ----------------------------------------------------------------------------

# work = the default ~/.claude (native Keychain login). If a 'work' token is stored, it's used instead.
claude-work() {
  local tok; tok="$(_cp_token work)"
  if [[ -n $tok ]]; then
    ( export CLAUDE_CODE_OAUTH_TOKEN="$tok"; command claude "$@" )   # subshell: doesn't leak into your shell
  else
    command claude "$@"
  fi
}

# personal = ~/.claude-personal, with its own OAuth token (if stored) so it stays logged in as the
# personal account regardless of the shared Keychain. The CLAUDE_CODE_PLUGIN_* vars are a best-effort,
# undocumented attempt to keep work's plugins from seeding into personal; drop them if plugins misbehave.
claude-personal() {
  local tok; tok="$(_cp_token personal)"
  (   # subshell: exports stay scoped to this launch, never leak into your interactive shell
    export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
    export CLAUDE_CODE_PLUGIN_CACHE_DIR="$HOME/.claude-personal/plugins"
    export CLAUDE_CODE_PLUGIN_SEED_DIR="$HOME/.claude-personal/plugins"
    [[ -n $tok ]] && export CLAUDE_CODE_OAUTH_TOKEN="$tok"
    command claude "$@"
  )
}

# --- status ---------------------------------------------------------------------------------------

# Run `claude auth status` with a profile's exact launch env, so the reported account matches what you
# actually get when you launch it. profile = work|personal.
_cp_auth_status_raw() {
  local profile="$1" tok; tok="$(_cp_token "$profile")"
  (
    [[ $profile == personal ]] && export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
    [[ -n $tok ]] && export CLAUDE_CODE_OAUTH_TOKEN="$tok"
    command claude auth status --text </dev/null 2>/dev/null
  )
}

# Summarise a profile's login as "<method> (<email>)" / "not logged in" / "unknown". Output is CAPTURED
# (stdin /dev/null) so the TUI's colour probe can't leak escape codes into the terminal.
_claude_login_line() {
  _cp_auth_status_raw "$1" | awk '
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
  local wm pm
  [[ -n "$(_cp_token work)" ]]     && wm=token || wm=keychain
  [[ -n "$(_cp_token personal)" ]] && pm=token || pm=keychain
  print -r -- ""
  print -r -- "Claude Code login status:"
  printf '  %-10s %-22s auth:%-9s %s\n' work     "(~/.claude)"          "$wm" "$(_claude_login_line work)"
  printf '  %-10s %-22s auth:%-9s %s\n' personal "(~/.claude-personal)" "$pm" "$(_claude_login_line personal)"
  print -r -- ""
}

# --- management: claude-profiles <cmd> ------------------------------------------------------------

_cp_help() {
  cat <<'EOF'
claude-profiles — manage two isolated Claude Code logins on one Mac

  claude-profiles status            show both profiles' login + auth mode
  claude-profiles set-token <p>     mint + store an OAuth token for profile p (work|personal)
  claude-profiles remove-token <p>  delete the stored token for profile p
  claude-profiles help              this help

Launch a profile:
  claude            menu: work / personal / status
  claude-work       work     = default ~/.claude
  claude-personal   personal = ~/.claude-personal

To stay signed into BOTH accounts at once on macOS, give the personal profile its own token:
  1) claude-work    ->  /login as your work (Enterprise) account   (uses the shared Keychain)
  2) claude-profiles set-token personal                            (mints + stores a personal token)
Then a work tab and a personal tab stay logged in independently. Don't run /login inside personal —
it's authenticated by its token, and /login would overwrite the shared (work) Keychain login.
EOF
}

_cp_valid_profile() {
  case "$1" in
    work|personal) return 0 ;;
    *) print -r -- "claude-profiles: profile must be 'work' or 'personal' (got '${1:-}')." >&2; return 1 ;;
  esac
}

_cp_set_token() {
  local profile="${1:-}"
  _cp_valid_profile "$profile" || return 1
  print -r -- ""
  print -r -- "Set up an OAuth token for the '$profile' profile."
  print -r -- "A login flow opens in your browser — sign in as your ${(U)profile} account."
  print -r -- "When it finishes it prints a token; copy it, then paste it below."
  print -r -- ""
  print -rn -- "Press Enter to run 'claude setup-token' now (Ctrl-C to cancel)… "
  local discard; read -r discard || return 1
  command claude setup-token || { print -r -- "setup-token failed or was cancelled." >&2; return 1; }
  print -r -- ""
  local token
  print -rn -- "Paste the token for '$profile' (input hidden): "
  read -rs token; print -r -- ""
  token="$(print -r -- "$token" | tr -d '[:space:]')"
  if [[ -z $token ]]; then print -r -- "No token entered; nothing stored." >&2; return 1; fi
  if security add-generic-password -s claude-profiles -a "$profile" -w "$token" -U 2>/dev/null; then
    print -r -- "✔ Stored '$profile' token in the macOS Keychain (service: claude-profiles)."
    print -r -- "  '$profile' sessions now use it. Run 'claude-profiles status' to verify."
  else
    print -r -- "Failed to store the token in the Keychain." >&2; return 1
  fi
}

_cp_remove_token() {
  local profile="${1:-}"
  _cp_valid_profile "$profile" || return 1
  if security delete-generic-password -s claude-profiles -a "$profile" >/dev/null 2>&1; then
    print -r -- "✔ Removed '$profile' token. It will fall back to the shared Keychain login."
  else
    print -r -- "No stored token for '$profile'."
  fi
}

claude-profiles() {
  local cmd="${1:-help}"
  (( $# )) && shift
  case "$cmd" in
    status)         _claude_status ;;
    set-token)      _cp_set_token "$@" ;;
    remove-token)   _cp_remove_token "$@" ;;
    help|-h|--help) _cp_help ;;
    *) print -r -- "claude-profiles: unknown command '$cmd'." >&2; _cp_help; return 1 ;;
  esac
}

# --- bare `claude` menu ---------------------------------------------------------------------------

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
