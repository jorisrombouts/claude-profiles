# claude-profiles: any number of isolated Claude Code profiles. Source this file from ~/.zshrc.
#
#   ~/.claude           the default profile, named $CLAUDE_PROFILES_DEFAULT (else "default")
#   ~/.claude-<name>    a profile called <name>, launched with  claude-<name>
#
# Each profile gets its own login, settings, plugins, MCP servers, history and memory, because
# Claude Code keeps everything (Keychain login included) under CLAUDE_CONFIG_DIR.
# Manage profiles with:  claude-profile [list|add <name>|remove <name>|status|help]

# Claude Code's native installer puts the binary in ~/.local/bin.
[[ :$PATH: == *:$HOME/.local/bin:* ]] || path+=("$HOME/.local/bin")

_cp_default=${CLAUDE_PROFILES_DEFAULT:-default}

# Define the launcher function for one profile name.
_cp_define() {
  if [[ $1 == $_cp_default ]]; then
    functions[claude-$1]='(unset CLAUDE_CONFIG_DIR; claude "$@")'
  else
    functions[claude-$1]="CLAUDE_CONFIG_DIR=\"\$HOME/.claude-$1\" claude \"\$@\""
  fi
}

# Profile names: the default first, then every ~/.claude-<name> directory.
_cp_names() {
  print -r -- $_cp_default
  local d; for d in "$HOME"/.claude-*(N/); print -r -- ${d##*/.claude-}
}

_cp_dir() { [[ $1 == $_cp_default ]] && print -r -- "$HOME/.claude" || print -r -- "$HOME/.claude-$1" }

claude-profile() {
  local cmd=${1:-list} name=$2
  case $cmd in
    list)
      local n; for n in $(_cp_names); do
        printf '  %-14s %s%s\n' "$n" "$(_cp_dir $n)" "$([[ $n == $_cp_default ]] && print ' (default)')"
      done ;;
    add)
      [[ $name =~ '^[a-z0-9][a-z0-9_-]*$' ]] || { print -u2 "claude-profile: invalid name '$name' (use a-z 0-9 _ -)"; return 1 }
      [[ -e $(_cp_dir $name) || $name == $_cp_default ]] && { print -u2 "claude-profile: '$name' already exists"; return 1 }
      mkdir -p "$(_cp_dir $name)"
      # Chrome integration is shared and bound to the default profile; keep it off here.
      print '{ "claudeInChromeDefaultEnabled": false }' > "$(_cp_dir $name)/settings.json"
      _cp_define $name
      print "Created $(_cp_dir $name). Run  claude-$name  and /login." ;;
    remove)
      [[ $name == $_cp_default ]] && { print -u2 "claude-profile: cannot remove the default profile"; return 1 }
      [[ -n $name && -d $(_cp_dir $name) ]] || { print -u2 "claude-profile: no profile '$name'"; return 1 }
      local ans; read -r "ans?Delete $(_cp_dir $name) and everything in it? [y/N] "
      [[ $ans == [yY]* ]] || return 1
      rm -rf "$(_cp_dir $name)"; unfunction claude-$name 2>/dev/null
      print "Removed '$name'." ;;
    status)
      command -v claude >/dev/null || { print -u2 "claude-profile: claude not found on PATH"; return 1 }
      local n out; for n in $(_cp_names); do
        out=$(claude-$n auth status --text </dev/null 2>/dev/null | grep -iE '^(login method|email):' | sed 's/^/    /')
        print -r -- "$n"; print -r -- "${out:-    not logged in}"
      done ;;
    help) cat <<'EOF'
claude-profile                 list profiles
claude-profile add <name>      create ~/.claude-<name> and the claude-<name> launcher
claude-profile remove <name>   delete a profile (asks first)
claude-profile status          login method and email per profile
EOF
      ;;
    *) claude-profile help >&2; return 1 ;;
  esac
}

for _cp_n in $(_cp_names); _cp_define $_cp_n
unset _cp_n
