#!/bin/bash

. src/workflow_handler.sh
. src/hosts.sh
. src/media.sh
. src/autoupdate.sh

# Single entry point behind the "ssh" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/ssh.sh list "{query}"
#   run mode  (Run Script):    . src/ssh.sh run  "{query}"

mode="$1"
query="$2"

# Open an SSH session to the given host in iTerm2.
open_ssh() {
  local host="$1"
  osascript - "$host" <<'APPLESCRIPT'
on run argv
  set h to item 1 of argv
  tell application "iTerm"
    create window with default profile command ("ssh " & h)
    activate
  end tell
end run
APPLESCRIPT
  return 0
}

# Run mode: act on the selected item
if [[ "$mode" == "run" ]]; then
  case "$query" in
    http://*|https://*) autoupdate_clear; . src/update.sh "$query" ;;  # install an update
    autoupdate*) set_autoupdate "${query#autoupdate }" ;;              # toggle autoupdate
    *) open_ssh "$query" ;;                                            # open an SSH session
  esac
  exit
fi

# Queue an always-last entry that checks for and installs workflow updates.
# It is valid=no with an "update" autocomplete, so selecting it fills the query
# and re-runs the filter into the update check below.
add_update_item() {
  add_result "" "" "Check for updates" \
    "Check for and install a new version of this workflow" "$ICON_UPDATE" "no" "update"
  return 0
}

# Queue an autoupdate on/off toggle (home view only) reflecting the state.
add_autoupdate_toggle() {
  [[ -z "$query" ]] || return 0
  if autoupdate_enabled; then
    add_result "" "autoupdate off" "Autoupdate: on"  "Turn off automatic update checks" "$ICON_UPDATE" "yes"
  else
    add_result "" "autoupdate on"  "Autoupdate: off" "Turn on automatic update checks"  "$ICON_UPDATE" "yes"
  fi
  return 0
}

# List mode
# A magic "update" query checks for a new workflow version.
if [[ "${query%% *}" == "update" ]]; then
  . src/update.sh ""
  exit
fi

hosts=$(ssh_hosts)

# Filter and format every host in a single jq pass. Spawning jq once, rather
# than several times per host, keeps the Script Filter instant even with
# hundreds of hosts. The subtitle is "ssh user@hostname:port", each part
# optional, falling back to the alias when there is no hostname. The jq
# program lives in src/list-hosts.jq so the shell logic stays small.
items=$(jq -c -f src/list-hosts.jq --arg q "$query" --arg icon "$ICON_HOST" <<< "$hosts")

# On the home view, check for updates (throttled) and offer any pending one.
if [[ -z "$query" ]]; then
  autoupdate_refresh
  autoupdate_banner
fi

if [[ "$hosts" == "[]" ]]; then
  # No hosts configured: show a hint, then the update controls.
  add_result "" "" "No SSH hosts found" "Add Host entries to ~/.ssh/config" "$ICON_HOST" "no"
  add_autoupdate_toggle
  add_update_item
  get_json_results
  exit
fi

# Print the filtered hosts, then the update controls, keeping the check last.
add_autoupdate_toggle
add_update_item
printf '{"items":%s}\n' "$(jq -c --argjson extra "$(get_json_results)" '. + $extra.items' <<< "$items")"
