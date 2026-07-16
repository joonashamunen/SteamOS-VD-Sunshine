from helpers.build_id import read_build_id, is_changed

OS = 'NAME=SteamOS\nBUILD_ID=20260601.1\nVERSION=3.6\n'

def test_reads_build_id(tmp_path):
    p = tmp_path / "os-release"; p.write_text(OS)
    assert read_build_id(str(p)) == "20260601.1"

def test_changed_when_no_stamp(tmp_path):
    osr = tmp_path / "os-release"; osr.write_text(OS)
    assert is_changed(str(osr), str(tmp_path / "nope.stamp")) is True

def test_not_changed_when_stamp_matches(tmp_path):
    osr = tmp_path / "os-release"; osr.write_text(OS)
    st = tmp_path / "s"; st.write_text("20260601.1")
    assert is_changed(str(osr), str(st)) is False

def test_changed_when_stamp_differs(tmp_path):
    osr = tmp_path / "os-release"; osr.write_text(OS)
    st = tmp_path / "s"; st.write_text("20260101.0")
    assert is_changed(str(osr), str(st)) is True
