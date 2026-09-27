#!/usr/bin/env python3
"""svd launcher for the sunshine_virt_display v2 daemon, gamescope-safe.

Upstream takes DRM master away from the compositor to release CRTCs (connect
step 5, disconnect step 3) and to force a dumb framebuffer onto the virtual
connector when the compositor is slow (connect step 7, disconnect step 2).
gamescope SIGABRTs when its master is stolen, restarting Game Mode and killing
the running game. Here those helpers only poke udev: gamescope re-reads the
connectors on the change event and moves to whichever output is connected
(the physical display is already forced "off" via sysfs), without anyone else
touching its KMS state. The upstream code is otherwise run unmodified.
"""
import importlib.util
import os
import shlex
import subprocess
import sys
import time

VD_DIR = os.environ.get("SVD_VD_DIR", "/home/deck/sunshine_virt_display")
POKE_CMD = os.environ.get("SVD_POKE_CMD", "udevadm trigger --subsystem-match=drm --action=change")
WAIT_SECONDS = 15.0  # upstream waits 5 s, then forces; gamescope needs a few pokes

sys.path.insert(0, VD_DIR)
from src import display  # noqa: E402  (after sys.path setup)

_upstream_wait = display.wait_for_output_ready


def _poke() -> None:
    subprocess.run(shlex.split(POKE_CMD), check=False)


def _release_crtc(card_name, port):
    _poke()
    return True


def _force_crtc_assignment(card_name, port):
    _poke()
    return True


def _wait_for_output_ready(card_name, port, width, height, timeout=5.0):
    deadline = time.monotonic() + max(timeout, WAIT_SECONDS)
    while True:
        ready, mode = _upstream_wait(card_name, port, width, height, timeout=1.0)
        if ready or time.monotonic() >= deadline:
            return ready, mode
        _poke()


display.release_crtc = _release_crtc
display.force_crtc_assignment = _force_crtc_assignment
display.wait_for_output_ready = _wait_for_output_ready

spec = importlib.util.spec_from_file_location(
    "sunshine_vd_daemon", os.path.join(VD_DIR, "src", "daemon", "daemon.py"))
daemon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(daemon)
sys.argv = [sys.argv[0]]
daemon.main()
