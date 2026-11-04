#!/bin/bash
# Tests for bin/agents that don't depend on what's running on this Mac.
#
#   tests/run.sh
#
# Detection reads canned `ps` and `pmset` output from tests/cases/<case>/ (see tests/README.md)
# through AGENTS_TEST_FIXTURE. Everything runs with an empty environment and a temporary HOME,
# so nothing touches your real settings, markers or the pmset flag.
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"
AGENTS="$ROOT/bin/agents"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

ok() { pass=$((pass + 1)); echo "ok   $1"; }
not_ok() { fail=$((fail + 1)); echo "FAIL $1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/     /'; }

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1" "$(diff <(printf '%s\n' "$2") <(printf '%s\n' "$3"))"; fi
}

# run_agents <home> <fixture dir or ""> <args...>: bin/agents with nothing from this shell
# (TEST_PATH and TEST_ENV add to the empty environment)
run_agents() {
  local home="$1" fixture="$2"; shift 2
  # shellcheck disable=SC2086  # TEST_ENV is a list of VAR=value words
  env -i HOME="$home" PATH="${TEST_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}" ${TEST_ENV:-} \
    ${fixture:+AGENTS_TEST_FIXTURE="$fixture"} /bin/bash "$AGENTS" "$@"
}

# `agents busy`, reduced to "pid name why why" (fixture pids have no folder), sorted
busy_lines() {
  run_agents "$1" "$2" busy | awk '$1 ~ /^[0-9]+$/ { print $1, $2, $3, $4 } $1 == "No" { print "No busy agents" }' | sort
}

# A needs-input marker as `agents mark waiting` writes it: "<epoch> <kind>", then the agent's
# descendants at that moment
put_marker() {   # put_marker <home> <pid> [descendants]
  mkdir -p "$1/.cache/lid-agents/waiting"
  printf '%s permission\n%s\n' "$(date +%s)" "${3:-}" > "$1/.cache/lid-agents/waiting/$2"
}

# --- Detection: one case per directory ---------------------------------------------------
for dir in "$ROOT"/tests/cases/*/; do
  dir="${dir%/}"
  name="${dir##*/}"
  home="$TMP/$name"
  mkdir -p "$home"
  if [ -f "$dir/waiting" ]; then
    while read -r pid snap; do put_marker "$home" "$pid" "${snap:-}"; done < "$dir/waiting"
  fi
  check "busy: $name" "$(sort "$dir/expected")" "$(busy_lines "$home" "$dir")"
  # markers whose agent isn't running are removed
  if [ -f "$dir/waiting" ]; then
    while read -r pid _; do
      if ! grep -q "^$pid " "$dir/procs" && [ -e "$home/.cache/lid-agents/waiting/$pid" ]; then
        not_ok "busy: $name removes the marker of exited pid $pid"
      fi
    done < "$dir/waiting"
  fi
done

# --- agents mark: finds the agent at or above the pid ------------------------------------
home="$TMP/mark"; mkdir -p "$home"; W="$home/.cache/lid-agents/waiting"
fx="$ROOT/tests/cases/claude-caffeinate"
run_agents "$home" "$fx" mark waiting --pid 900002 --kind question      # caffeinate under claude
check "mark: a child's pid marks its agent" "question" "$(awk 'NR == 1 { print $2 }' "$W/900001" 2>/dev/null)"
check "mark: the agent then needs input" "900001 claude needs input" "$(busy_lines "$home" "$fx")"
run_agents "$home" "$fx" mark working --pid 900001
check "mark: working clears it and leaves a stamp" "-.clear-900001" "$(ls -A "$W" | tr '\n' ' ' | sed 's/ $//; s/^/-/')"
rm -f "$W"/.clear-*
run_agents "$home" "$fx" mark waiting --pid 900010                      # the Claude desktop app
check "mark: a non-agent marks nothing" "" "$(ls "$W" 2>/dev/null)"
run_agents "$home" "$fx" mark waiting --pid 900001 --kind bogus
check "mark: an unknown kind is stored as input" "input" "$(awk 'NR == 1 { print $2 }' "$W/900001" 2>/dev/null)"
rm -f "$W/900001"
# a clear that lands after `mark waiting` started (the stamp is newer) wins the race
touch -t "$(date -v+1M +%Y%m%d%H%M.%S)" "$W/.clear-900001"
run_agents "$home" "$fx" mark waiting --pid 900001
check "mark: a later clear wins the race" "no" "$([ -f "$W/900001" ] && echo yes || echo no)"
rm -f "$W"/.clear-*
run_agents "$home" "$ROOT/tests/cases/interpreters" mark waiting --pid 900303
check "mark: an interpreter agent (node titled claude)" "yes" "$([ -f "$W/900302" ] && echo yes)"
run_agents "$home" "$ROOT/tests/cases/answered-long-tool" mark waiting --pid 900601
check "mark: records the agent's children at that moment" "900602,900603" "$(sed -n 2p "$W/900601")"
run_agents "$home" "$fx" mark sideways --pid 900001; status=$?
check "mark: always exits 0" "0" "$status"

# --- agents integrate: hooks merge into Claude Code's and Codex's JSON --------------------
home="$TMP/hooks"; mkdir -p "$home/.claude" "$home/.codex" "$TMP/bin"
cat > "$TMP/bin/codex" <<'EOF'
#!/bin/sh
# a stand-in for `codex features enable|list`
[ "$1" = features ] || exit 1
[ "$2" = list ] && echo "prevent_idle_sleep  experimental  true"
exit 0
EOF
chmod +x "$TMP/bin/codex"
export TEST_PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# The fixtures are written the way edit_hooks_json writes (2-space JSON), so a remove that
# restores them must give back the same bytes.
canonical() { osascript -l JavaScript -e 'function run(a) { return JSON.stringify(JSON.parse(a[0]), null, 2) }' "$1"; }
canonical '{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"guard.sh"}]}]}}' > "$home/.claude/settings.json"
canonical '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"superset-notify"}]}]}}' > "$home/.codex/hooks.json"
chmod 600 "$home/.claude/settings.json"
cp "$home/.claude/settings.json" "$TMP/claude.orig"; cp "$home/.codex/hooks.json" "$TMP/codex.orig"

run_agents "$home" "" integrate >/dev/null 2>&1
first="$(stat -f %m "$home/.claude/settings.json")"
sleep 1
run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: 9 Claude hooks, once each after two runs" "9" "$(grep -c 'lid-agents-hook' "$home/.claude/settings.json")"
check "integrate: 7 Codex hooks, once each after two runs" "7" "$(grep -c 'lid-agents-hook' "$home/.codex/hooks.json")"
check "integrate: an unchanged file isn't rewritten" "$first" "$(stat -f %m "$home/.claude/settings.json")"
check "integrate: the file's permissions are kept" "600" "$(stat -f %Lp "$home/.claude/settings.json")"
check "integrate: Claude's other hooks and settings kept" "guard.sh opus say done" \
  "$(grep -o '"say done"\|"guard.sh"\|"opus"' "$home/.claude/settings.json" | tr -d '"' | sort | tr '\n' ' ' | sed 's/ $//')"
check "integrate: Codex's other hooks kept" "1" "$(grep -c 'superset-notify' "$home/.codex/hooks.json")"
check "integrate: Claude permission prompts mark it" "1" \
  "$(plutil -extract hooks.Notification json -o - "$home/.claude/settings.json" | grep -c 'permission_prompt')"
check "integrate: Codex PermissionRequest marks it" "yes" \
  "$(plutil -extract hooks.PermissionRequest json -o - "$home/.codex/hooks.json" >/dev/null 2>&1 && echo yes)"
check "integrate: backups of the originals" "same same" \
  "$(cmp -s "$TMP/claude.orig" "$home/.claude/settings.json.lid-agents.bak" && echo same) $(cmp -s "$TMP/codex.orig" "$home/.codex/hooks.json.lid-agents.bak" && echo same)"

# a custom CLAUDE_CONFIG_DIR is recorded, so refresh and uninstall find it without the variable
mkdir -p "$home/custom-claude"
TEST_ENV="CLAUDE_CONFIG_DIR=$home/custom-claude" run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: a custom CLAUDE_CONFIG_DIR is recorded" "yes" \
  "$(grep -qxF "$home/custom-claude/settings.json" "$home/.cache/lid-agents/hook-files" && echo yes)"

# removal (what uninstall does) gives back the original files byte for byte
(
  export HOME="$home" AGENTS_SOURCED=1
  # shellcheck source=../bin/agents
  source "$AGENTS"
  edit_hooks_json "$home/.claude/settings.json" remove && edit_hooks_json "$home/.codex/hooks.json" remove
)
# Remote Control is a Claude Code setting you may want either way, so uninstall leaves it
without_remote() {
  osascript -l JavaScript -e 'function run(a) { const o = JSON.parse(a[0]); delete o.remoteControlAtStartup
    delete o.inputNeededNotifEnabled; return JSON.stringify(o, null, 2) }' "$(cat "$1")"
}
check "remove: Claude settings back to the original, apart from Remote Control" "$(cat "$TMP/claude.orig")" \
  "$(without_remote "$home/.claude/settings.json")"
check "remove: Codex hooks back to the original" "same" "$(cmp -s "$TMP/codex.orig" "$home/.codex/hooks.json" && echo same)"

# files that aren't a JSON object are left alone
printf '{ not json' > "$home/.claude/settings.json"
run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: invalid JSON is left untouched" "{ not json" "$(cat "$home/.claude/settings.json")"
printf '[]\n' > "$home/.claude/settings.json"
run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: a JSON array is left untouched" "[]" "$(cat "$home/.claude/settings.json")"

# --- Remote Control: Claude Code's own settings, and which busy sessions are connected ------
home="$TMP/remote"; mkdir -p "$home/.claude"
S="$home/.claude/settings.json"
setting() { plutil -extract "$1" raw -o - "$S" 2>/dev/null || echo unset; }
remote_line() { run_agents "$home" "$1" state --menu | awk '$1 == "remote"'; }
agent_line() { run_agents "$home" "$1" state --menu | awk '$1 == "agent" { print $2, $3, $4, $5 }'; }
fx="$ROOT/tests/cases/claude-caffeinate"
canonical '{"model":"opus"}' > "$S"
check "remote: unset until chosen" "remote unset" "$(remote_line "")"
run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: Remote Control and its push on when never chosen" "true true" \
  "$(setting remoteControlAtStartup) $(setting inputNeededNotifEnabled)"
run_agents "$home" "" remote off >/dev/null
run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: keeps Remote Control off once you've chosen it" "false" "$(setting remoteControlAtStartup)"
check "remote: off" "remote off" "$(remote_line "")"
canonical '{"inputNeededNotifEnabled":false}' > "$S"
run_agents "$home" "" remote on >/dev/null
check "remote on: keeps a push choice you made" "true false" \
  "$(setting remoteControlAtStartup) $(setting inputNeededNotifEnabled)"
check "remote: on" "remote on" "$(remote_line "")"

# which settings file: a stale record (a throwaway CLAUDE_CONFIG_DIR, a deleted one) mustn't win,
# or Remote Control goes to a file Claude Code never reads
records="$home/.cache/lid-agents/hook-files"
scratch="$TMP/scratchpad/cc"; mkdir -p "$scratch"
canonical '{}' > "$scratch/settings.json"
printf '%s\n%s\n' "$scratch/settings.json" "$S" > "$records"
TEST_ENV="TMPDIR=$TMP/" run_agents "$home" "" remote off >/dev/null
check "remote: skips a recorded settings file in a temporary folder" "false unset" \
  "$(setting remoteControlAtStartup) $(plutil -extract remoteControlAtStartup raw -o - "$scratch/settings.json" 2>/dev/null || echo unset)"
printf '%s\n%s\n' "$home/gone/settings.json" "$S" > "$records"
run_agents "$home" "" remote on >/dev/null
check "remote: skips a recorded settings file that's gone" "true" "$(setting remoteControlAtStartup)"
check "remote: a missing recorded file isn't created" "no" "$([ -e "$home/gone" ] && echo yes || echo no)"
mkdir -p "$home/custom-claude"; canonical '{"remoteControlAtStartup":false}' > "$home/custom-claude/settings.json"
printf '%s\n%s\n' "$home/custom-claude/settings.json" "$S" > "$records"
check "remote: a recorded custom CLAUDE_CONFIG_DIR is still used" "remote off" "$(remote_line "")"
check "temp folders: Claude Code's scratchpads and \$TMPDIR" "yes yes yes no" "$(
  export HOME="$home" AGENTS_SOURCED=1 TMPDIR=/var/folders/ab/T/
  # shellcheck source=../bin/agents
  source "$AGENTS"
  for p in /private/tmp/claude-501/x/scratchpad/cc/settings.json /tmp/cc/settings.json \
    /private/var/folders/ab/T/cc/settings.json "$home/.claude/settings.json"; do
    in_temp_dir "$p" && printf 'yes ' || printf 'no '
  done | sed 's/ $//'
)"
printf '%s\n' "$S" > "$records"
TEST_ENV="CLAUDE_CONFIG_DIR=$scratch TMPDIR=$TMP/" run_agents "$home" "" integrate >/dev/null 2>&1
check "integrate: a CLAUDE_CONFIG_DIR in a temporary folder isn't recorded" "$S" "$(cat "$records")"

# a busy Claude session's sessions/<pid>.json says whether it's connected
mkdir -p "$home/.claude/sessions"
canonical '{"pid":900001,"kind":"interactive"}' > "$home/.claude/sessions/900001.json"
check "state --menu: a busy Claude session not on Remote Control" "900001 claude working no" "$(agent_line "$fx")"
canonical '{"pid":900001,"kind":"interactive","bridgeSessionId":"session_x"}' > "$home/.claude/sessions/900001.json"
check "state --menu: a busy Claude session on Remote Control" "900001 claude working yes" "$(agent_line "$fx")"
rm "$home/.claude/sessions/900001.json"
check "state --menu: a session without a file isn't flagged" "900001 claude working -" "$(agent_line "$fx")"

# --- Auto keep: switches on when an agent starts, held after a pause until agents finish ------
# AGENTS_AUTO stands in for the AutoKeep default; nothing here runs pmset or writes defaults.
home="$TMP/auto"; mkdir -p "$home/.cache/lid-agents"
HOLD="$home/.cache/lid-agents/auto-hold"
auto_of() {   # auto_of <on|off> <keep|pause> <fixture case or "">: auto_state for that snapshot
  (
    export HOME="$home" AGENTS_SOURCED=1 AGENTS_AUTO="$1"
    [ -z "$3" ] || export AGENTS_TEST_FIXTURE="$ROOT/tests/cases/$3"
    # shellcheck source=../bin/agents
    source "$AGENTS"
    battery_low() { return 1; }          # this Mac's battery mustn't decide the test
    auto_state "$2" "$([ -z "$3" ] || agent_report)"
  )
}
check "auto: an agent working with keep off is due" "due" "$(auto_of 1 pause claude-caffeinate)"
check "auto: nothing to do while keep is already on" "on" "$(auto_of 1 keep claude-caffeinate)"
check "auto: no agent working, nothing due" "on" "$(auto_of 1 pause no-agents)"
put_marker "$home" 900001                # the Claude session stops on a prompt
check "auto: an agent that needs you doesn't switch it on" "on" "$(auto_of 1 pause claude-caffeinate)"
check "auto: off means keep only when asked" "off" "$(auto_of 0 pause claude-caffeinate)"
: > "$HOLD"
check "auto: paused with agents at work, held" "held" "$(auto_of 1 pause claude-caffeinate)"
check "auto: held while an agent still needs you" "held" "$(auto_of 1 pause claude-caffeinate)"
rm -f "$home/.cache/lid-agents/waiting/900001"
check "auto: the hold stays while they work" "yes" "$([ -f "$HOLD" ] && echo yes)"
check "auto: once they've finished, armed again" "on" "$(auto_of 1 pause no-agents)"
check "auto: …and the hold is gone" "no" "$([ -f "$HOLD" ] && echo yes || echo no)"
check "auto: the next agent to start is due" "due" "$(auto_of 1 pause claude-caffeinate)"
: > "$HOLD"
TEST_ENV="AGENTS_AUTO=1" run_agents "$home" "$ROOT/tests/cases/claude-caffeinate" keep --auto >/dev/null 2>&1; status=$?
check "keep --auto: does nothing while held" "3" "$status"
rm -f "$HOLD"
TEST_ENV="AGENTS_AUTO=0" run_agents "$home" "$ROOT/tests/cases/claude-caffeinate" keep --auto >/dev/null 2>&1; status=$?
check "keep --auto: does nothing when auto is off" "3" "$status"
: > "$HOLD"
check "state: the auto field" "held" \
  "$(TEST_ENV="AGENTS_AUTO=1" run_agents "$home" "$ROOT/tests/cases/claude-caffeinate" state | awk '{ print $10 }')"
rm -f "$HOLD"

# --- Other apps: which are slowed with the lid closed (tests/apps/) --------------------------
# Plans only: nothing here runs taskpolicy, so no real app is touched.
plan_of() {   # plan_of <keep list>: apps_plan for the tests/apps snapshot, sorted
  (
    export HOME="$TMP/apps" AGENTS_SOURCED=1 AGENTS_TEST_FIXTURE="$ROOT/tests/apps" AGENTS_KEEP_APPS="$1"
    # shellcheck source=../bin/agents
    source "$AGENTS"
    apps_plan | sort
  )
}
mkdir -p "$TMP/apps"
check "apps: agent hosts, what they started, the list and busy apps kept; the rest slowed" \
  "$(sort "$ROOT/tests/apps/expected")" "$(plan_of "Simulator,Google Chrome")"
check "apps: with an empty list, Chrome is slowed too" "slow 910010 slow 910011 slow 910020 slow 910021" \
  "$(plan_of "" | awk -F'\t' '$1 == "slow" { printf "%s%s %s", (n++ ? " " : ""), $1, $2 }')"
names_of() {
  export HOME="$TMP/apps" AGENTS_SOURCED=1
  # shellcheck source=../bin/agents
  source "$AGENTS"
  apps_names
}
check "apps: names for the log and menu" "Slack, Google Chrome" \
  "$(printf '1\t/Applications/Slack.app/Contents/MacOS/Slack\n2\t/Applications/Slack.app/x\n3\t/Applications/Google Chrome.app/y\n' | (names_of))"

# --- Lid closed: the display is put to sleep unless a monitor is plugged in -----------------
display_case() {   # display_case <system_profiler text>: external or none
  mkdir -p "$TMP/displays"; printf '%s\n' "$1" > "$TMP/displays/displays"
  (
    export HOME="$TMP/apps" AGENTS_SOURCED=1 AGENTS_TEST_FIXTURE="$TMP/displays"
    # shellcheck source=../bin/agents
    source "$AGENTS"
    external_display && echo external || echo none
  )
}
check "display: the built-in screen alone" "none" "$(display_case '        Color LCD:
          Display Type: Built-in Liquid Retina XDR Display
          Resolution: 3024 x 1964 Retina')"
check "display: a monitor as well (clamshell mode)" "external" "$(display_case '        Color LCD:
          Display Type: Built-In Retina LCD
          Resolution: 2560 x 1600 Retina
        DELL U2720Q:
          Resolution: 3840 x 2160 (2160p/4K UHD 1 - Ultra High Definition)')"
check "display: lid closed, only a monitor" "external" "$(display_case '        LG HDR 4K:
          Resolution: 3840 x 2160')"

# --- agents focus: the steps for each kind of app (tests/focus/<case>/) ---------------------
for dir in "$ROOT"/tests/focus/*/; do
  dir="${dir%/}"
  check "focus: ${dir##*/}" "$(cat "$dir/expected")" \
    "$(run_agents "$TMP" "$dir" focus --plan "$(cat "$dir/pid")" | tr '\t' ' ')"
done
run_agents "$TMP" "$ROOT/tests/focus/nothing-known" focus 900933 >/dev/null 2>&1; status=$?
check "focus: says so when it can't tell the app" "1" "$status"
run_agents "$TMP" "$ROOT/tests/focus/cmux" focus 999999 >/dev/null 2>&1; status=$?
check "focus: a pid that isn't running" "1" "$status"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
