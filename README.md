# claude-profiles

Run two Claude Code accounts on one Mac — a **work** (Enterprise) login and a **personal** (Max/Pro)
login — each with its own credentials, history, settings, and MCP servers. Profiles are selected per
terminal, so you can be **signed into both at once** in different tabs.

It's a thin layer of zsh functions over Claude Code's built-in `CLAUDE_CONFIG_DIR`, plus one small
trick for macOS (a per-profile OAuth token, explained [below](#how-it-works)). No daemon, no
background process — ~150 lines you can read top to bottom. (Plugins and skills are the exception:
they're effectively **shared**; see [What is and isn't isolated](#what-is-and-isnt-isolated).)

## Quickstart

```sh
# 1. Put the tool somewhere permanent and install it
git clone <repo-url> ~/tools/claude-profiles    # or just copy this folder there
cd ~/tools/claude-profiles && ./install.sh && source ~/.zshrc

# 2. Log into your FIRST account — it becomes "work" (the default ~/.claude)
claude-work                           # then, in the session:  /login

# 3. Add a SECOND account ("personal") that stays logged in at the same time
claude-profiles set-token personal    # runs `claude setup-token`: log in as account #2, paste the token

# Done — use them in separate tabs, both logged in at once:
claude-work               # account #1
claude-personal           # account #2
claude-profiles status    # see both logins at a glance
```

> **"work" and "personal" are just labels** for two config profiles — map them to whichever two
> accounts you like (two work orgs, work + personal, a client account, …). On macOS the second one
> needs its own token; step 3 sets that up. That's the whole tool.

## Requirements

- **macOS** with **zsh** (the default shell).
- **Claude Code** installed (`claude` on your `PATH`).
- A subscription on each account (Pro/Max/Team/Enterprise) — the per-profile token needs one.
- **[gum](https://github.com/charmbracelet/gum)** for the picker menu — optional; `install.sh`
  installs it via Homebrew, and the menu falls back to a plain text prompt without it.

## Install

```sh
git clone <repo-url> ~/tools/claude-profiles   # clone (or copy this folder) somewhere permanent
cd ~/tools/claude-profiles
./install.sh                                    # wires ~/.zshrc, creates ~/.claude-personal, installs gum
source ~/.zshrc                                 # or just open a new terminal
```

> Keep the cloned folder where it is — `~/.zshrc` *sources* it, so moving or deleting it breaks the
> commands (re-run `./install.sh` from the new location if you do move it).

Your **existing** `~/.claude` (whatever you're logged into now) is left untouched and becomes the
**work** profile.

## Set up two accounts that stay logged in at once

On macOS the login is stored in **one shared Keychain item**, so two profiles can't both use it at the
same time — the second `/login` overwrites the first. The fix: keep **work** on the native Keychain
login, and give **personal** its own token.

```sh
# 1) Work uses the normal Keychain login:
claude-work                       # then inside the session:  /login   (your work / Enterprise account)

# 2) Personal gets its own token (one time):
claude-profiles set-token personal
#    -> runs `claude setup-token`; sign in as your PERSONAL account, copy the token, paste it back.
```

That's it — a work tab and a personal tab now stay logged in **independently**.

> **Don't run `/login` inside the personal profile.** It's authenticated by its token; a `/login`
> there would overwrite the shared (work) Keychain login. To change the personal account, re-run
> `claude-profiles set-token personal`.

Prefer to keep it simple? Skip step 2 and just `/login` again whenever you switch accounts (one at a
time, not both-at-once).

## Usage

```
claude                   # menu: work / personal / status   (arrow keys; plain prompt without gum)
claude-work              # straight into work   (= the default ~/.claude — the IDE and scripts use this too)
claude-personal          # straight into personal
claude-profiles status   # show both logins + auth mode
claude-profiles help     # all commands
```

`claude` with arguments (`claude -p …`, `claude mcp …`), the IDE, and scripts always run the real
binary on the **work** default — only bare, interactive `claude` opens the menu.

`status` shows each profile's account and whether it's authenticated by `keychain` or `token`:

```
Claude Code login status:
  work       (~/.claude)            auth:keychain  Claude Enterprise account (you@company.com)
  personal   (~/.claude-personal)   auth:token     Claude Max account (you@personal.com)
```

## How it works

A profile is just a config directory. `claude-personal` runs with
`CLAUDE_CONFIG_DIR=~/.claude-personal`; `work` uses the default `~/.claude`. That variable lives in the
shell that launched Claude, so two terminals stay independent.

`CLAUDE_CONFIG_DIR` isolates almost everything — **except the login on macOS**:

| Platform | Easy account switching | Both signed in at once |
| --- | --- | --- |
| Linux / Windows | ✅ | ✅ — credentials are a per-directory `.credentials.json` |
| **macOS** | ✅ | ⚠️ needs a per-profile token — the login is one shared Keychain item |

So on macOS, `claude-personal` injects `CLAUDE_CODE_OAUTH_TOKEN` (read from the Keychain) when a token
is stored for it. That token sits **above** the shared Keychain login in Claude Code's [auth
precedence](https://code.claude.com/docs/en/authentication), so a personal tab authenticates as the
personal account while a work tab uses the Keychain — both at the same time. No stored token? The
profile just falls back to the shared Keychain login, so nothing breaks before you run `set-token`.

Tokens are kept in the macOS Keychain (service `claude-profiles`, account `work`/`personal`) — never in
a plaintext dotfile. You can give **work** a token too (`claude-profiles set-token work`) if you'd
rather pin both; by default work stays on its native Keychain login.

## What is (and isn't) isolated

**Isolated per profile:** login/credentials, session history, `settings.json`, MCP servers, project
trust — so two terminals stay independently logged in.

**Plugins and skills are _not_ reliably isolated — treat them as shared.** Claude Code seeds and reads
them from the default `~/.claude`, which `CLAUDE_CONFIG_DIR` doesn't govern, so a plugin enabled in one
profile tends to appear in the other. `claude-personal` sets the (undocumented)
`CLAUDE_CODE_PLUGIN_CACHE_DIR` / `CLAUDE_CODE_PLUGIN_SEED_DIR` at its own dir as a _best-effort_
attempt to keep them apart, but it's **unverified** — so assume plugins/skills are common to both
profiles. (Delete those two lines from `claude-personal` if plugins ever misbehave.)

## Token lifecycle

- A `setup-token` token is valid for about **a year**. When it expires, refresh it:
  `claude-profiles set-token personal`.
- Remove a token (fall back to the Keychain login): `claude-profiles remove-token personal`.
- A token is **scoped to inference only** — it can't establish [Remote
  Control](https://code.claude.com/docs/en/remote-control) sessions. If you need that on the personal
  account, use `remove-token` and `/login` instead (one account at a time).

## Update / Uninstall

```sh
git -C <clone-dir> pull    # update — the ~/.zshrc source line picks up changes automatically
./uninstall.sh             # remove the ~/.zshrc block (offers to delete stored tokens); profile dirs are left intact
```

## Renaming the profiles

Want different names (e.g. `main` / `client`)? Rename the functions and the `~/.claude-personal` path
consistently in `claude-profiles.zsh` (and in `install.sh`). Everything else follows.

## Troubleshooting

- **`command not found: claude-personal`** — you haven't `source ~/.zshrc`'d (or you're not in zsh).
- **Menu is a plain prompt, not arrow keys** — `gum` isn't installed: `brew install gum`.
- **`status` shows the same account for both** — you haven't set a personal token yet; run
  `claude-profiles set-token personal`.
- **macOS asks for Keychain permission when launching personal** — click **Always Allow** so the
  launcher can read the stored token without prompting each time.
- **Logging into one profile signs the other out** — you ran `/login` inside personal (which overwrites
  the shared Keychain). Re-`/login` work, and authenticate personal with a token instead.
