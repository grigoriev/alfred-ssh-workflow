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

@test "sshHosts: parses alias, hostname, user and port" {
  run sshHosts "$CFG"
  echo "$output" | jq -e '.[] | select(.alias=="web")
    | .hostname=="web.example.com" and .user=="deploy" and .port=="2222"' >/dev/null
}

@test "sshHosts: expands multiple aliases on one Host line" {
  run sshHosts "$CFG"
  echo "$output" | jq -e 'map(.alias) | index("db1") != null and index("db2") != null' >/dev/null
  echo "$output" | jq -e '.[] | select(.alias=="db1") | .hostname=="10.0.0.5"' >/dev/null
}

@test "sshHosts: skips wildcard and negated patterns" {
  run sshHosts "$CFG"
  echo "$output" | jq -e 'all(.[]; .alias | test("[*?!]") | not)' >/dev/null
}

@test "sshHosts: keys are case-insensitive (Hostname)" {
  run sshHosts "$CFG"
  echo "$output" | jq -e '.[] | select(.alias=="bastion") | .hostname=="bastion.example.com"' >/dev/null
}

@test "sshHosts: missing config yields an empty array" {
  run sshHosts "$BATS_TEST_TMPDIR/nope"
  [ "$output" == "[]" ]
}

@test "sshHosts: expands Include directives" {
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
  run sshHosts "$BATS_TEST_TMPDIR/main"
  echo "$output" | jq -e 'map(.alias) | index("included") != null and index("local") != null' >/dev/null
}
