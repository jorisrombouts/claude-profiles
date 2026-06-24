# claude-profiles

Run two Claude Code accounts on one Mac — e.g. a **work** (enterprise) login and a **personal**
(Max/Pro) login — each with its own credentials, history, settings, and MCP servers. Profiles are
selected per terminal, so you can be signed into **both at once** in different tabs. (Plugins and
skills are the exception — they're effectively **shared**; see [below](#what-is-and-isnt-isolated).)

It's a thin layer of zsh functions over Claude Code's built-in `CLAUDE_CONFIG_DIR` — no daemon, no
background process, ~70 lines you can read top to bottom.

## Requirements

- **macOS** with **zsh** (the default shell).
- **Claude Code** installed (`claude` on your `PATH`).
- **[gum](https://github.com/charmbracelet/gum)** for the picker menu — optional; `install.sh`
  installs it via Homebrew, and the menu falls back to a plain text prompt without it.

## Install

```sh
git clone <repo-url> ~/tools/claude-profiles   # clone somewhere permanent
cd ~/tools/claude-profiles
./install.sh                                   # wires ~/.zshrc, creates ~/.claude-personal, installs gum
source ~/.zshrc                                # or just open a new terminal
```

> Keep the cloned folder where it is — `~/.zshrc` *sources* it, so moving or deleting it breaks the
> commands (re-run `./install.sh` from the new location if you do move it).

Your **existing** `~/.claude` (whatever you're logged into now) is left untouched and becomes the
**work** profile. Add your second account once:

```sh
claude-personal      # then, inside the session:  /login
```

## Usage

```
claude            # menu: work / personal / status   (arrow keys; plain prompt without gum)
claude-work       # straight into work   (= the default ~/.claude — the IDE and scripts use this too)
claude-personal   # straight into personal
```

`claude` with arguments (`claude -p …`, `claude mcp …`), the IDE, and scripts always run the real
binary on the **work** default — only bare, interactive `claude` opens the menu.

Check both logins at a glance (pick **status** in the menu):

```
Claude Code login status:
  work      (~/.claude)            Claude Enterprise account (you@company.com)
  personal  (~/.claude-personal)   Claude Max account (you@personal.com)
```

## How it works

A profile is just a config directory. `claude-personal` runs with
`CLAUDE_CONFIG_DIR=~/.claude-personal`; `work` uses the default `~/.claude`. That variable lives in
the shell that launched Claude, so two terminals stay independent — which is what lets both accounts
be logged in at the same time.

## What is (and isn't) isolated

**Isolated per profile** (what matters for two accounts): login/credentials, session history,
`settings.json`, MCP servers, project trust — so two terminals stay independently logged in.

**Plugins and skills are _not_ reliably isolated — treat them as shared.** Claude Code seeds and
reads them from the default `~/.claude`, which `CLAUDE_CONFIG_DIR` doesn't govern, so a plugin
enabled in one profile tends to appear in the other. `claude-personal` sets the (undocumented)
`CLAUDE_CODE_PLUGIN_CACHE_DIR` / `CLAUDE_CODE_PLUGIN_SEED_DIR` at its own dir as a _best-effort_
attempt to keep them apart, but it's **unverified** — so assume plugins/skills are common to both
profiles. (If they still bleed, that's a known Claude Code limitation, not this tool; delete those
two lines from `claude-personal` if plugins ever misbehave.)

## Update / Uninstall

```sh
git -C <clone-dir> pull    # update — the ~/.zshrc source line picks up changes automatically
./uninstall.sh             # remove the ~/.zshrc block; your profile directories are left intact
```

## Renaming the profiles

Want different names (e.g. `main` / `client`)? Rename the functions and the `~/.claude-personal`
path consistently in `claude-profiles.zsh` (and in `install.sh`). Everything else follows.

## Troubleshooting

- **`command not found: claude-personal`** — you haven't `source ~/.zshrc`'d (or you're not in zsh).
- **Menu is a plain prompt, not arrow keys** — `gum` isn't installed: `brew install gum`.
- **Logging into one profile signs the other out** — macOS may share the Keychain login entry across
  profiles; just `/login` again. The config directories stay separate regardless.
