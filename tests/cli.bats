#!/usr/bin/env bats

setup() { SVD="$BATS_TEST_DIRNAME/../svd"; }

@test "no command prints usage and exits non-zero" {
  run "$SVD"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]] || false
}

@test "unknown command errors" {
  run "$SVD" frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown command"* ]] || false
}

@test "help lists all commands" {
  run "$SVD" help
  [ "$status" -eq 0 ]
  for c in install repair status check-prereqs heal heal-check uninstall; do
    [[ "$output" == *"$c"* ]] || false
  done
}

@test "--dry-run is parsed and exposed" {
  run "$SVD" status --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]] || false
}
