# claude-profiles

Run two Claude Code accounts on one Mac — a **work** (Enterprise) login and a **personal** (Max/Pro)
login — each with its own credentials, history, settings, and MCP servers. Profiles are selected per
terminal, so you can be **signed into both at once** in different tabs.

It's a thin layer of zsh functions over Claude Code's built-in `CLAUDE_CONFIG_DIR`, plus one small
trick for macOS (a per-profile OAuth token, explained [below](#how-it-works)). No daemon, no
background process — ~200 lines you can read top to bottom. (Plugins and skills are the exception:
they're effectively **shared**; see [What is and isn't isolated](#what-is-and-isnt-isolated).)

## Quickstart

```sh
# Install — clones, wires ~/.zshrc, installs gum, then OFFERS to set up your accounts right away.
git clone https://github.com/jorisrombouts/claude-profiles.git ~/tools/claude-profiles   # or copy this folder
cd ~/tools/claude-profiles && ./install.sh

# Everyday use — both accounts stay logged in, one per terminal:
claude-work        # work
claude-personal    # personal
claude             # menu (work / personal / status)

# Set up or change your accounts anytime (the installer runs this for you the first time):
claude-setup       # guided: detects what's done, walks you through work + personal
```

> **"work" and "personal" are just labels** for two config profiles — map them to whichever two
> accounts you like (two work orgs, work + personal, a client account, …). `claude-setup` walks you
> through both.

## Requirements

- **macOS** with **zsh** (the default shell).
- **Claude Code** installed (`claude` on your `PATH`).
- A subscription on each account (Pro/Max/Team/Enterprise) — the per-profile token needs one.
- **[gum](https://github.com/charmbracelet/gum)** for the menu + setup wizard — optional; `install.sh`
  installs it via Homebrew, and everything falls back to plain text prompts without it.

## Install

```sh
git clone https://github.com/jorisrombouts/claude-profiles.git ~/tools/claude-profiles   # clone (or copy this folder) somewhere permanent
cd ~/tools/claude-profiles
./install.sh                                    # wires ~/.zshrc, creates ~/.claude-personal, installs gum, offers setup
source ~/.zshrc                                 # or just open a new terminal
```

> Keep the cloned folder where it is — `~/.zshrc` *sources* it, so moving or deleting it breaks the
> commands (re-run `./install.sh` from the new location if you do move it).

Your **existing** `~/.claude` (whatever you're logged into now) is left untouched and becomes the
**work** profile.

## Setting up your two accounts

`install.sh` offers to run the guided setup for you. You can also run it anytime:

```sh
claude-setup
```

It detects what's already done and walks you through both accounts: confirm (or switch) your **work**
login, then set up the **personal** account (a browser opens to log in). Re-run it whenever you want to
check or change things — nothing destructive happens without a confirm.

**Why personal needs a token:** on macOS the login lives in **one shared Keychain item**, so two
profiles can't both use it — the second `/login` overwrites the first. So `claude-setup` keeps **work**
on the native Keychain login and gives **personal** its own long-lived token (stored in the Keychain),
which is what lets both stay signed in at the same time.

> **Don't run `/login` inside the personal profile.** It's authenticated by its token; a `/login` there
> would overwrite the shared (work) Keychain login. To change the personal account, run `claude-setup`
> (or `claude-set-token personal`).

Prefer to do it by hand? `claude-work` then `/login` (work); `claude-set-token personal` (personal). Or
skip the token entirely and just `/login` to switch accounts one at a time.

## Usage

```
claude              # menu: work / personal / status   (arrow keys; plain prompt without gum)
claude-work         # straight into work   (= the default ~/.claude — the IDE and scripts use this too)
claude-personal     # straight into personal
claude-setup        # guided setup / re-check both accounts (re-runnable, idempotent)
claude-set-token p  # advanced: store a token directly (p = work|personal, default personal)
```

`claude` with arguments (`claude -p …`, `claude mcp …`), the IDE, and scripts always run the real
binary on the **work** default — only bare, interactive `claude` opens the menu. Pick **status** in the
menu to see each profile's account and whether it's authenticated by `keychain` or `token`:

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
profile just falls back to the shared Keychain login, so nothing breaks before you run `claude-setup`.

Tokens are kept in the macOS Keychain (service `claude-profiles`, account `work`/`personal`) — never in
a plaintext dotfile, and they're read with hidden input so they never reach your shell history. You can
give **work** a token too (`claude-set-token work`) if you'd rather pin both; by default work stays on
its native Keychain login.

## What is (and isn't) isolated

Each profile is its own `CLAUDE_CONFIG_DIR` (`~/.claude` for work, `~/.claude-personal` for personal),
so everything Claude stores there is **per profile**. The exceptions are things that live in the **repo
you open**, and **plugins/skills** (Claude seeds those from the default dir).

| State | Per profile? | Notes |
| --- | --- | --- |
| Login / account | ✅ isolated | work = macOS Keychain, personal = its own token |
| `settings.json` / `settings.local.json` (model, permissions, hooks, env) | ✅ isolated | |
| Global `CLAUDE.md` (your user-level instructions) | ✅ isolated | `~/.claude/CLAUDE.md` vs `~/.claude-personal/CLAUDE.md` |
| Session history, transcripts, `plans/`, todos | ✅ isolated | |
| Auto-memory (`MEMORY.md` + subagent `agent-memory/`) | ✅ isolated | under each profile's `projects/…/memory/` |
| MCP servers (user-scoped) | ✅ isolated | |
| Per-folder trust / onboarding | ✅ isolated\* | \*personal re-asks every launch — upstream [#36403](https://github.com/anthropics/claude-code/issues/36403) |
| Caches, telemetry, UI prefs (themes, keybindings) | ✅ isolated | |
| **Plugins & skills** (and slash-commands — same mechanism) | 🔗 shared | Claude seeds/reads them from the default `~/.claude` regardless of `CLAUDE_CONFIG_DIR` |
| **A repo's own `CLAUDE.md` / `.claude/`** | 🔗 shared | lives in the repo, so it's identical in both profiles (by design — it belongs to the project, not you) |
| **`claude` binary, `gum`, Homebrew, your macOS user** | 🔗 shared | one install, used by everything |

**About plugins/skills:** because Claude seeds them from the default `~/.claude`, a plugin enabled in
one profile tends to appear in the other. `claude-personal` sets the (undocumented)
`CLAUDE_CODE_PLUGIN_CACHE_DIR` / `CLAUDE_CODE_PLUGIN_SEED_DIR` at its own dir as a _best-effort_ attempt
to keep them apart, but it's **unverified** — so assume plugins/skills are common to both profiles.
(Delete those two lines from `claude-personal` if plugins ever misbehave.)

**Global vs project `CLAUDE.md`:** the *global* one above is per profile; a `CLAUDE.md` committed inside
a repo is part of that repo and applies in **both** profiles when you open it.

## Token lifecycle

- A token is valid for about **a year**. When it expires, refresh it: `claude-setup` (or
  `claude-set-token personal`).
- Remove a token (fall back to the Keychain login):
  `security delete-generic-password -s claude-profiles -a personal`.
- A token is **scoped to inference only** — it can't establish [Remote
  Control](https://code.claude.com/docs/en/remote-control) sessions. If you need that on the personal
  account, remove the token (above) and `/login` instead (one account at a time).

## Update / Uninstall

```sh
git -C <clone-dir> pull    # update — the ~/.zshrc source line picks up changes automatically
./uninstall.sh             # remove the ~/.zshrc block (offers to delete stored tokens); profile dirs are left intact
```

## Renaming the profiles

Want different names (e.g. `main` / `client`)? Rename the functions and the `~/.claude-personal` path
consistently in `claude-profiles.zsh` (and in `install.sh`). Everything else follows.

## Troubleshooting

- **`command not found: claude-setup`** — you haven't `source ~/.zshrc`'d yet (or you're not in zsh).
- **`_cp_exec: command not found: claude`** — the real Claude Code binary wasn't on your `PATH` (usually
  `~/.local/bin/claude`). Re-run `source ~/.zshrc`; recent versions of this repo add that path
  automatically. If it persists, install or reinstall Claude Code: https://claude.com/claude-code
- **Menu/wizard is plain text, not styled** — `gum` isn't installed: `brew install gum`.
- **`status` shows the wrong or duplicate account for a profile** — without its own token a profile
  falls back to the *shared* Keychain login, and `status` reports that profile's last-used account
  rather than the live one. Run `claude-setup` to make it real.
- **macOS asks for Keychain permission when launching personal** — click **Always Allow** so the
  launcher can read the stored token without prompting each time.
- **`claude-personal` re-asks "Do you trust this folder?" every launch** — known upstream bug with
  token auth ([claude-code#36403](https://github.com/anthropics/claude-code/issues/36403)): sessions
  using `CLAUDE_CODE_OAUTH_TOKEN` don't persist folder trust, so just accept it each time. Harmless,
  and `claude-work` (Keychain) remembers trusted folders normally.
- **Logging into one profile signs the other out** — you ran `/login` inside personal (which overwrites
  the shared Keychain). Re-`/login` work, and authenticate personal with a token (`claude-setup`).
```
