#!/usr/bin/env bats
# payload/sunshine-watchdog.sh: restart Sunshine (via Decky) only when the
# plugin wants it running, it has been gone past the grace period, and the
# restart budget is not exhausted. wd_tick takes "now" so time is simulated.

setup() {
  export SVD_WD_LIB=1
  export SVD_DECKY_SETTINGS="$BATS_TEST_TMPDIR/decky-sunshine.json"
  export RESTARTS="$BATS_TEST_TMPDIR/restarts"
  export SVD_WD_RESTART_CMD="sh -c 'echo x >> $RESTARTS'"
  export SVD_WD_RUNNING_CMD=false
  export SVD_WD_GRACE=60 SVD_WD_LIMIT=3 SVD_WD_WINDOW=600
  echo '{"lastRunState": "start"}' > "$SVD_DECKY_SETTINGS"
  source "$BATS_TEST_DIRNAME/../payload/sunshine-watchdog.sh"
}

restarts() { [ -f "$RESTARTS" ] && wc -l < "$RESTARTS" | tr -d ' ' || echo 0; }

@test "no restart while Sunshine is running" {
  RUNNING_CMD=true
  wd_tick 0; wd_tick 100
  [ "$(restarts)" -eq 0 ]
}

@test "no restart when the user stopped Sunshine in Decky" {
  echo '{"lastRunState": "stop"}' > "$SVD_DECKY_SETTINGS"
  wd_tick 0; wd_tick 100
  [ "$(restarts)" -eq 0 ]
}

@test "no restart when the Decky settings file is missing" {
  rm -f "$SVD_DECKY_SETTINGS"
  wd_tick 0; wd_tick 100
  [ "$(restarts)" -eq 0 ]
}

@test "waits out the grace period, then restarts once" {
  wd_tick 0
  wd_tick 59
  [ "$(restarts)" -eq 0 ]
  wd_tick 60
  [ "$(restarts)" -eq 1 ]
}

@test "grace restarts after Sunshine comes back and dies again" {
  wd_tick 0; wd_tick 60            # restart 1
  RUNNING_CMD=true; wd_tick 70
  RUNNING_CMD=false; wd_tick 80; wd_tick 139
  [ "$(restarts)" -eq 1 ]          # new outage still inside its grace period
  wd_tick 140
  [ "$(restarts)" -eq 2 ]
}

@test "gives up after the restart limit, recovers after the window" {
  for t in 0 60 120 180 240 300; do wd_tick "$t"; done
  [ "$(restarts)" -eq 3 ]
  wd_tick 700                      # first restart (t=60) aged out of the window
  [ "$(restarts)" -eq 4 ]
}
