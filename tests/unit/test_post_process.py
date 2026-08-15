"""Tests for Ken Burns / motion-graphic still → clip."""

from unittest.mock import MagicMock, patch

from agent.services.post_process import image_to_motion_clip


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
