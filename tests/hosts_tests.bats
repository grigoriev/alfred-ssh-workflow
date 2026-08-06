#!/usr/bin/env bats

. src/hosts.sh

setup() {
  CFG="$BATS_TEST_TMPDIR/config"
  cat > "$CFG" <<'EOF'
# sample ssh config
Host web
  HostName web.example.com
  User deploy
  Port 2222

Host db1 db2
  HostName 10.0.0.5

Host *.internal
  User admin

Host bastion
  Hostname bastion.example.com
EOF
}

@test "ssh_hosts: parses alias, hostname, user and port" {
  run ssh_hosts "$CFG"
  echo "$output" | jq -e '.[] | select(.alias=="web")
    | .hostname=="web.example.com" and .user=="deploy" and .port=="2222"' >/dev/null
}

@test "ssh_hosts: expands multiple aliases on one Host line" {
  run ssh_hosts "$CFG"
  echo "$output" | jq -e 'map(.alias) | index("db1") != null and index("db2") != null' >/dev/null
  echo "$output" | jq -e '.[] | select(.alias=="db1") | .hostname=="10.0.0.5"' >/dev/null
}

@test "ssh_hosts: skips wildcard and negated patterns" {
  run ssh_hosts "$CFG"
  echo "$output" | jq -e 'all(.[]; .alias | test("[*?!]") | not)' >/dev/null
}

@test "ssh_hosts: keys are case-insensitive (Hostname)" {
  run ssh_hosts "$CFG"
  echo "$output" | jq -e '.[] | select(.alias=="bastion") | .hostname=="bastion.example.com"' >/dev/null
}

@test "ssh_hosts: missing config yields an empty array" {
  run ssh_hosts "$BATS_TEST_TMPDIR/nope"
  [ "$output" == "[]" ]
}

@test "ssh_hosts: expands Include directives" {
  mkdir -p "$BATS_TEST_TMPDIR/conf.d"
  cat > "$BATS_TEST_TMPDIR/conf.d/extra" <<'EOF'
Host included
  HostName inc.example.com
EOF
  cat > "$BATS_TEST_TMPDIR/main" <<EOF
Include $BATS_TEST_TMPDIR/conf.d/*
Host local
  HostName localhost
EOF
  run ssh_hosts "$BATS_TEST_TMPDIR/main"
  echo "$output" | jq -e 'map(.alias) | index("included") != null and index("local") != null' >/dev/null
}
