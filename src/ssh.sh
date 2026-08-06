#!/bin/bash

. src/workflow_handler.sh
. src/hosts.sh
. src/media.sh

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
    http://*|https://*) . src/update.sh "$query" ;;   # install a downloaded update
    *) open_ssh "$query" ;;                            # open an SSH session
  esac
  exit
fi

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
# optional, falling back to the alias when there is no hostname.
items=$(jq -c --arg q "$query" --arg icon "$ICON_SSH" '
  def target:
    "ssh "
    + (if .user != "" then .user + "@" else "" end)
    + (if .hostname != "" then .hostname else .alias end)
    + (if .port != "" then ":" + .port else "" end);
  def hit($q): $q == "" or
    (([.alias, .hostname, .user] | join(" ") | ascii_downcase)
      | contains($q | ascii_downcase));
  [ .[]
    | select(hit($q))
    | { uid: .alias, title: .alias, arg: .alias, valid: true,
        icon: { path: $icon }, subtitle: target } ]' <<< "$hosts")

if [[ "$items" == "[]" ]] && [[ "$hosts" == "[]" ]]; then
  add_result "" "" "No SSH hosts found" "Add Host entries to ~/.ssh/config" "$ICON_SSH" "no"
  get_json_results
  exit
fi

printf '{"items":%s}\n' "$items"
