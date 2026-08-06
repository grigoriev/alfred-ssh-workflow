#!/bin/bash

# Parse ~/.ssh/config into a JSON array of hosts.
# Each element is { alias, hostname, user, port }.
# Wildcard patterns (Host *, ?, !) are skipped since they are not connectable.

# Print a config file with its Include directives expanded inline.
# Relative includes resolve against the including file's directory.
# $1 = config file path
expand_ssh_config() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local dir
  dir="$(dirname "$file")"

  local line globs glob path match
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*[Ii]nclude[[:space:]]+(.+)$ ]]; then
      globs="${BASH_REMATCH[1]}"
      for glob in $globs; do
        case "$glob" in
          /*)    path="$glob" ;;
          \~/*)  path="$HOME/${glob#\~/}" ;;
          *)     path="$dir/$glob" ;;
        esac
        for match in $path; do
          [[ -f "$match" ]] && expand_ssh_config "$match"
        done
      done
    else
      printf '%s\n' "$line"
    fi
  done < "$file"
  return 0
}

# Turn ssh config text on stdin into a JSON array of hosts.
# The awk and jq programs live in sibling files so the shell logic stays small.
parse_hosts() {
  awk -f src/parse-hosts.awk | jq -Rn -f src/rows-to-hosts.jq
  return 0
}

# Read the ssh config (default ~/.ssh/config, override with SSH_CONFIG) and
# print the hosts as a JSON array.
ssh_hosts() {
  local cfg="${1:-${SSH_CONFIG:-$HOME/.ssh/config}}"
  if [[ ! -f "$cfg" ]]; then
    echo "[]"
    return 0
  fi
  expand_ssh_config "$cfg" | parse_hosts
  return 0
}
