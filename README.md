# claude-profiles

Several Claude Code accounts on one Mac, each signed in at the same time in its own terminal. Every
profile has its own login, settings, history, memory, plugins and MCP servers.

One zsh file over Claude Code's `CLAUDE_CONFIG_DIR`. No dependencies beyond `claude` itself.

## Install

```sh
git clone https://github.com/jorisrombouts/claude-profiles.git ~/tools/claude-profiles
echo 'source ~/tools/claude-profiles/claude-profiles.zsh' >> ~/.zshrc
source ~/.zshrc
```

Your existing `~/.claude` is the default profile. Add a second one and log in:

```
claude-profile add personal
claude-personal          # then /login with the other account
```

To give the default profile a name of your own, set it before the `source` line:

```sh
CLAUDE_PROFILES_DEFAULT=work
source ~/tools/claude-profiles/claude-profiles.zsh
```

## Usage

```
claude                          the default profile, as always
claude-<name>                   any other profile; accepts the usual claude arguments

claude-profile                  list profiles
claude-profile add <name>       create ~/.claude-<name> and the claude-<name> launcher
claude-profile remove <name>    delete a profile (asks first)
claude-profile status           login method and email per profile
```

Names use lowercase letters, digits, `-` and `_`.

## How it works

A profile is a directory: `~/.claude` for the default, `~/.claude-<name>` for the rest. Sourcing the file
defines one launcher per directory. `claude-<name>` runs `claude` with `CLAUDE_CONFIG_DIR` pointing at
that directory; the default profile's launcher runs it with the variable unset.

Claude Code stores everything under that directory and keeps the login in a Keychain item tied to it
(`Claude Code-credentials` for the default, `Claude Code-credentials-<hash>` for any other), so a `/login`
in one profile leaves the others signed in.

The file also appends `~/.local/bin`, where Claude Code's native installer puts `claude`, to `PATH` when
it is missing.

## What is and is not isolated

| Per profile | Shared |
|---|---|
| login and organisation | the `claude` binary and its version |
| `settings.json`, memory, history | a repo's own `CLAUDE.md` and `.claude/` |
| plugins, marketplaces, org-synced plugins | Chrome integration |
| MCP servers, projects, sessions | |

Chrome has one native-host registration for Claude Code, and it runs `claude` without
`CLAUDE_CONFIG_DIR`, so the browser belongs to the default profile. `claude-profile add` writes
`"claudeInChromeDefaultEnabled": false` into each new profile so it stays that way.

## Uninstall

Remove the `source` line from `~/.zshrc`. Profile directories are left in place; delete the ones you
no longer want.

## Development

```
zsh test.zsh
```

Runs against a temporary `HOME` with a stub `claude`; prints `ok` or the first failing check.
