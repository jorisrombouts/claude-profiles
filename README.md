# claude-profiles

Two Claude Code accounts on one Mac — **work** (the default `~/.claude`) and
**personal** (`~/.claude-personal`) — with separate logins, MCP servers, settings, project history,
and memory. (Plugins and skills are **not** fully isolated — see [Known limitations](#known-limitations).)
Switching is a menu on bare `claude` — a polished arrow-key UI via
[`gum`](https://github.com/charmbracelet/gum), with a pure-zsh plain-menu fallback if gum isn't installed.

## Layout

| Profile  | Config dir          | Launch with                          | Used by                         |
| -------- | ------------------- | ------------------------------------ | ------------------------------- |
| work     | `~/.claude`         | `claude-work`, bare `claude` default | the IDE, `claude -p`, scripts   |
| personal | `~/.claude-personal`| `claude-personal`                    | `code-personal` for the IDE     |

Isolation works via `CLAUDE_CONFIG_DIR` (a separate config dir per profile) — with the exception
of plugins and skills (see [Known limitations](#known-limitations)).

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
claude            # arrow-key menu: work / personal / status  (gum; plain typed fallback without it)
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
- The menu uses [`gum`](https://github.com/charmbracelet/gum) for the arrow-key UI; `install.sh`
  installs it via Homebrew. Without gum, bare `claude` falls back to a plain typed menu —
  everything still works, it just looks plainer.

## Known limitations

`CLAUDE_CONFIG_DIR` isolates most state, but **not the plugin/skill subsystem** — this is a Claude
Code limitation this setup can't fully fix.

**Isolated** per profile: logins, MCP servers, `settings.json` (including the `enabledPlugins`
list), `.claude.json` (project history + trust), session history, and the user-level `CLAUDE.md`.

**Shared / not isolated** (they fall back to the default `~/.claude`):

- **Plugins** — on launch, Claude Code seeds/syncs plugin payloads from `~/.claude/plugins`, so a
  plugin enabled in one profile shows up (and may activate) in the other's `/plugin` view, and its
  files land in both `plugins/cache/` dirs. The plugin system has its own *undocumented* env vars
  (`CLAUDE_CODE_PLUGIN_CACHE_DIR`, `CLAUDE_CODE_PLUGIN_SEED_DIR`, `CLAUDE_CODE_SYNC_PLUGINS`) that
  `CLAUDE_CONFIG_DIR` does **not** set. Pointing those at each profile's own dir *may* isolate
  plugins, but it's experimental and untested here.
- **Skills** (`~/.claude/skills/`) appear to behave the same way.
- **macOS Keychain** — the login entry may be shared across profiles. If signing into one logs the
  other out, just `/login` again; the config dirs stay separate regardless.

Bottom line: treat plugins/skills as shared across both profiles. Everything that defines *who
you're logged in as* and *your settings/history* is properly separated.
