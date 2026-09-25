# Isolated Claude Code profiles, sourced from ~/.zshrc.
#   work     = default ~/.claude            (plain `claude`, `claude-work`, the IDE, scripts)
#   personal = ~/.claude-personal           (`claude-personal`)
#
# CLAUDE_CONFIG_DIR isolates settings / history / sessions / MCP servers per profile. On macOS the one
# thing it does NOT isolate is the *login*: the OAuth credential lives in a single shared Keychain item
# (file-based credentials are Linux/Windows only). So to stay signed into BOTH accounts at once we
# inject a per-profile CLAUDE_CODE_OAUTH_TOKEN — auth precedence #5, above the shared Keychain (#6).
# Tokens are minted with `claude setup-token` and stored in the Keychain (service "claude-profiles").
# Run `claude-setup` for the guided wizard (or `claude-set-token personal` directly). Without a stored
# token a profile just falls back to the shared Keychain login, so nothing breaks before you set it up.
#
# The `claude` function below shadows the real binary — always call it via `_cp_claude` instead.

# Claude Code's native installer drops the binary in ~/.local/bin; ensure it's on PATH.
case ":${PATH}:" in
  *":$HOME/.local/bin:"*) ;;
  *) [[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Resolve the real Claude Code binary once (the menu function below would shadow `command claude`).
_cp_resolve_claude_bin() {
  whence -p claude 2>/dev/null && return
  local p
  for p in \
    "$HOME/.local/bin/claude" \
    "$HOME/.local/share/claude/ClaudeCode.app/Contents/MacOS/claude"
  do
    [[ -x $p ]] && { print -r -- "$p"; return; }
  done
  return 1
}
_CP_CLAUDE_BIN="$(_cp_resolve_claude_bin)" || _CP_CLAUDE_BIN=

_cp_claude() {
  if [[ -n $_CP_CLAUDE_BIN ]]; then
    "$_CP_CLAUDE_BIN" "$@"
  else
    command claude "$@"
  fi
}

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
    _cp_claude "$@"
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
  _cp_claude setup-token || { print -r -- "setup-token cancelled." >&2; return 1; }
  local token
  if command -v gum >/dev/null 2>&1; then
    token="$(gum input --password --placeholder 'paste the token here')"
  else
    print -rn -- "Paste the token (input hidden): "
    read -rs token; print -r -- ""
  fi
  token="${token//[[:space:]]/}"
  [[ -z $token ]] && { print -r -- "No token entered; nothing stored." >&2; return 1; }
  if security add-generic-password -s claude-profiles -a "$profile" -w "$token" -U 2>/dev/null; then
    print -r -- "✔ Stored '$profile' token."
  else
    print -r -- "Failed to store the token in the Keychain." >&2; return 1
  fi
}

# --- guided setup wizard --------------------------------------------------------------------------

# gum-or-plain yes/no prompt. Returns 0 (yes) / 1 (no).
_cp_confirm() {   # <prompt>
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$1"
  else
    local r; read "r?$1 [y/N] " || return 1
    [[ $r == [Yy]* ]]
  fi
}

# Styled (or plain) section header.
_cp_head() {   # <text>
  print -r -- ""
  if command -v gum >/dev/null 2>&1; then gum style --bold --foreground 212 "$1"; else print -r -- "— $1 —"; fi
}

# A profile's currently logged-in email (empty if none). Reads the cached/Keychain identity, no token.
_cp_email() {   # <profile>
  _cp_exec "$1" "" auth status --text </dev/null 2>/dev/null | awk -F': *' '/^[Ee]mail:/ { print $2; exit }'
}

# The one step that needs Claude's TUI: guide a work /login, then re-verify.
_cp_setup_work_login() {
  print -r -- "Claude will open on the work profile. Type /login, sign in as your WORK account, then /exit."
  print -rn -- "Press Enter to continue (Ctrl-C to skip)… "
  local d; read -r d || { print -r -- "Skipped."; return 0; }
  claude-work
  local m; m="$(_cp_email work)"
  if [[ -n $m ]]; then print -r -- "✓ Work is now $m."; else print -r -- "Work still isn't logged in — run claude-setup again when ready."; fi
}

# Guided first-run setup: detects what's already done and walks you through both accounts. Re-runnable
# anytime to check or change things; install.sh offers to run it right after installing.
claude-setup() {
  [[ -n $_CP_CLAUDE_BIN ]] || {
    print -r -- "claude is not installed. Install Claude Code first: https://claude.com/claude-code" >&2; return 1; }
  local have_gum=0; command -v gum >/dev/null 2>&1 && have_gum=1

  if (( have_gum )); then
    gum style --border double --border-foreground 212 --padding "1 3" --margin "1 0" --align center \
      "claude-profiles" "two accounts, signed in at the same time"
  else
    print -r -- ""; print -r -- "=== claude-profiles — two accounts, signed in at the same time ==="
  fi

  print -r -- "Checking what's already set up…"
  local wmail ptok wdisp pdisp
  wmail="$(_cp_email work)"
  ptok="$(_cp_token personal)"
  [[ -n $wmail ]] && wdisp="✓ $wmail"   || wdisp="— not logged in"
  [[ -n $ptok  ]] && pdisp="✓ token set" || pdisp="— not set up yet"
  printf '  %-10s %-22s %s\n' work     "(~/.claude)"          "$wdisp"
  printf '  %-10s %-22s %s\n' personal "(~/.claude-personal)" "$pdisp"

  _cp_head "Step 1/2 · Work account  (your default profile)"
  if [[ -n $wmail ]]; then
    if _cp_confirm "Keep $wmail as your work account?"; then
      print -r -- "✓ Keeping $wmail as work."
    else
      _cp_setup_work_login
    fi
  else
    print -r -- "No work account is logged in yet."
    _cp_setup_work_login
  fi

  _cp_head "Step 2/2 · Personal account"
  if [[ -n $ptok ]]; then
    local pmail; pmail="$(_cp_email personal)"
    if _cp_confirm "Keep the current personal token${pmail:+ ($pmail)}?"; then
      print -r -- "✓ Keeping the personal token."
    else
      claude-set-token personal
    fi
  else
    print -r -- "Personal needs its own token to stay signed in alongside work (a browser will open)."
    if _cp_confirm "Set up personal now?"; then
      claude-set-token personal
    else
      print -r -- "Skipped. Run claude-setup again whenever you're ready."
    fi
  fi

  _claude_status
  local we pe; we="$(_cp_email work)"; pe="$(_cp_email personal)"
  if [[ -n $we && $we == "$pe" ]]; then
    local warn="⚠ Both profiles resolve to $we — you probably want two different accounts. Re-run claude-setup and switch one."
    if (( have_gum )); then gum style --foreground 214 "$warn"; else print -r -- "$warn"; fi
  elif (( have_gum )); then
    gum style --border rounded --border-foreground 42 --padding "0 2" \
      "✓ All set — both accounts stay logged in, one per terminal." \
      "claude-work · claude-personal · claude (menu) · claude-setup (re-run)"
  else
    print -r -- "✓ All set. Use: claude-work · claude-personal · claude (menu) · claude-setup (re-run)"
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
  if (( $# > 0 )) || [[ ! -t 0 || ! -t 1 ]]; then _cp_claude "$@"; return; fi
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
