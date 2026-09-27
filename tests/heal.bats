#!/usr/bin/env bats

setup() {
  export SVD_ROOT="$BATS_TEST_TMPDIR/svd"; mkdir -p "$SVD_ROOT"
  export DRY_RUN=0
  # Do NOT source lib/common.sh in bats tests: it defines a `run` function
  # that shadows bats' built-in `run`. Stub the only helper heal.sh needs at
  # source time, then source heal.sh (which does not define `run`).
  log() { echo "$*"; }
  source "$BATS_TEST_DIRNAME/../lib/heal.sh"
  # redirect the real system paths into the tmp sandbox
  export SYSTEM_UNIT="$BATS_TEST_TMPDIR/svd-heal.service"
  export USER_UNIT="$BATS_TEST_TMPDIR/user-svd-heal.service"
}

@test "system unit runs svd heal as a root oneshot at boot" {
  run heal_render_unit
  [ "$status" -eq 0 ]
  [[ "$output" == *"ExecStart=/home/deck/.local/bin/svd heal"* ]] || false
  [[ "$output" == *"Type=oneshot"* ]] || false
  [[ "$output" == *"WantedBy=multi-user.target"* ]] || false
  [[ "$output" != *"User="* ]] || false   # root: no sudo, so no sudoers rule to lose
  [[ "$output" != *"sudo"* ]] || false
}

@test "user unit only runs the unprivileged heal-check" {
  run heal_render_user_unit
  [ "$status" -eq 0 ]
  [[ "$output" == *"svd heal-check"* ]] || false
  [[ "$output" == *"WantedBy=default.target"* ]] || false
}

@test "heal-check warns when the root heal unit is missing" {
  rm -f "$SYSTEM_UNIT"
  run heal_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"sudo svd repair"* ]] || false
}

@test "heal-check is quiet when the root heal unit is present" {
  heal_render_unit > "$SYSTEM_UNIT"
  run heal_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "heal refuses to run without root" {
  [ "$(id -u)" -ne 0 ] || skip "running as root"
  run heal_run "$BATS_TEST_DIRNAME/.."
  [ "$status" -ne 0 ]
  [[ "$output" == *"root"* ]] || false
}
