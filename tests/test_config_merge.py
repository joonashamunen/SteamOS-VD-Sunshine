import json
from helpers.config_merge import merge_prep_cmd, remove_prep_cmd, set_key

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

def test_set_key_adds_when_absent():
    out = set_key("sunshine_name = deck\n", "system_tray", "disabled")
    assert "system_tray = disabled" in out.splitlines()
    assert "sunshine_name = deck" in out

def test_set_key_replaces_existing_value():
    out = set_key("system_tray = enabled\nport = 47989\n", "system_tray", "disabled")
    lines = out.splitlines()
    assert lines.count("system_tray = disabled") == 1
    assert "system_tray = enabled" not in lines
    assert "port = 47989" in lines

def test_set_key_idempotent():
    once = set_key("", "system_tray", "disabled")
    assert set_key(once, "system_tray", "disabled") == once

def test_set_key_does_not_match_key_prefix():
    out = set_key("system_tray_icon = x\n", "system_tray", "disabled")
    assert "system_tray_icon = x" in out.splitlines()


def test_remove_drops_only_our_entry():
    text = merge_prep_cmd('global_prep_cmd = [{"do":"echo hi","undo":"echo bye","elevated":"false"}]\n', DO, UNDO)
    out = remove_prep_cmd(text, DO)
    assert [x["do"] for x in _entries(out)] == ["echo hi"]

def test_remove_drops_key_when_nothing_left_and_keeps_other_keys():
    text = set_key(merge_prep_cmd("", DO, UNDO), "system_tray", "disabled")
    out = remove_prep_cmd(text, DO)
    assert _entries(out) is None
    assert "system_tray = disabled" in out.splitlines()

def test_remove_is_noop_when_absent():
    assert remove_prep_cmd("port = 47989\n", DO) == "port = 47989\n"
