# Cold Brew

**Close your MacBook's lid and let your AI agents keep working.**

[![Download for macOS](https://img.shields.io/github/v/release/liam-machine/cold-brew?label=Download%20for%20macOS&logo=apple&style=for-the-badge&color=8a5a2b)](https://github.com/liam-machine/cold-brew/releases/latest/download/ColdBrew.dmg)

Website: **[cold-brew.liam-is-an.ai](https://cold-brew.liam-is-an.ai)**

Claude Code, Codex and other terminal agents stop the moment you close the lid, because macOS sleeps. Cold Brew adds a coffee cup to your menu bar. The moment an agent starts working, the cup fills: closing the lid then turns the screen off but keeps the Mac awake **while an agent is busy**. When they've all finished, it switches itself back off and puts the closed Mac to sleep. Press <kbd>⌃0</kbd> (or click the cup) to switch it off for the agents running now, or [turn the automatic part off](#settings) and fill the cup only when you ask.

No external display, no keyboard or mouse plugged in, no power adapter required.

**Why "Cold Brew"?** It keeps things cool. With the lid closed, the apps your agents aren't using drop to the lowest CPU and disk priority, so they draw less power while the agents work, and they're back at full speed when the lid opens. What an agent needs stays at full strength: where it runs, what it started (a simulator, a browser it drives) and the apps you list ([more](#everything-the-agent-uses-keeps-running-everything-else-is-slowed)). Browser agents work in the dark too: Claude in Chrome, Playwright and other tools that drive a browser keep seeing and clicking pages with the display off and the Mac locked.

## Install

**[Download Cold Brew (.dmg)](https://github.com/liam-machine/cold-brew/releases/latest/download/ColdBrew.dmg)**, drag it into Applications and open it. On first launch it asks once for your password (see [Permissions](#permissions-and-exactly-what-the-installer-changes)), and then the cup appears in your menu bar.

Or from a terminal:

```bash
curl -fsSL https://github.com/liam-machine/cold-brew/releases/latest/download/install.sh | bash
```

<sub>macOS 13 or later, Apple Silicon or Intel, on an administrator account. Signed with a Developer ID and notarized by Apple. Free and MIT licensed.</sub>

## How you use it

| You do | What happens |
|---|---|
| Start an agent | Within a few seconds the cup fills in and shows how many agents are busy. Close the lid whenever. (Turned **Keep running whenever an agent starts** off under **Settings**? Then fill it yourself: below.) |
| Click the cup → **When the lid closes** → **Keep running while agents work** (or press <kbd>⌃0</kbd>) | The same, by hand. **Keep running for 3 hours** stays on even when no agent is working. |
| Close the lid while an agent works | The screen goes off; the agent keeps going. |
| Your agents finish | About 3 minutes later the cup empties and a closed Mac goes to sleep. The next agent to start fills it again. |
| Click the cup → **Sleep (normal)** (or press <kbd>⌃0</kbd> again) | Back to normal: closing the lid sleeps the Mac. The agents running now stay that way; once they've all finished, the next one to start fills the cup again. |

The cup's menu also lists the agents that are running, each one **working** or **needs you**; click one to go to it (see below). Everything you set once is under **Settings**.

The same controls from a terminal:

```bash
agents keep            # keep running while agents are busy (no time limit; battery floor applies)
agents keep 2h         # …but no longer than 2 hours
agents keep --always   # even when no agent is busy (3h)
agents pause           # normal lid-close sleep (until the agents running now finish)
agents auto off        # keep only when you ask, not whenever an agent starts (agents auto on: back)
agents apps            # which apps stay at full speed with the lid closed, and which are slowed
agents apps keep Blender   # never slow an app an agent uses (agents apps drop Safari, agents apps reset)
agents                 # status
agents busy            # which agents count as busy (or need you), and in which folder
agents focus 12345     # bring that agent's terminal or editor to the front, at its tab
agents wait 10         # a closed Mac stays awake 10 min for an agent that needs you (default 3)
agents integrate       # let Cold Brew see when Codex and OpenCode are busy, and when an agent needs you
agents remote on       # new Claude Code sessions connect to Remote Control, so you can answer from your phone
agents hotkey ctrl+opt+cmd+l   # change the hotkey (or none); applies within seconds
agents update          # install the latest release
```

## Any terminal: Ghostty, cmux, Superset, IDEs

Cold Brew looks at processes, not at the app they run in, so agents count the same in Ghostty, cmux, Superset, Terminal, iTerm, tmux or an IDE's terminal. Wrappers that those apps put in front of `claude`, `codex` or `opencode` keep the agent's process name. Agents installed through npm, bun or pip run as `node` or `python`; for those the script name counts, so `node …/bin/gemini` is Gemini CLI.

**Click an agent to go to it.** In the cup's **Agents** list, or with `agents focus <pid>`. The app is whichever one the agent runs in, found from its processes, so any terminal or editor works, listed here or not. Where the app has a way in, you land on the agent's own tab:

| Where the agent runs | Where you land |
|---|---|
| cmux | its tab (cmux's command line) |
| Terminal, iTerm2 | its tab. The first time, macOS asks to let Cold Brew control that app (Privacy & Security → Automation) |
| tmux | its pane, then the terminal tab of whoever used that session last |
| WezTerm; kitty with `listen_on` set | its pane or window |
| VS Code, Cursor, Ghostty, Warp, Superset, Zed, JetBrains, anything else | the app, brought to the front |

Selecting a window or tab in any app would need the Accessibility permission, which Cold Brew doesn't ask for.

## Everything the agent uses keeps running; everything else is slowed

With the lid closed and keep on, the whole Mac stays awake, not just the agent: VS Code, a simulator, a browser, Docker and dev servers all keep running. To give the agents the Mac's attention, Cold Brew **slows every app they aren't using**. Those apps drop to background priority (`taskpolicy -b`: they keep running, with the lowest CPU and disk priority) and are back at full speed the moment you open the lid or keep switches off.

Never slowed:

| What | Why |
|---|---|
| The app an agent runs in (VS Code, Cursor, cmux, Terminal, iTerm…) | Found from the process tree. Slowing it would slow the agent's own terminal. |
| Any app an agent started (a simulator, a browser it drives) | Also found from the process tree. |
| **Keep at Full Speed** list: Simulator, Xcode, Docker, OrbStack and the common browsers | For apps an agent uses without starting them, such as your own Chrome through an extension. Change it under the cup → **Settings** → **Keep at Full Speed**, or `agents apps keep Blender` / `drop Safari` / `reset`. |
| An app that told macOS it's busy (a call, audio, Chrome capturing a tab) | It holds a power assertion. |
| Anything outside `/Applications` and `~/Applications` | System processes, command-line tools (node, python, a dev server) and Playwright's browsers are never touched. |

Turn it off under **Settings** → **Slow other apps while the lid is closed**, or `agents apps off`. `agents apps` shows what's kept and what would be slowed right now. It needs no permission: an app you run can always be moved to background priority and back.

Two things it can't change, because macOS doesn't allow it: with the lid shut there's no screen, so a browser or the iOS Simulator stops drawing and screenshots of the screen come back black. Headless browsers (Playwright), `simctl`, builds and servers aren't affected. And macOS's own App Nap still slows apps whose windows can't be seen. Use an external display if an agent needs to see the screen.

## Codex and OpenCode

Claude Code tells Cold Brew when it's working. Codex and OpenCode don't by default, so a session waiting on the model or on a long test run can look idle. Run this once:

```bash
agents integrate
```

| Agent | What `agents integrate` does | Then |
|---|---|---|
| Codex | Runs `codex features enable prevent_idle_sleep`, Codex's own setting, in each Codex home it finds (`$CODEX_HOME`, `~/.codex`, and Superset's Codex account if you use one). Codex then holds a sleep assertion while a turn runs, which Cold Brew reads. | Busy for the whole turn in interactive sessions. `codex exec` doesn't take the assertion, so it counts only by CPU use. |
| OpenCode | Copies a small plugin to `~/.config/opencode/plugins/lid-agents.js`. It holds `caffeinate` while any session is busy, the same signal Claude Code gives. OpenCode loads it next to the plugins Superset and cmux add. | Busy for the whole task. |

Restart sessions that are already open to pick it up.

## When an agent needs you

An agent stopped on a permission prompt or a question isn't working: it's waiting for an answer. `agents integrate` tells Cold Brew when that happens, and the agent shows as **needs input** in `agents busy` and as **needs you** in the cup's **Agents** list.

- **Lid closed:** the Mac stays awake for **3 minutes** by default, so you have a moment to answer, for example from your phone, and then it sleeps unless something else is still working. Choose the time under the cup → **Settings** → **Wait for your answer** (3, 10, 30 or 60 minutes), or run `agents wait 10`. It applies straight away, even to a keep that's already running.
- **Lid open:** the agent counts as busy, because you may be there reading the prompt, so keep doesn't switch off under you.
- **You answered:** anything the agent starts afterwards that runs for 10 seconds or more, such as an approved test suite or `gh run watch`, means it's working again, even before its next hook fires. So a closed Mac doesn't sleep partway through an approved task.

| Agent | How it's told |
|---|---|
| Claude Code | Hooks in `~/.claude/settings.json`: its permission-prompt and question notifications mark it, its next event (a prompt, a tool finishing, the turn ending) clears it. |
| Codex | Hooks in `hooks.json` in each Codex home: `PermissionRequest` and its `request_user_input` question tool mark it, the next event clears it. Codex asks you to review new hooks once (`/hooks` in a Codex session); Codex started by Superset runs them as they are. |
| OpenCode | The same plugin, on `permission.asked` and `question.asked`. |

The hooks run `agents mark` and do nothing else: they print nothing, always succeed, and are tagged `# lid-agents-hook`, so re-running `agents integrate` replaces them and `agents uninstall` removes them, leaving any other hooks alone. The first change to each file keeps a `.lid-agents.bak` copy next to it. An agent that's using CPU again, or has started a long-running command since the prompt, counts as busy straight away. Editing a settings file never replaces it: an unreadable or invalid file is left alone, a file that wouldn't change isn't rewritten, and its permissions are kept.

## Answer from your phone

Close the lid, walk away, and still answer an agent that needs you. Claude Code's [Remote Control](https://code.claude.com/docs/en/remote-control) connects a session on your Mac to [claude.ai/code](https://claude.ai/code) and the Claude app for iOS and Android, and the app gets a push when the agent stops on a permission prompt or a question. Cold Brew keeps the Mac awake for it (see the wait time above) and turns it on for you:

- **Every new Claude Code session connects.** Once setup is done, Cold Brew asks you once, explaining what Remote Control does (it doesn't ask if you've already chosen in `/config`). Change it any time under the cup → **Settings** → **Connect new Claude sessions to your phone**, or with `agents remote on`. `agents integrate` turns it on too, unless you've already chosen either way. It sets Claude Code's own `remoteControlAtStartup` (the same as **Enable Remote Control for all sessions** in `/config`) and, unless you've chosen otherwise, **Push when actions required** (`inputNeededNotifEnabled`). `agents remote off` or the same menu item turns it off for new sessions.
- **Sessions that were already open are named.** Claude Code only connects a running session from inside it, so Cold Brew can't do it for you. When you switch keep on, the notification names any busy Claude session that isn't connected. In the cup's **Agents** list a connected Claude session has a phone in front of it and one that isn't has ⚠, and `agents` and `agents remote` name them too. Run `/remote-control` in each before you close the lid.

Remote Control needs a claude.ai Pro, Max, Team or Enterprise plan (Team and Enterprise: an Owner switches it on), and the Mac needs its own internet connection while the lid is closed. A session only appears in your own account. Cold Brew tells connected sessions apart by a field in Claude Code's `~/.claude/sessions/<pid>.json`, which isn't documented, so if a Claude Code update changes it, the warning stays quiet rather than wrong.

## Why this needs a tool

macOS has two kinds of sleep:

- **Idle sleep**, when nobody touches the Mac for a while. `caffeinate`, Amphetamine-style apps and Claude Code itself already block it. Claude Code runs `caffeinate -i -t 300` for as long as it's working.
- **Lid-close sleep**, triggered by the hardware lid sensor. No power assertion can override it. Apple only skips it in "clamshell mode", which needs an external display, keyboard, mouse **and** power.

The one switch that covers the lid is `pmset -a disablesleep 1`. It is global and easy to forget, which is the dangerous part: a Mac that stays awake in a bag gets hot and flattens its battery. Cold Brew handles it for you:

- **Only while agents work.** An agent counts as busy if it has a `caffeinate` child (Claude Code holds one only while working, and so does OpenCode with the plugin), holds a sleep assertion itself (Codex with `prevent_idle_sleep`), or uses 5% or more CPU. A session left open and idle in a terminal tab doesn't count.
- **Turns itself off** after 3 idle minutes, or when the battery reaches 15%. There's no time limit while agents work (give one with `agents keep 4h`). If the lid is closed when that happens, the Mac goes to sleep straight away.
- **The screen sleeps and the Mac locks.** Closing the lid only turns the backlight off, and macOS waits for its display-sleep timer, which any app holding the display awake stops (a Chrome tab using the camera or sharing the screen, a video). So when the lid closes, Cold Brew puts the display to sleep straight away, and the Mac locks as usual. With a monitor plugged in (clamshell mode) the display is left alone.

## Permissions, and exactly what the installer changes

| What | Why | Where |
|---|---|---|
| Your password, **once** (the installer, or the app's first-launch prompt) | Adds a sudoers rule allowing exactly `/usr/bin/pmset -a disablesleep 0` and `… 1`, nothing else. Sudo matches the arguments literally, so the rule can't be used for anything else. | `/etc/sudoers.d/lid-agents` |
| "Allow notifications" prompt | Notifications when you switch, and when it pauses itself | System Settings → Notifications → Cold Brew |
| Nothing else | The hotkey uses `RegisterEventHotKey`, which needs **no** Accessibility or Input Monitoring permission. Slowing other apps uses `taskpolicy` on your own apps, which needs no permission either. | — |

Files: `Cold Brew.app` (in `/Applications` from the DMG, `~/Applications` from the one-liner), the `agents` link in `~/.local/bin`, a login item in `~/Library/LaunchAgents/io.github.liam-machine.lid-agents.plist`, and a log in `~/.cache/lid-agents/`. `agents integrate`, which you run yourself, adds `~/.config/opencode/plugins/lid-agents.js`, sets `prevent_idle_sleep` in `~/.codex/config.toml`, and adds tagged hooks to `~/.claude/settings.json` and `~/.codex/hooks.json`. It and `agents remote` also set `remoteControlAtStartup` and `inputNeededNotifEnabled` in `~/.claude/settings.json`, Claude Code settings that `agents uninstall` leaves as they are. The app is built from this repo by GitHub Actions, signed with a Developer ID and notarized by Apple, so Gatekeeper opens it without warnings however you install it.

## Settings

| Setting | Default | How to change |
|---|---|---|
| Hotkey | ⌃0 | The cup → **Settings** → **Hotkey** → pick a preset, **None**, or **Record New Hotkey…** and press the keys you want; or `agents hotkey ctrl+opt+cmd+l` in a terminal. It applies immediately. It needs ⌃, ⌥ or ⌘ with a letter, number or Space. |
| Agents watched | `claude codex gemini aider opencode amp goose cursor-agent droid` | `AGENTS_NAMES` |
| Idle minutes before pausing | 3 | `AGENTS_IDLE_MINUTES` |
| CPU % that counts as busy (an agent plus its child processes) | 5 | `AGENTS_CPU` |
| Slow other apps while the lid is closed | On | The cup → **Settings** → **Slow other apps while the lid is closed**, or `agents apps off` / `on` |
| Apps never slowed | Simulator, Xcode, Docker, OrbStack, Google Chrome, Chromium, Safari, Firefox, Arc, Brave Browser, Microsoft Edge | The cup → **Settings** → **Keep at Full Speed**, or `agents apps keep <app>` / `drop <app>` / `reset` |
| Keep running whenever an agent starts | On | The cup → **Settings** → **Keep running whenever an agent starts**, or `agents auto off` / `on`. Needs the menu bar app running. |
| Minutes a closed Mac stays awake for an agent that needs your answer | 3 | The cup → **Settings** → **Wait for your answer**, `agents wait 10`, or `AGENTS_WAIT_MINUTES` |
| Minutes an agent may sit "busy" at almost no CPU, usually waiting on you, before pausing | 30 | `AGENTS_QUIET_MINUTES` |
| Time limit while agents work (hours) | none | `AGENTS_HOURS`, or `agents keep 4h` |
| Battery floor | 15% | `AGENTS_MIN_BATTERY` |

The `AGENTS_*` variables apply to the `agents` command in your shell. The menu bar app uses the defaults.

## Safety

- **Never put the Mac in a bag while the cup is full.** With the lid shut it can't get rid of heat. Cold Brew pauses when your agents finish, but a long task can still run for hours. The cup fills by itself when an agent starts, so glance at it (or press <kbd>⌃0</kbd>) before you pack up.
- When the battery floor, a time limit you set or a prompt you didn't answer switches keep off, it stays off until those agents have finished, so it can't switch straight back on.
- Plug in for long runs, and run agents in `tmux` or a terminal that survives disconnects.
- Your lock screen still works: a closed, awake Mac is locked as usual.

## Updates

Once a day, Cold Brew asks GitHub's public API for the latest release. That one anonymous request sends nothing about you or your Mac. When there's a newer version, you get **one notification**, and **Update to x.y.z** appears at the top of the cup's menu. Clicking it installs the update and reopens the app a few seconds later, with no password. It never updates on its own. If an agent is running with the lid closed while it updates, it keeps running.

- Check now: the cup → **Settings** → **Check for Updates…**, or `agents update` in a terminal.
- Turn off the daily check: `defaults write io.github.liam-machine.lid-agents CheckForUpdates -bool false`

## Uninstall

```bash
agents uninstall
```

This switches lid-close sleep back on and removes the app, the command, the login item, the sudoers rule (asking for your password), the OpenCode plugin and the log. Codex's `prevent_idle_sleep` is a Codex setting, so it stays on; `codex features disable prevent_idle_sleep` turns it off.

## Troubleshooting

- **No cup in the menu bar.** Open **Cold Brew** from Applications (or Spotlight). The cup asks for a spot next to the clock, so it's the last item a full menu bar hides; if it's still hidden, ⌘-drag it further right, or turn other items off in System Settings → Menu Bar. The hotkey works either way.
- **The hotkey does nothing.** Another app may have claimed the same combination (Cold Brew tells you at launch when that happens). Pick a different one: `agents hotkey ctrl+opt+cmd+l`.
- **Switching shows no banner.** Notifications are off for Cold Brew: System Settings → Notifications → Cold Brew. `agents` shows the current state either way.
- **"Setup incomplete".** Run `agents install`.
- **Want to see what happened while the lid was closed?** Run `cat ~/.cache/lid-agents/lid-agents.log`.

## Building from source

```bash
git clone https://github.com/liam-machine/cold-brew && cd cold-brew
scripts/build.sh      # universal "build/Cold Brew.app", dist/ColdBrew.dmg, dist/lid-agents.tar.gz
./install.sh          # installs the local build
tests/run.sh          # tests for bin/agents (detection, agents mark, hooks); see tests/README.md
```

**Releasing.** Every merge to `main` that changes the app is built by GitHub Actions, signed, notarized and published as the next patch release (latest tag + 1), with the DMG, the tarball and `install.sh`. Installed copies offer it within a day. Pushes that only change docs don't release. CI won't publish an unsigned release: the signing secrets come from `scripts/setup-signing-secrets.sh`, a one-time step for maintainers.

- Curated release notes: add a `## x.y.z` section to `CHANGELOG.md` before merging. Without one, GitHub writes the notes from the commits.
- Minor or major bump: set `VERSION` to e.g. `1.1.0`.
- Re-run a release by hand: Actions → *Build and release* → *Run workflow*.

## Credits

The `pmset disablesleep` approach and the narrow sudoers rule follow [Sleepless](https://github.com/Aboudjem/Sleepless). Cold Brew adds the agent awareness, so the Mac only stays awake while there's work being done.
