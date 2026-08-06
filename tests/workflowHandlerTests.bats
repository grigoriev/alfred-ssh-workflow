#!/usr/bin/env bats

. src/workflowHandler.sh

setup() {
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
}

@test "jsonEncode: escape quote and backslash" {
  run jsonEncode 'a"b\c'
  [ "$output" == 'a\"b\\c' ]
}

@test "jsonEncode: plain text is unchanged" {
  run jsonEncode "web-1"
  [ "$output" == "web-1" ]
}

@test "addResult and getJSONResults: build feedback json" {
  addResult "uid1" "arg1" "Title" "Subtitle" "icon.png" "yes" "auto"
  run getJSONResults

  [ "$status" -eq 0 ]
  [[ "$output" =~ '"items":[' ]]
  [[ "$output" =~ '"title":"Title"' ]]
  [[ "$output" =~ '"subtitle":"Subtitle"' ]]
  [[ "$output" =~ '"arg":"arg1"' ]]
  [[ "$output" =~ '"uid":"uid1"' ]]
  [[ "$output" =~ '"icon":{"path":"icon.png"}' ]]
  [[ "$output" =~ '"autocomplete":"auto"' ]]
}

@test "addResult: escapes special characters in fields" {
  addResult "" 'a"b' 'back\slash' "" "" "" ""
  run getJSONResults
  [[ "$output" =~ '"arg":"a\"b"' ]]
  [[ "$output" =~ '"title":"back\\slash"' ]]
}

@test "addResult: ARG_PREFIX prefixes a non-empty arg" {
  ARG_PREFIX="ssh "
  addResult "" "web" "web" "" "i.png"
  run getJSONResults
  [[ "$output" =~ '"arg":"ssh web"' ]]
}

@test "addResult: omits uid when empty and marks invalid" {
  addResult "" "" "Info" "row" "i.png" "no" ""
  run getJSONResults
  [[ ! "$output" =~ '"uid"' ]]
  [[ "$output" =~ '"valid":false' ]]
}

@test "getJSONResults: empty result set is valid json" {
  run getJSONResults
  [ "$output" == '{"items":[]}' ]
}

@test "getJSONResults: emit rerun and variables" {
  setRerun 0.1
  addVariable "checking" "1"
  addResult "" "" "Loading" "" "i.png" "no" ""
  run getJSONResults
  [[ "$output" =~ '"rerun":0.1' ]]
  [[ "$output" =~ '"variables":{"checking":"1"}' ]]
  [[ "$output" =~ '"items":[' ]]
}

@test "setPref and getPref: store and read a value" {
  setPref "host" "web.example.com" 1
  run getPref "host" 1
  [ "$output" == "web.example.com" ]
}

@test "getPref: key is not matched as a substring" {
  setPref "db" "10.0.0.5" 1
  setPref "db2" "10.0.0.6" 1
  run getPref "db" 1
  [ "$output" == "10.0.0.5" ]
}
