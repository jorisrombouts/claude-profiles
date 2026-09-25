#!/usr/bin/env zsh
# Self-check for claude-profiles.zsh. Run: zsh test.zsh
set -e
here=${0:A:h}
export HOME=$(mktemp -d)
trap 'rm -rf "$HOME"' EXIT

# Stub claude: prints the config dir it was given, then its arguments.
mkdir -p "$HOME/bin" "$HOME/.claude" "$HOME/.claude-a"
cat > "$HOME/bin/claude" <<'EOF'
#!/bin/sh
echo "dir=${CLAUDE_CONFIG_DIR-unset} args=$*"
EOF
chmod +x "$HOME/bin/claude"
export PATH="$HOME/bin:$PATH"

fail() { print -u2 "FAIL: $1"; exit 1 }

CLAUDE_PROFILES_DEFAULT=work
source "$here/claude-profiles.zsh"

(( $+functions[claude-work] )) || fail "default launcher not defined"
(( $+functions[claude-a] ))    || fail "claude-a not defined"
[[ "$(claude-profile list)" == *"work"*"(default)"* ]] || fail "list does not mark default"

[[ "$(claude-a --version)" == "dir=$HOME/.claude-a args=--version" ]] || fail "claude-a env"
[[ "$(CLAUDE_CONFIG_DIR=/leak claude-work x)" == "dir=unset args=x" ]]  || fail "default launcher leaks config dir"

claude-profile add c >/dev/null
[[ -d "$HOME/.claude-c" ]]                                               || fail "add did not create dir"
grep -q claudeInChromeDefaultEnabled "$HOME/.claude-c/settings.json"     || fail "add did not write chrome flag"
(( $+functions[claude-c] ))                                              || fail "add did not define launcher"
claude-profile add c 2>/dev/null && fail "duplicate add succeeded"

claude-profile remove work 2>/dev/null && fail "removed default"
print y | claude-profile remove a >/dev/null
[[ ! -d "$HOME/.claude-a" ]]                                             || fail "remove did not delete dir"

print "ok"
