#!/usr/bin/env bats

# Performance guard for the Script Filter. Times the hot path over a large
# generated config and fails only on an order-of-magnitude regression, such as
# re-introducing a per-host subprocess spawn. The measured time is printed so a
# slowdown is visible in the test output even before it trips the budget.
#
# Times with jq's `now` (already a dependency); BSD `date` has no %N.

BUDGET_MS=1000
HOSTS=300

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  BIG="$BATS_TEST_TMPDIR/big"
  local i
  for i in $(seq 1 "$HOSTS"); do
    printf 'Host host%d\n  HostName h%d.example.com\n  User u%d\n  Port 22\n\n' "$i" "$i" "$i"
  done > "$BIG"
  export SSH_CONFIG="$BIG"
}

now_ms() { jq -n 'now * 1000 | floor'; }

@test "perf: ssh list over many hosts stays fast" {
  local start end ms
  start=$(now_ms)
  run bash -c '. src/ssh.sh list ""'
  end=$(now_ms)
  ms=$((end - start))
  [ "$status" -eq 0 ]
  echo "# ssh list ($HOSTS hosts): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}

@test "perf: ssh list filtered over many hosts stays fast" {
  local start end ms
  start=$(now_ms)
  run bash -c '. src/ssh.sh list "host25"'
  end=$(now_ms)
  ms=$((end - start))
  [ "$status" -eq 0 ]
  echo "# ssh list filtered ($HOSTS hosts): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}
