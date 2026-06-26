# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude            (plain `claude`, `claude-work`, the IDE, scripts)
#   personal = ~/.claude-personal           (`claude-personal`)
#
# CLAUDE_CONFIG_DIR isolates settings / history / sessions / MCP servers per profile. On macOS the one
# thing it does NOT isolate is the *login*: the OAuth credential lives in a single shared Keychain item
# (file-based credentials are Linux/Windows only). So to stay signed into BOTH accounts at once we
# inject a per-profile CLAUDE_CODE_OAUTH_TOKEN — auth precedence #5, above the shared Keychain (#6).
# Tokens are minted with `claude setup-token` and stored in the Keychain (service "claude-profiles");
# set one up with `claude-set-token personal`. Without a stored token a profile just falls
# back to the shared Keychain login, so nothing breaks before you set it up.
#
# `command claude` always runs the real binary untouched (it bypasses the menu function below).

# --- token store (macOS Keychain, service "claude-profiles") --------------------------------------

# Print the stored OAuth token for a profile (work|personal), or nothing if none is set.
_cp_token() { security find-generic-password -s claude-profiles -a "$1" -w 2>/dev/null; }

# --- profile launchers ----------------------------------------------------------------------------

# Run the real `claude` binary with a profile's launch environment: personal gets its own config dir
# (plus best-effort plugin dirs), and either profile gets its stored OAuth token injected when present.
# The token is read by the caller and passed in, so the Keychain is touched at most once per launch.
# Redirections on the call apply to claude (e.g. `_cp_exec personal "$t" auth status </dev/null`).
_cp_exec() {
  local profile="$1" tok="$2"; shift 2
  (   # subshell: these exports stay scoped to this launch, never leak into your interactive shell
    if [[ $profile == personal ]]; then
      export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
      # best-effort, undocumented: keep work's plugins from seeding into personal (drop if they misbehave)
      export CLAUDE_CODE_PLUGIN_CACHE_DIR="$HOME/.claude-personal/plugins"
      export CLAUDE_CODE_PLUGIN_SEED_DIR="$HOME/.claude-personal/plugins"
    fi
    [[ -n $tok ]] && export CLAUDE_CODE_OAUTH_TOKEN="$tok"
    command claude "$@"
  )
}

# work = the default ~/.claude (native Keychain login); personal = ~/.claude-personal. Each injects its
# own stored token if one is set (see `claude-set-token`), else falls back to the shared Keychain login.
claude-work()     { local t; t="$(_cp_token work)";     _cp_exec work     "$t" "$@"; }
claude-personal() { local t; t="$(_cp_token personal)"; _cp_exec personal "$t" "$@"; }

# --- status ---------------------------------------------------------------------------------------

# Report a profile's account for the status view. We query `claude auth status` WITHOUT injecting the
# token: with a token set it prints only "Auth token: CLAUDE_CODE_OAUTH_TOKEN" (no account), so instead
# we read the profile's cached/Keychain identity. The auth: column (from the stored token) already says
# whether that profile launches via token or Keychain. Output is CAPTURED (stdin /dev/null) so the TUI's
# colour probe can't leak escape codes into the terminal.
_claude_login_line() {   # <profile>
  _cp_exec "$1" "" auth status --text </dev/null 2>/dev/null | awk '
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

# --- one-time token setup -------------------------------------------------------------------------

# Mint an OAuth token for a profile and store it in the Keychain, so that profile stays logged in
# alongside the other (see the header note). Usage: claude-set-token [work|personal]  (default personal).
# The token is read with hidden input, so it never lands in your shell history.
claude-set-token() {
  local profile="${1:-personal}"
  if [[ $profile != work && $profile != personal ]]; then
    print -r -- "usage: claude-set-token [work|personal]   (default: personal)" >&2; return 1
  fi
  print -r -- "Set up a token for '$profile' — sign in as your ${(U)profile} account when the browser opens."
  print -rn -- "Press Enter to run 'claude setup-token' (Ctrl-C to cancel)… "
  local discard; read -r discard || return 1
  command claude setup-token || { print -r -- "setup-token cancelled." >&2; return 1; }
  local token
  print -rn -- "Paste the token (input hidden): "
  read -rs token; print -r -- ""
  token="${token//[[:space:]]/}"
  [[ -z $token ]] && { print -r -- "No token entered; nothing stored." >&2; return 1; }
  if security add-generic-password -s claude-profiles -a "$profile" -w "$token" -U 2>/dev/null; then
    print -r -- "✔ Stored '$profile' token. Launch 'claude' and pick 'status' to verify."
  else
    print -r -- "Failed to store the token in the Keychain." >&2; return 1
  fi
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
