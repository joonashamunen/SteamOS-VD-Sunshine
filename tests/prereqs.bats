#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../lib/common.sh"
  source "$BATS_TEST_DIRNAME/../lib/prereqs.sh"
  # Override run function to capture status and output for bats compatibility
  run() {
    local output_var
    local status_var
    set +e
    output_var=$( "$@" 2>&1 )
    status_var=$?
    set -e
    export status="$status_var"
    export output="$output_var"
  }
}

@test "passes when both present" {
  _has_decky() { return 0; }; _has_decky_sunshine() { return 0; }
  run check_prereqs
  [ "$status" -eq 0 ]
}

@test "fails and guides when decky missing" {
  _has_decky() { return 1; }; _has_decky_sunshine() { return 1; }
  run check_prereqs
  [ "$status" -ne 0 ]
  [[ "$output" == *"Decky Loader"* ]]
}

@test "fails and guides when only plugin missing" {
  _has_decky() { return 0; }; _has_decky_sunshine() { return 1; }
  run check_prereqs
  [ "$status" -ne 0 ]
  [[ "$output" == *"Decky Sunshine"* ]]
}
