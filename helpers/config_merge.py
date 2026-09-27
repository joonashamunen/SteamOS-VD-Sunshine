#!/usr/bin/env python3
"""Merge one global_prep_cmd entry into a Sunshine sunshine.conf, idempotently.

Sunshine's conf is line-based `key = value`; global_prep_cmd's value is a JSON
array of {do, undo, elevated} objects. We key idempotency on the `do` string.
Extra `key=value` arguments are set as plain keys (e.g. system_tray=disabled).
"""
import json
import sys

KEY = "global_prep_cmd"


def merge_prep_cmd(text: str, do: str, undo: str) -> str:
    lines = text.splitlines()
    out, existing = [], []
    for line in lines:
        if line.strip().startswith(KEY) and "=" in line:
            raw = line.split("=", 1)[1].strip()
            try:
                existing = json.loads(raw) if raw else []
            except json.JSONDecodeError:
                existing = []
            continue  # drop; we re-emit below
        out.append(line)

    entry = {"do": do, "undo": undo, "elevated": "false"}
    merged = [e for e in existing if e.get("do") != do]
    merged.append(entry)

    out.append(f"{KEY} = {json.dumps(merged)}")
    result = "\n".join(out)
    if not result.endswith("\n"):
        result += "\n"
    return result


def set_key(text: str, key: str, value: str) -> str:
    """Set a plain `key = value` line, replacing any existing value for key."""
    out = [
        line for line in text.splitlines()
        if not (line.split("=", 1)[0].strip() == key and "=" in line)
    ]
    out.append(f"{key} = {value}")
    return "\n".join(out) + "\n"


def main(argv):
    if len(argv) < 4 or any("=" not in a for a in argv[4:]):
        print("usage: config_merge.py <conf_path> <do> <undo> [key=value ...]", file=sys.stderr)
        return 2
    path, do, undo = argv[1], argv[2], argv[3]
    try:
        with open(path, "r") as f:
            text = f.read()
    except FileNotFoundError:
        text = ""
    text = merge_prep_cmd(text, do, undo)
    for pair in argv[4:]:
        key, value = pair.split("=", 1)
        text = set_key(text, key.strip(), value.strip())
    with open(path, "w") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
