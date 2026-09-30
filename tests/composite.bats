#!/usr/bin/env bats
# payload/gamescope-composite.sh sets gamescope's GAMESCOPE_COMPOSITE_FORCE
# root-window atom (Game Mode ignores --force-composition and gamescopectl).

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../payload/gamescope-composite.sh"
  export ARGS_LOG="$BATS_TEST_TMPDIR/xprop-args"
  # stub xprop: record DISPLAY and arguments
  cat > "$BATS_TEST_TMPDIR/xprop" <<'EOF'
#!/bin/sh
echo "DISPLAY=$DISPLAY $*" >> "$ARGS_LOG"
EOF
  chmod +x "$BATS_TEST_TMPDIR/xprop"
  export SVD_XPROP="$BATS_TEST_TMPDIR/xprop"
}

@test "on forces composition on the gamescope root window" {
  run "$SCRIPT" on
  [ "$status" -eq 0 ]
  grep -qx "DISPLAY=:0 -root -f GAMESCOPE_COMPOSITE_FORCE 32c -set GAMESCOPE_COMPOSITE_FORCE 1" "$ARGS_LOG"
}

@test "off hands direct scanout back to gamescope" {
  run "$SCRIPT" off
  [ "$status" -eq 0 ]
  grep -qx "DISPLAY=:0 -root -f GAMESCOPE_COMPOSITE_FORCE 32c -set GAMESCOPE_COMPOSITE_FORCE 0" "$ARGS_LOG"
}

@test "anything else is rejected without touching the atom" {
  run "$SCRIPT" maybe
  [ "$status" -ne 0 ]
  [ ! -e "$ARGS_LOG" ]
}
