# Two isolated Claude Code profiles. Source this file from ~/.zshrc.
#   claude-work      default ~/.claude  (same as plain `claude`, the IDE and scripts)
#   claude-personal  ~/.claude-personal
# CLAUDE_CONFIG_DIR isolates everything per profile, including the login: Claude Code keeps a
# separate Keychain item per config dir. Run /login once in each profile.

# Claude Code's native installer puts the binary in ~/.local/bin.
[[ :$PATH: == *:$HOME/.local/bin:* ]] || path+=("$HOME/.local/bin")

claude-work()     { (unset CLAUDE_CONFIG_DIR; claude "$@") }
claude-personal() { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude "$@" }
