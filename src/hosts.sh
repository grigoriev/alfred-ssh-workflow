#!/bin/bash

# Parse ~/.ssh/config into a JSON array of hosts.
# Each element is { alias, hostname, user, port }.
# Wildcard patterns (Host *, ?, !) are skipped since they are not connectable.

# Print a config file with its Include directives expanded inline.
# Relative includes resolve against the including file's directory.
# $1 = config file path
expandSshConfig() {
  local file="$1"
  [ -f "$file" ] || return 0
  local dir
  dir="$(dirname "$file")"

  local line globs g path f
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^[[:space:]]*[Ii]nclude[[:space:]]+(.+)$ ]]; then
      globs="${BASH_REMATCH[1]}"
      for g in $globs; do
        case "$g" in
          /*)    path="$g" ;;
          \~/*)  path="$HOME/${g#\~/}" ;;
          *)     path="$dir/$g" ;;
        esac
        for f in $path; do
          [ -f "$f" ] && expandSshConfig "$f"
        done
      done
    else
      printf '%s\n' "$line"
    fi
  done < "$file"
}

# Turn ssh config text on stdin into a JSON array of hosts.
parseHosts() {
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
}

# Read the ssh config (default ~/.ssh/config, override with SSH_CONFIG) and
# print the hosts as a JSON array.
sshHosts() {
  local cfg="${1:-${SSH_CONFIG:-$HOME/.ssh/config}}"
  if [ ! -f "$cfg" ]; then
    echo "[]"
    return
  fi
  expandSshConfig "$cfg" | parseHosts
}
