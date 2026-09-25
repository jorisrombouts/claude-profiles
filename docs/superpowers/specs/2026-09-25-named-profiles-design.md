# Named profiles

## Goal

Turn the two hardcoded launchers into a small tool others can install: any number of named Claude Code
profiles, each fully isolated by `CLAUDE_CONFIG_DIR`, managed from one zsh file.

## Scope

- zsh only. macOS is the target; the file must not break on Linux zsh.
- One file, `claude-profiles.zsh`, sourced from `~/.zshrc`. No installer, no dependencies beyond
  `claude` on `PATH`.
- No token layer, no wizard, no shadowing of the `claude` binary.

## Profiles

- `~/.claude` is the default profile. Its name is `$CLAUDE_PROFILES_DEFAULT` if set before sourcing,
  else `default`.
- Every directory `~/.claude-<name>` is a profile named `<name>`.
- Names match `^[a-z0-9][a-z0-9_-]*$`. The default profile's name cannot collide with a
  directory-derived name.
- Discovery happens at source time and again inside every `claude-profile` command, so a profile added
  by hand is seen on the next command without re-sourcing.

## Launchers

- One function `claude-<name>` per discovered profile, defined at source time and by `add`.
- `claude-<name> "$@"` runs `claude "$@"` with `CLAUDE_CONFIG_DIR=~/.claude-<name>`. The default
  profile's launcher runs `claude` with the variable unset, in a subshell so nothing leaks.
- Plain `claude` is untouched.
- `~/.local/bin` is appended to `PATH` when missing.

## `claude-profile` command

| Invocation | Behaviour |
|---|---|
| `claude-profile` or `list` | One line per profile: name, directory, `(default)` marker. |
| `add <name>` | Validate the name, refuse if the directory exists, `mkdir`, write `settings.json` with `{"claudeInChromeDefaultEnabled": false}`, define the launcher, print `run claude-<name> and /login`. |
| `remove <name>` | Refuse the default. Refuse unknown names. Print the directory, ask `y/N`, `rm -rf` on yes. |
| `status` | For each profile: name, then `Login method` and `Email` parsed from `claude auth status --text` with stdin from `/dev/null`. `not logged in` when the output has neither. |
| `help`, `-h`, `--help`, unknown | Usage text. Unknown returns 1. |

All error paths print one line to stderr and return 1: invalid name, existing profile on `add`,
unknown profile on `remove`, default on `remove`, `claude` not on `PATH` for `status`.

## Isolation notes

Documented in the README and, where possible, enforced:

- Login, settings, plugins, marketplaces, synced org plugins, MCP servers, history, projects and memory
  live under the config dir and are per profile. Claude Code keeps one Keychain item per config dir.
- Chrome integration is shared. Chrome has one native-host registration for Claude Code and it runs
  `claude` without `CLAUDE_CONFIG_DIR`, so the browser belongs to the default profile. `add` writes
  `claudeInChromeDefaultEnabled: false` into the new profile so it stays that way.
- The `claude` binary is shared. A repo's own `CLAUDE.md` and `.claude/` belong to the repo.

## README

Rewritten for the general case: what it is, install (clone, one `source` line, optional
`CLAUDE_PROFILES_DEFAULT`), first profile (`claude-profile add personal`, `claude-personal`, `/login`),
command reference, how it works, what is and is not isolated, uninstall. Work and personal appear only
as examples.

## Tests

`test.zsh`, runnable with `zsh test.zsh`, exits non-zero on the first failure. It sets `HOME` to a
temporary directory with a stub `claude` on `PATH` that prints `CLAUDE_CONFIG_DIR` and its arguments,
then checks:

- Sourcing with `~/.claude-a` and `~/.claude-b` present defines `claude-a`, `claude-b` and the default
  launcher, and `list` shows all three with the default marked.
- `claude-a --version` reaches the stub with `CLAUDE_CONFIG_DIR=$HOME/.claude-a`; the default launcher
  reaches it with the variable unset, even when it was set in the caller.
- `add c` creates the dir, the settings file with the Chrome flag, and the `claude-c` function; a
  second `add c` fails; `add "Bad Name"` fails.
- `remove` of the default fails; `remove` of an unknown name fails; `remove b` with `y` on stdin deletes
  the dir; with `n` it does not.
- `status` parses the stub's fake `auth status --text` output into `method (email)` per profile.

## Out of scope

bash and fish, Homebrew tap, shell completions, renaming or relocating profiles, a bare `claude` menu.
