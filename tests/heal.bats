#!/usr/bin/env bats

setup() {
  export SVD_ROOT="$BATS_TEST_TMPDIR/svd"; mkdir -p "$SVD_ROOT"
  export DRY_RUN=0
  # Do NOT source lib/common.sh in bats tests: it defines a `run` function
  # that shadows bats' built-in `run`. Stub the only helper heal.sh needs at
  # source time, then source heal.sh (which does not define `run`).
  log() { :; }
  source "$BATS_TEST_DIRNAME/../lib/heal.sh"
  # redirect the real system paths into the tmp sandbox
  export USER_UNIT="$BATS_TEST_TMPDIR/svd-heal.service"
  export SUDOERS="$BATS_TEST_TMPDIR/svd-heal.sudoers"
}

@test "heal_render_unit invokes svd heal" {
  run heal_render_unit
  [ "$status" -eq 0 ]
  [[ "$output" == *" heal"* ]]
  [[ "$output" == *"oneshot"* ]]
}

@test "heal_render_sudoers scopes to svd repair only" {
  run heal_render_sudoers
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOPASSWD"* ]]
  [[ "$output" == *"svd repair"* ]]
}

@test "default sudoers file sorts after SteamOS's own sudoers.d entries" {
  # sudoers: last match wins, and sudoers.d is read in lexical order. SteamOS
  # ships wheel ("%wheel ALL=(ALL) ALL"); a file sorting before it is overridden.
  unset SUDOERS
  source "$BATS_TEST_DIRNAME/../lib/heal.sh"
  name="$(basename "$SUDOERS")"
  for shipped in no-fqdn sudo wheel wheel-prepare-oobe-test; do
    [[ "$name" > "$shipped" ]]
  done
}
