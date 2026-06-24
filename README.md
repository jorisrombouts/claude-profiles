# claude-profiles

Two Claude Code accounts on one Mac, each with its own login, history, settings, and MCP servers —
switchable per terminal so you can be signed into **both at the same time** (e.g. enterprise work in
one window, personal Max in another). Minimal: a few zsh functions on top of `CLAUDE_CONFIG_DIR`.

| Profile  | Config dir           | Launch with                                            |
| -------- | -------------------- | ------------------------------------------------------ |
| work     | `~/.claude`          | `claude-work`, bare `claude` default, the IDE, scripts |
| personal | `~/.claude-personal` | `claude-personal`                                      |

`work` is the default `~/.claude`, so the IDE, `claude -p`, and scripts all use it automatically.
`personal` is a separate config dir selected via `CLAUDE_CONFIG_DIR`. Each terminal carries its own
value, so two terminals stay independently logged in.

## Install

```sh
./install.sh          # creates ~/.claude-personal, wires ~/.zshrc, installs gum
source ~/.zshrc
claude-personal       # in-session: /login   (your personal account)
```

Your existing `~/.claude` is left exactly as-is and becomes the **work** default — nothing is moved.

## Usage

```
claude            # menu: work / personal / status  (gum; plain typed fallback without it)
claude-work       # straight into work (= default ~/.claude)
claude-personal   # straight into personal
```

`claude` with arguments (`claude -p ...`, `claude auth ...`, `claude mcp ...`), the IDE, and scripts
all run the real binary on the work default — only bare, interactive `claude` shows the menu.

Login status for both:

```sh
claude auth status                                        # work
CLAUDE_CONFIG_DIR=~/.claude-personal claude auth status   # personal
```

## Update

```sh
git -C ~/Projects/Personal/claude-profiles pull   # ~/.zshrc sources the file, so this is enough
```

## Uninstall

```sh
./uninstall.sh    # removes the ~/.zshrc block; leaves both profile dirs intact
```

## What is (and isn't) isolated

`CLAUDE_CONFIG_DIR` gives each profile its own **login/credentials, session history, `settings.json`,
MCP servers, and project trust** — that's what makes two simultaneous logins work.

**Plugins and skills are the exception.** Claude Code seeds/reads them from the default `~/.claude`,
which `CLAUDE_CONFIG_DIR` doesn't fully govern, so a plugin enabled in work can appear in personal.
`claude-personal` sets the (undocumented) `CLAUDE_CODE_PLUGIN_CACHE_DIR` and
`CLAUDE_CODE_PLUGIN_SEED_DIR` at its own dir as a best-effort fix; if plugins still bleed, that's a
known Claude Code limitation, not this setup. Drop those two env vars from `claude-personal` if
plugins ever misbehave.

## Notes

- `CLAUDE_CONFIG_DIR` is read at launch — switch profiles by opening a new terminal tab.
- The menu uses [`gum`](https://github.com/charmbracelet/gum); without it, bare `claude` falls back to
  a plain typed menu — everything still works, it just looks plainer.
- macOS Keychain: if logging into one profile ever signs the other out, just `/login` again — the
  config dirs stay separate regardless.
