# claude-profiles

Two isolated Claude Code accounts on one Mac — **work** (the default `~/.claude`) and
**personal** (`~/.claude-personal`) — with separate logins, skills, plugins, MCP servers,
settings, and history. Switching is a small menu on bare `claude`. Pure zsh, no dependencies.

## Layout

| Profile  | Config dir          | Launch with                          | Used by                         |
| -------- | ------------------- | ------------------------------------ | ------------------------------- |
| work     | `~/.claude`         | `claude-work`, bare `claude` default | the IDE, `claude -p`, scripts   |
| personal | `~/.claude-personal`| `claude-personal`                    | `code-personal` for the IDE     |

Isolation works via `CLAUDE_CONFIG_DIR` (a separate config dir per profile). On macOS each
profile gets its own Keychain login entry, so both stay signed in independently.

## Install

> Close **all** Claude Code sessions and the IDE extension first, and run this from a plain
> terminal (it refuses to run inside a Claude Code session). It moves your existing `~/.claude`
> to `~/.claude-personal` and makes a fresh `~/.claude` the work profile.

```sh
./install.sh
```

Then, in a new terminal:

```sh
source ~/.zshrc
claude-work       # in-session: /logout  then  /login   (your WORK / enterprise account)
claude-personal   # in-session: /login   (your personal account)
```

The work step needs `/logout` first because the freshly-emptied default still carries your
old (personal) login token until you replace it with the work login.

## Usage

```
claude            # menu: 1) work  2) personal  s) status   (Enter = work)
claude-work       # straight into work
claude-personal   # straight into personal
code-personal .   # open VS Code so its Claude extension uses personal (plain `code` = work)
```

Everything else — `claude -p ...`, `claude auth status`, `claude mcp ...`, scripts, the IDE —
runs the real binary untouched. Only bare, no-arg, interactive `claude` shows the menu.

One-off login check without the menu:

```sh
claude auth status
CLAUDE_CONFIG_DIR=~/.claude-personal claude auth status
```

## Update

```sh
git -C ~/Projects/Personal/claude-profiles pull   # ~/.zshrc sources the file, so this is enough
```

## Uninstall / reverse

```sh
./uninstall.sh    # removes the ~/.zshrc block; optionally moves ~/.claude-personal back to ~/.claude
```

## Notes

- `CLAUDE_CONFIG_DIR` is read at launch — switch profiles by opening a new terminal tab.
- Skills/plugins are isolated. To share one into work, re-add its marketplace inside `claude-work`.
- macOS per-profile Keychain isolation is observed behavior, not a documented guarantee. If a
  future Claude Code update ever makes the two profiles share a login, just `/login` each again —
  the config dirs stay fully isolated regardless.
