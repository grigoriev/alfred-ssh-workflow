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

if [ "$(jq 'length' <<< "$HOSTS")" == "0" ]; then
  addResult "" "" "No SSH hosts found" "Add Host entries to ~/.ssh/config" "$ICON_SSH" "no"
  getJSONResults
  exit
fi

# Render each host, filtered by the query (case-insensitive substring over the
# alias, hostname and user).
shopt -s nocasematch
while IFS= read -r HOST; do
  [ -z "$HOST" ] && continue
  ALIAS=$(jq -r '.alias' <<< "$HOST")
  HOSTNAME=$(jq -r '.hostname // ""' <<< "$HOST")
  USER=$(jq -r '.user // ""' <<< "$HOST")
  PORT=$(jq -r '.port // ""' <<< "$HOST")

  if [ -n "$QUERY" ] && [[ "$ALIAS $HOSTNAME $USER" != *"$QUERY"* ]]; then
    continue
  fi

  # subtitle: user@hostname:port, falling back to the alias
  TARGET="$HOSTNAME"
  [ -z "$TARGET" ] && TARGET="$ALIAS"
  [ -n "$USER" ] && TARGET="$USER@$TARGET"
  [ -n "$PORT" ] && TARGET="$TARGET:$PORT"

  addResult "$ALIAS" "$ALIAS" "$ALIAS" "ssh $TARGET" "$ICON_SSH"
done <<< "$(jq -c '.[]' <<< "$HOSTS")"

getJSONResults
