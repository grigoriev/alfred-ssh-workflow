#!/usr/bin/env bats

# Integration tests for src/ssh.sh. osascript is mocked (tests/mocks/bin) and
# the ssh config is a fixture pointed to by SSH_CONFIG.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export SSH_CONFIG="$BATS_TEST_TMPDIR/config"
  cat > "$SSH_CONFIG" <<'EOF'
Host web
  HostName web.example.com
  User deploy
  Port 2222

Host db1
  HostName 10.0.0.5
EOF
}

@test "ssh.sh: lists hosts from the config" {
  run bash -c '. src/ssh.sh list ""'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.items[].title] | index("web") != null and index("db1") != null' >/dev/null
}

@test "ssh.sh: subtitle shows the ssh target" {
  run bash -c '. src/ssh.sh list ""'
  echo "$output" | jq -e '.items[] | select(.title=="web") | .subtitle=="ssh deploy@web.example.com:2222"' >/dev/null
}

@test "ssh.sh: filters by the query" {
  run bash -c '. src/ssh.sh list "web"'
  echo "$output" | jq -e '[.items[].title] == ["web", "Check for updates"]' >/dev/null
}

@test "ssh.sh: shows an update entry as the last item" {
  run bash -c '. src/ssh.sh list ""'
  echo "$output" | jq -e '.items[-1]
    | .title == "Check for updates" and .valid == false and .autocomplete == "update"' >/dev/null
}

@test "ssh.sh: no hosts shows a hint then the update entry" {
  : > "$SSH_CONFIG"
  run bash -c '. src/ssh.sh list ""'
  [[ "$output" =~ "No SSH hosts found" ]]
  echo "$output" | jq -e '.items[-1].title == "Check for updates"' >/dev/null
}

@test "ssh.sh: home offers an autoupdate toggle" {
  run bash -c '. src/ssh.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("Autoupdate: off") != null' >/dev/null
}

@test "ssh.sh: the toggle is hidden while filtering" {
  run bash -c '. src/ssh.sh list "web"'
  echo "$output" | jq -e '[.items[].title] | index("Autoupdate: off") == null' >/dev/null
}

@test "ssh.sh: run autoupdate on enables it and the toggle flips" {
  run bash -c '. src/ssh.sh run "autoupdate on"'
  [ -f "$alfred_workflow_data/autoupdate" ]
  run bash -c '. src/ssh.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("Autoupdate: on") != null' >/dev/null
}

@test "ssh.sh: shows an update banner when one is pending" {
  mkdir -p "$alfred_workflow_data"
  : > "$alfred_workflow_data/autoupdate"
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"Update to v9","arg":"https://example.com/SSH.alfredworkflow"}]}'
STUB
  run bash -c '. src/ssh.sh list ""'
  rm -f src/update.sh
  echo "$output" | jq -e '[.items[].title] | index("Update available") != null' >/dev/null
}

@test "ssh.sh: run opens an ssh session via osascript" {
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  run bash -c '. src/ssh.sh run "web"'
  [ "$status" -eq 0 ]
  grep -q "web" "$OSASCRIPT_LOG"
}

@test "ssh.sh: update query dispatches to the updater" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
echo "updater [$1]"
STUB
  run bash -c '. src/ssh.sh list "update"'
  rm -f src/update.sh
  [[ "$output" =~ "updater []" ]]
}

@test "ssh.sh: run with a url dispatches to the updater" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
echo "install [$1]"
STUB
  run bash -c '. src/ssh.sh run "https://example.com/SSH.alfredworkflow"'
  rm -f src/update.sh
  [[ "$output" =~ "install [https://example.com/SSH.alfredworkflow]" ]]
}
