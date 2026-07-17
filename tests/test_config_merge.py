import json
from helpers.config_merge import merge_prep_cmd

DO = 'sh /root/.var/app/dev.lizardbyte.app.Sunshine/config/vd-connect.sh'
UNDO = 'sh -c "echo disconnect > /root/.var/app/dev.lizardbyte.app.Sunshine/config/trigger.fifo"'

def _entries(text):
    for line in text.splitlines():
        if line.startswith("global_prep_cmd"):
            return json.loads(line.split("=", 1)[1].strip())
    return None

def test_adds_key_when_absent():
    out = merge_prep_cmd("sunshine_name = deck\n", DO, UNDO)
    e = _entries(out)
    assert e == [{"do": DO, "undo": UNDO, "elevated": "false"}]
    assert "sunshine_name = deck" in out  # preserves other keys

def test_idempotent_no_duplicate():
    once = merge_prep_cmd("", DO, UNDO)
    twice = merge_prep_cmd(once, DO, UNDO)
    assert once == twice
    assert len(_entries(twice)) == 1

def test_preserves_unrelated_existing_entries():
    existing = 'global_prep_cmd = [{"do":"echo hi","undo":"echo bye","elevated":"false"}]\n'
    out = merge_prep_cmd(existing, DO, UNDO)
    dos = [x["do"] for x in _entries(out)]
    assert "echo hi" in dos and DO in dos
    assert len(dos) == 2

def test_replaces_our_entry_if_undo_changed():
    stale = merge_prep_cmd("", DO, "old-undo")
    out = merge_prep_cmd(stale, DO, UNDO)
    e = _entries(out)
    assert len(e) == 1 and e[0]["undo"] == UNDO
