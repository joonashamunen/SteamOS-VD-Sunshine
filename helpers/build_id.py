#!/usr/bin/env python3
"""Read SteamOS BUILD_ID and compare against a stamp file to detect updates."""
import sys


def read_build_id(os_release_path: str) -> str:
    with open(os_release_path) as f:
        for line in f:
            if line.startswith("BUILD_ID="):
                return line.split("=", 1)[1].strip().strip('"')
    return ""


def is_changed(os_release_path: str, stamp_path: str) -> bool:
    current = read_build_id(os_release_path)
    try:
        with open(stamp_path) as f:
            stamped = f.read().strip()
    except FileNotFoundError:
        return True
    return current != stamped


def main(argv):
    if len(argv) >= 3 and argv[1] == "current":
        print(read_build_id(argv[2])); return 0
    if len(argv) >= 4 and argv[1] == "changed":
        return 0 if is_changed(argv[2], argv[3]) else 1
    print("usage: build_id.py current <os_release> | changed <os_release> <stamp>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
