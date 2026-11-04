#!/bin/bash
# Cold Brew installer (it was called Lid Agents before 1.5.0).
#
#   curl -fsSL https://github.com/liam-machine/lid-agents/releases/latest/download/install.sh | bash
#
# Installs "Cold Brew.app" (menu bar app; replaces an existing copy where it is, a "Lid Agents.app"
# included, otherwise ~/Applications), links the `agents` command into ~/.local/bin, adds one sudoers rule allowing
# exactly `pmset -a disablesleep 0|1`, opens the app at login, and starts it. Nothing else on
# the system changes. Re-run to upgrade. Pin a version with LID_AGENTS_VERSION=1.0.0; the app's
# Update item passes LID_AGENTS_APP (its own path). From a checkout, `./install.sh` uses build/.
set -euo pipefail

REPO="liam-machine/lid-agents"
VERSION="${LID_AGENTS_VERSION:-latest}"
BUNDLE_ID="io.github.liam-machine.lid-agents"
NAME="Cold Brew.app"
EXE="ColdBrew"
OLD_NAMES=("Lid Agents.app" "LidAgents.app")   # its names before 1.5.0 and before 1.0.6
APP="${LID_AGENTS_APP:-}"                       # the app's Update item: its own path, maybe an old name
if [ -z "$APP" ]; then
  for candidate in "/Applications/$NAME" "$HOME/Applications/$NAME" \
                   "/Applications/${OLD_NAMES[0]}" "$HOME/Applications/${OLD_NAMES[0]}" "$HOME/Applications/${OLD_NAMES[1]}"; do
    if [ -d "$candidate" ]; then APP="$candidate"; break; fi
  done
fi
# Same folder, new name: an old copy is removed once the new one is in place
[ -n "$APP" ] && APP="$(dirname "$APP")/$NAME"
APP="${APP:-$HOME/Applications/$NAME}"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/agents"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mcold brew:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "Cold Brew is for macOS only."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || die "Cold Brew needs macOS 13 (Ventura) or later."
pmset -g batt | grep -q 'InternalBattery' || echo "Note: no internal battery found. Cold Brew is meant for MacBooks."
id -Gn | tr ' ' '\n' | grep -qx admin || die "Your account must be an administrator: the lid setting needs one pmset rule in /etc/sudoers.d."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. Get the app: a local build when run from a checkout, otherwise the GitHub release
self="${BASH_SOURCE[0]:-}"
if [ -n "$self" ] && [ -f "$self" ] && [ -d "$(dirname "$self")/build/$NAME" ]; then
  src="$(cd "$(dirname "$self")" && pwd)/build/$NAME"
  step "Using local build: $src"
else
  if [ "$VERSION" = "latest" ]; then
    url="https://github.com/$REPO/releases/latest/download/lid-agents.tar.gz"
  else
    url="https://github.com/$REPO/releases/download/v${VERSION#v}/lid-agents.tar.gz"
  fi
  step "Downloading $url"
  curl -fsSL "$url" -o "$tmp/lid-agents.tar.gz" || die "Download failed."
  tar -xzf "$tmp/lid-agents.tar.gz" -C "$tmp"
  src="$tmp/$NAME"
fi
[ -x "$src/Contents/MacOS/$EXE" ] || die "The download did not contain the Cold Brew app (versions before 1.5.0 need their own install.sh)."

# 2. Install the app (quit a running copy first so the upgrade takes)
step "Installing $APP"
# -a: when the app's own Update item started this installer, the app is our ancestor,
# and macOS pkill skips ancestors by default. `open` below would then just reactivate it.
for exe in "$EXE" LidAgents; do pkill -a -x "$exe" 2>/dev/null || true; done
for _ in $(seq 50); do pgrep -x "$EXE" >/dev/null || pgrep -x LidAgents >/dev/null || break; sleep 0.1; done
for exe in "$EXE" LidAgents; do pkill -9 -a -x "$exe" 2>/dev/null || true; done
mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
ditto "$src" "$APP"
for dir in /Applications "$HOME/Applications"; do
  for old in "${OLD_NAMES[@]}"; do
    if [ -d "$dir/$old" ]; then rm -rf "${dir:?}/${old:?}" 2>/dev/null && echo "    Removed $dir/$old (Cold Brew's old name)"; fi
  done
done
# Downloads through a browser are quarantined; curl's are not, but clear it either way
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

# 3. The `agents` command
mkdir -p "$BIN_DIR"
if [ -e "$LINK" ] && ! [ -L "$LINK" ]; then
  mv "$LINK" "$LINK.bak"
  echo "    Moved an existing $LINK to $LINK.bak"
fi
ln -sfn "$APP/Contents/Resources/agents" "$LINK"
step "Linked the \`agents\` command: $LINK"

# An upgrade refreshes the OpenCode plugin if `agents integrate` installed it earlier
# (the app does the same at launch, which covers upgrades from the DMG)
"$LINK" integrate --refresh

# 4. The one permission that needs your password
step "Allowing \`pmset -a disablesleep 0|1\` without a password (nothing else)"
"$LINK" install

# 5. Open at login
mkdir -p "$(dirname "$LAUNCH_AGENT")"
cat > "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$BUNDLE_ID</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>$APP</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
step "Cold Brew will open at login (turn off in its menu)"

# 6. Start it; first launch asks to send notifications
open "$APP"

hotkey="$(defaults read "$BUNDLE_ID" Hotkey 2>/dev/null || echo "ctrl+0")"
echo
bold "Cold Brew $("$LINK" version | awk '{print $NF}') is installed."
case "$(defaults read "$BUNDLE_ID" AutoKeep 2>/dev/null)" in
  0|false|off|no)
    echo "  • Click the cup in the menu bar, or press $hotkey, to keep agents running with the lid closed." ;;
  *)
    echo "  • Nothing to switch on: when an agent starts working, the cup in the menu bar fills and"
    echo "    closing the lid keeps it running. Press $hotkey or click the cup to let it sleep this time."
    echo "  • Rather switch it on yourself each time? Run: agents auto off" ;;
esac
echo "  • macOS will ask whether \"Cold Brew\" can send notifications: click Allow."
echo "  • In a terminal: agents keep · agents pause · agents (status) · agents uninstall"
if ! [ -f "$HOME/.cache/lid-agents/integrated" ] && { command -v codex || command -v opencode; } >/dev/null 2>&1; then
  echo "  • Use Codex or OpenCode? Run \`agents integrate\` so Cold Brew can tell when they're busy."
fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo
     echo "  $BIN_DIR is not on your PATH. To use the \`agents\` command, run:"
     echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && exec zsh" ;;
esac
