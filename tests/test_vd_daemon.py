"""payload/vd-daemon.py must neutralise the upstream daemon's DRM-master theft.

A fake upstream tree stands in for sunshine_virt_display: its CRTC helpers
record calls, so the test fails if the real (master-stealing) code would run.
"""
import os
import subprocess
import sys
import textwrap
from pathlib import Path

LAUNCHER = Path(__file__).resolve().parent.parent / "payload" / "vd-daemon.py"


def _fake_upstream(root: Path) -> None:
    (root / "src" / "daemon").mkdir(parents=True)
    (root / "src" / "__init__.py").write_text("")
    (root / "src" / "display.py").write_text(textwrap.dedent("""
        CALLS = []
        def release_crtc(card, port):
            CALLS.append(("release_crtc", card, port)); return True
        def force_crtc_assignment(card, port):
            CALLS.append(("force_crtc_assignment", card, port)); return True
        def wait_for_output_ready(card, port, w, h, timeout=5.0):
            CALLS.append(("wait", card, port)); return True, "1920x1080"
    """))
    (root / "src" / "daemon" / "daemon.py").write_text(textwrap.dedent("""
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent.parent))
        from src import display
        def main():
            display.release_crtc("card0", "HDMI-A-1")
            display.force_crtc_assignment("card0", "DP-1")
            ok, mode = display.wait_for_output_ready("card0", "DP-1", 0, 0, timeout=1.0)
            print("REAL_CALLS=" + ",".join(c[0] for c in display.CALLS))
            print("READY=%s %s" % (ok, mode))
    """))


def _run(tmp_path: Path) -> str:
    _fake_upstream(tmp_path)
    pokes = tmp_path / "pokes"
    env = dict(os.environ, SVD_VD_DIR=str(tmp_path),
               SVD_POKE_CMD=f"sh -c 'echo x >> {pokes}'")
    out = subprocess.run([sys.executable, str(LAUNCHER)], env=env,
                         capture_output=True, text=True, check=True).stdout
    return out + "POKES=%d" % (len(pokes.read_text().splitlines()) if pokes.exists() else 0)


def test_crtc_helpers_never_reach_upstream(tmp_path):
    out = _run(tmp_path)
    real = out.split("REAL_CALLS=")[1].splitlines()[0].split(",")
    assert "release_crtc" not in real
    assert "force_crtc_assignment" not in real


def test_replacements_poke_udev_and_wait_still_works(tmp_path):
    out = _run(tmp_path)
    assert "READY=True 1920x1080" in out
    assert int(out.split("POKES=")[1]) >= 2  # one per neutralised helper
