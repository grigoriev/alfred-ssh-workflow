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
  echo "$output" | jq -e '[.items[].title] == ["web"]' >/dev/null
}

@test "ssh.sh: no hosts shows a hint" {
  : > "$SSH_CONFIG"
  run bash -c '. src/ssh.sh list ""'
  [[ "$output" =~ "No SSH hosts found" ]]
}

@test "ssh.sh: the home view has no inline update or toggle items" {
  run bash -c '. src/ssh.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("Check for updates") == null and index("Autoupdate: off") == null' >/dev/null
}

@test "ssh.sh: > lists settings and update items" {
  run bash -c '. src/ssh.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Edit SSH config") != null and index("Check for updates") != null and index("Activate autoupdate") != null' >/dev/null
}

@test "ssh.sh: > update dispatches to the updater" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
echo "updater [$1]"
STUB
  run bash -c '. src/ssh.sh list "> update"'
  rm -f src/update.sh
  [[ "$output" =~ "updater []" ]]
}

@test "ssh.sh: run autoupdate on enables it and > reflects it" {
  run bash -c '. src/ssh.sh run "autoupdate on"'
  [ -f "$alfred_workflow_data/autoupdate" ]
  run bash -c '. src/ssh.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Deactivate autoupdate") != null' >/dev/null
}

@test "ssh.sh: run edit-config opens the ssh config" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/ssh.sh run "edit-config"'
  grep -q "config" "$OPEN_LOG"
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

@test "ssh.sh: run with a url dispatches to the updater" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
echo "install [$1]"
STUB
  run bash -c '. src/ssh.sh run "https://example.com/SSH.alfredworkflow"'
  rm -f src/update.sh
  [[ "$output" =~ "install [https://example.com/SSH.alfredworkflow]" ]]
}
