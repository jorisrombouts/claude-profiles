# claude-profiles

Two Claude Code accounts on one Mac, **work** and **personal**, each signed in at the same time in
different terminals. Each profile has its own login, settings, history, memory, plugins and MCP servers.

It is two zsh functions over Claude Code's `CLAUDE_CONFIG_DIR`.

## Install

```sh
git clone https://github.com/jorisrombouts/claude-profiles.git ~/tools/claude-profiles
echo 'source ~/tools/claude-profiles/claude-profiles.zsh' >> ~/.zshrc
source ~/.zshrc
```

Then log in once per profile: run `claude-work` and `/login` with the work account, then
`claude-personal` and `/login` with the personal account.

## Usage

```
claude-work        # work: the default ~/.claude, same as plain `claude`, the IDE and scripts
claude-personal    # personal: ~/.claude-personal
```

Both accept the usual `claude` arguments, e.g. `claude-personal auth status`.

## How it works

`claude-personal` runs `claude` with `CLAUDE_CONFIG_DIR=~/.claude-personal`; `claude-work` runs it with
the variable unset, so the default `~/.claude` applies. Claude Code stores everything under that
directory and keeps the login in a Keychain item tied to it (`Claude Code-credentials` for the default
directory, `Claude Code-credentials-<hash>` for any other), so a `/login` in one profile leaves the other
signed in.

Not isolated: a repo's own `CLAUDE.md` and `.claude/` (they belong to the repo), and the `claude` binary.

Also not isolated: the Chrome integration. Chrome has one native-host slot for Claude Code, and its wrapper
runs `claude` without `CLAUDE_CONFIG_DIR`, so the browser is bound to the work profile. Both profiles detect
the extension; the personal profile keeps it off via `"claudeInChromeDefaultEnabled": false` in its
`settings.json`.

The file also appends `~/.local/bin`, where Claude Code's native installer puts `claude`, to `PATH` when
it is missing.

## Uninstall

Remove the `source …/claude-profiles.zsh` line from `~/.zshrc`. `~/.claude-personal` is left in place.
