#!/usr/bin/env bats

. src/workflow_handler.sh

setup() {
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
}

@test "json_encode: escape quote and backslash" {
  run json_encode 'a"b\c'
  [ "$output" == 'a\"b\\c' ]
}

@test "json_encode: plain text is unchanged" {
  run json_encode "web-1"
  [ "$output" == "web-1" ]
}

@test "add_result and get_json_results: build feedback json" {
  add_result "uid1" "arg1" "Title" "Subtitle" "icon.png" "yes" "auto"
  run get_json_results

  [ "$status" -eq 0 ]
  [[ "$output" =~ '"items":[' ]]
  [[ "$output" =~ '"title":"Title"' ]]
  [[ "$output" =~ '"subtitle":"Subtitle"' ]]
  [[ "$output" =~ '"arg":"arg1"' ]]
  [[ "$output" =~ '"uid":"uid1"' ]]
  [[ "$output" =~ '"icon":{"path":"icon.png"}' ]]
  [[ "$output" =~ '"autocomplete":"auto"' ]]
}

@test "add_result: escapes special characters in fields" {
  add_result "" 'a"b' 'back\slash' "" "" "" ""
  run get_json_results
  [[ "$output" =~ '"arg":"a\"b"' ]]
  [[ "$output" =~ '"title":"back\\slash"' ]]
}

@test "add_result: ARG_PREFIX prefixes a non-empty arg" {
  ARG_PREFIX="ssh "
  add_result "" "web" "web" "" "i.png"
  run get_json_results
  [[ "$output" =~ '"arg":"ssh web"' ]]
}

@test "add_result: omits uid when empty and marks invalid" {
  add_result "" "" "Info" "row" "i.png" "no" ""
  run get_json_results
  [[ ! "$output" =~ '"uid"' ]]
  [[ "$output" =~ '"valid":false' ]]
}

@test "get_json_results: empty result set is valid json" {
  run get_json_results
  [ "$output" == '{"items":[]}' ]
}

@test "get_json_results: emit rerun and variables" {
  set_rerun 0.1
  add_variable "checking" "1"
  add_result "" "" "Loading" "" "i.png" "no" ""
  run get_json_results
  [[ "$output" =~ '"rerun":0.1' ]]
  [[ "$output" =~ '"variables":{"checking":"1"}' ]]
  [[ "$output" =~ '"items":[' ]]
}

@test "set_pref and get_pref: store and read a value" {
  set_pref "host" "web.example.com" 1
  run get_pref "host" 1
  [ "$output" == "web.example.com" ]
}

@test "get_pref: key is not matched as a substring" {
  set_pref "db" "10.0.0.5" 1
  set_pref "db2" "10.0.0.6" 1
  run get_pref "db" 1
  [ "$output" == "10.0.0.5" ]
}
