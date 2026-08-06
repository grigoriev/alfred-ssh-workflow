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
parse_hosts() {
  awk '
    function flush() {
      if (n > 0) {
        for (i = 1; i <= n; i++) {
          printf "%s\t%s\t%s\t%s\n", aliases[i], hostname, user, port
        }
      }
      n = 0; hostname = ""; user = ""; port = ""
    }
    { key = tolower($1) }
    key == "host" {
      flush()
      for (i = 2; i <= NF; i++) {
        if ($i ~ /[*?!]/) continue   # skip wildcard/negated patterns
        aliases[++n] = $i
      }
      next
    }
    n == 0 { next }
    key == "hostname" { hostname = $2; next }
    key == "user"     { user = $2; next }
    key == "port"     { port = $2; next }
    END { flush() }
  ' | jq -Rn '[inputs | split("\t")
    | {alias: .[0], hostname: .[1], user: .[2], port: .[3]}]'
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
