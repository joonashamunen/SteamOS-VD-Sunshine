#!/usr/bin/env bats

setup() {
  # Do NOT source lib/common.sh: it defines a `run` function that shadows
  # bats' built-in `run`. Stub the only helper prereqs.sh needs, then source it.
  log() { :; }
  source "$BATS_TEST_DIRNAME/../lib/prereqs.sh"
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
  [[ "$output" == *"Decky Loader"* ]] || false
}

@test "fails and guides when only plugin missing" {
  _has_decky() { return 0; }; _has_decky_sunshine() { return 1; }
  run check_prereqs
  [ "$status" -ne 0 ]
  [[ "$output" == *"Decky Sunshine"* ]] || false
}
