"""Tests for Ken Burns / motion-graphic still → clip."""

from pathlib import Path
from unittest.mock import MagicMock, patch

from agent.services.post_process import (
    _zoompan_expr,
    estimate_motion_duration,
    format_concat_entry,
    image_to_motion_clip,
    infer_motion_preset,
    merge_videos,
)


def test_image_to_motion_clip_builds_zoompan_and_silent_audio(tmp_path):
    still = tmp_path / "in.jpg"
    still.write_bytes(b"fake-jpeg")
    out = tmp_path / "out.mp4"

    fake = MagicMock()
    fake.returncode = 0

    with patch("agent.services.post_process.subprocess.run", return_value=fake) as run:
        # Pretend ffmpeg wrote the file
        def _write(*args, **kwargs):
            out.write_bytes(b"mp4")
            return fake

        run.side_effect = _write
        ok = image_to_motion_clip(str(still), str(out), duration=8, orientation="HORIZONTAL", preset_index=0)

    assert ok is True
    cmd = run.call_args[0][0]
    assert cmd[0] == "ffmpeg"
    assert "zoompan=" in " ".join(cmd)
    assert "anullsrc=" in " ".join(cmd)
    assert "1920x1080" in " ".join(cmd)


def test_image_to_motion_clip_vertical_size(tmp_path):
    still = tmp_path / "in.jpg"
    still.write_bytes(b"x")
    out = tmp_path / "out.mp4"
    fake = MagicMock(returncode=0)

    with patch("agent.services.post_process.subprocess.run", return_value=fake) as run:
        def _write(*args, **kwargs):
            out.write_bytes(b"mp4")
            return fake

        run.side_effect = _write
        image_to_motion_clip(str(still), str(out), orientation="VERTICAL")

    assert "1080x1920" in " ".join(run.call_args[0][0])


def test_image_to_motion_clip_missing_source(tmp_path):
    assert image_to_motion_clip(str(tmp_path / "nope.jpg"), str(tmp_path / "o.mp4")) is False


def test_image_to_motion_clip_named_preset_caps_zoom(tmp_path):
    still = tmp_path / "in.jpg"
    still.write_bytes(b"x")
    out = tmp_path / "out.mp4"
    fake = MagicMock(returncode=0)

    with patch("agent.services.post_process.subprocess.run", return_value=fake) as run:
        def _write(*args, **kwargs):
            out.write_bytes(b"mp4")
            return fake

        run.side_effect = _write
        image_to_motion_clip(
            str(still), str(out), duration=4, orientation="HORIZONTAL", preset_name="hold",
        )

    joined = " ".join(run.call_args[0][0])
    assert "1.04" in joined
    assert "1.12" not in joined


def test_infer_motion_preset_hook_hold_wide_last():
    assert infer_motion_preset({"display_order": 0}) == "push_in"
    assert infer_motion_preset({"display_order": 2, "prompt": "Close-up of the headline"}) == "hold"
    assert infer_motion_preset({"display_order": 2, "prompt": "Wide establishing skyline"}) == "pan_right"
    assert infer_motion_preset({"display_order": 9}, scene_count=10) == "pull_out"


def test_estimate_motion_duration_from_tts_and_words():
    assert estimate_motion_duration({}, 4.0) == 4.5
    # 7 words / 3.5 + 0.5 = 2.5 → floor 3.0
    assert estimate_motion_duration({"narrator_text": "one two three four five six seven"}) == 3.0
    assert estimate_motion_duration({"duration": 12}) == 8.0


def test_zoompan_expr_protects_top_and_limits_zoom():
    expr = _zoompan_expr("push_in", 96)
    assert "1.08" in expr
    assert "0.12" in expr
    assert _zoompan_expr("hold", 48).startswith("z='1.04'")


def test_format_concat_entry_uses_forward_slashes_and_escapes_quotes():
    assert format_concat_entry(r"C:\Users\Admin\clip.mp4") == "file 'C:/Users/Admin/clip.mp4'"
    assert format_concat_entry(r"C:\Users\Admin\a'b.mp4") == "file 'C:/Users/Admin/a'\\''b.mp4'"
    assert format_concat_entry("/tmp/scene 1.mp4") == "file '/tmp/scene 1.mp4'"


def test_merge_videos_writes_posix_concat_list(tmp_path):
    out = tmp_path / "merged.mp4"
    fake = MagicMock(returncode=0)
    clips = [r"C:\Users\Admin\a.mp4", r"C:\Users\Admin\b.mp4"]
    captured = {}

    def _run(cmd, **kwargs):
        concat_path = cmd[cmd.index("-i") + 1]
        captured["text"] = Path(concat_path).read_text(encoding="utf-8")
        captured["cmd"] = cmd
        return fake

    with patch("agent.services.post_process.subprocess.run", side_effect=_run):
        assert merge_videos(clips, str(out)) is True

    assert "file 'C:/Users/Admin/a.mp4'\n" in captured["text"]
    assert "file 'C:/Users/Admin/b.mp4'\n" in captured["text"]
    assert "\\" not in captured["text"]
    assert not Path(str(out) + ".concat.txt").exists()
