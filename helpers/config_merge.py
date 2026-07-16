#!/usr/bin/env python3
"""Merge one global_prep_cmd entry into a Sunshine sunshine.conf, idempotently.

Sunshine's conf is line-based `key = value`; global_prep_cmd's value is a JSON
array of {do, undo, elevated} objects. We key idempotency on the `do` string.
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


def main(argv):
    if len(argv) != 4:
        print("usage: config_merge.py <conf_path> <do> <undo>", file=sys.stderr)
        return 2
    path, do, undo = argv[1], argv[2], argv[3]
    try:
        with open(path, "r") as f:
            text = f.read()
    except FileNotFoundError:
        text = ""
    with open(path, "w") as f:
        f.write(merge_prep_cmd(text, do, undo))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
