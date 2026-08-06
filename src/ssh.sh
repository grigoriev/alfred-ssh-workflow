#!/bin/bash

. src/workflowHandler.sh
. src/hosts.sh
. src/media.sh

# Single entry point behind the "ssh" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/ssh.sh list "{query}"
#   run mode  (Run Script):    . src/ssh.sh run  "{query}"

MODE="$1"
QUERY="$2"

# Open an SSH session to the given host in iTerm2.
openSSH() {
  osascript - "$1" <<'APPLESCRIPT'
on run argv
  set h to item 1 of argv
  tell application "iTerm"
    create window with default profile command ("ssh " & h)
    activate
  end tell
end run
APPLESCRIPT
}

# Run mode: act on the selected item
if [ "$MODE" == "run" ]; then
  case "$QUERY" in
    http://*|https://*) . src/update.sh "$QUERY" ;;   # install a downloaded update
    *) openSSH "$QUERY" ;;                             # open an SSH session
  esac
  exit
fi

# List mode
# A magic "update" query checks for a new workflow version.
if [ "${QUERY%% *}" == "update" ]; then
  . src/update.sh ""
  exit
fi

HOSTS=$(sshHosts)

# Filter and format every host in a single jq pass. Spawning jq once, rather
# than several times per host, keeps the Script Filter instant even with
# hundreds of hosts. The subtitle is "ssh user@hostname:port", each part
# optional, falling back to the alias when there is no hostname.
ITEMS=$(jq -c --arg q "$QUERY" --arg icon "$ICON_SSH" '
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
        icon: { path: $icon }, subtitle: target } ]' <<< "$HOSTS")

if [ "$ITEMS" == "[]" ] && [ "$HOSTS" == "[]" ]; then
  addResult "" "" "No SSH hosts found" "Add Host entries to ~/.ssh/config" "$ICON_SSH" "no"
  getJSONResults
  exit
fi

printf '{"items":%s}\n' "$ITEMS"
