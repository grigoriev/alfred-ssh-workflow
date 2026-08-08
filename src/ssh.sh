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
# Open the user's SSH config in a text editor, creating it if missing.
edit_ssh_config() {
  local file="${SSH_CONFIG:-$HOME/.ssh/config}"
  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : > "$file"
  open -e "$file"
  return 0
}

if [[ "$mode" == "run" ]]; then
  case "$query" in
    http://*|https://*) autoupdate_clear; . src/update.sh "$query" ;;  # install an update
    autoupdate*) set_autoupdate "${query#autoupdate }" ;;              # toggle autoupdate
    edit-config) edit_ssh_config ;;                                    # open ~/.ssh/config
    *) open_ssh "$query" ;;                                            # open an SSH session
  esac
  exit
fi

# The ">" menu, filtered by a substring: settings and the shared update items.
globals_menu() {
  local filter="$1" lc
  lc="$(printf '%s' "$filter" | tr '[:upper:]' '[:lower:]')"
  if [[ "edit ssh config" == *"$lc"* ]]; then
    add_result "" "edit-config" "Edit SSH config" "Open ~/.ssh/config in a text editor" "$ICON_HOST" "yes"
  fi
  autoupdate_menu "$filter" "$ICON_UPDATE"
  get_json_results
  return 0
}

# List mode
# ">" opens the settings and updates menu; "> update" checks for a new version.
if [[ "$query" == ">"* ]]; then
  sub="${query#>}"
  sub="${sub# }"
  if [[ "$sub" == update* ]]; then
    . src/update.sh ""
  else
    globals_menu "$sub"
  fi
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
  # No hosts configured: show a hint. Settings and updates live under ">".
  add_result "" "" "No SSH hosts found" "Add Host entries to ~/.ssh/config, or type > for settings" "$ICON_HOST" "no"
  get_json_results
  exit
fi

# Print the filtered hosts, plus any update banner queued on the home view.
printf '{"items":%s}\n' "$(jq -c --argjson extra "$(get_json_results)" '. + $extra.items' <<< "$items")"
