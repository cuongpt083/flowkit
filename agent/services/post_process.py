"""Post-processing: trim, merge, add music via ffmpeg."""
import subprocess
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

_FLOAT_MIN = 0.0
_FLOAT_MAX = 2.0


def _clamp_float(value: float, name: str, lo: float = _FLOAT_MIN, hi: float = _FLOAT_MAX) -> float:
    """Clamp float to [lo, hi] and warn if out of bounds."""
    if value < lo or value > hi:
        logger.warning("Parameter %s=%s out of bounds [%s, %s], clamping", name, value, lo, hi)
        return max(lo, min(hi, value))
    return value


def trim_video(input_path: str, output_path: str, start: float, end: float) -> bool:
    """Trim video to [start, end] seconds."""
    if not Path(input_path).exists():
        logger.error("trim_video: input file not found: %s", input_path)
        return False
    duration = end - start
    cmd = [
        "ffmpeg", "-y", "-i", input_path,
        "-ss", str(start), "-t", str(duration),
        "-c:v", "libx264", "-preset", "fast", "-crf", "18",
        "-force_key_frames", "expr:gte(t,0)",
        "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart",
        output_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        logger.error("Trim failed: %s", result.stderr[-200:])
        return False
    return True


def merge_videos(video_paths: list[str], output_path: str) -> bool:
    """Concatenate videos using ffmpeg concat demuxer."""
    concat_file = output_path + ".concat.txt"
    try:
        with open(concat_file, "w") as f:
            for p in video_paths:
                # Escape single quotes to prevent path injection in concat file
                escaped = str(p).replace("'", "'\\''")
                f.write(f"file '{escaped}'\n")

        cmd = [
            "ffmpeg", "-y", "-f", "concat", "-safe", "0",
            "-i", concat_file,
            "-c:v", "copy", "-c:a", "copy",
            "-movflags", "+faststart",
            output_path,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    finally:
        Path(concat_file).unlink(missing_ok=True)
    if result.returncode != 0:
        logger.error("Merge failed: %s", result.stderr[-200:])
        return False
    return True


def add_narration(video_path: str, narration_path: str, output_path: str,
                  narration_volume: float = 1.0, sfx_volume: float = 0.4,
                  fade_in: float = 0.5, fade_out: float = 0.5) -> bool:
    """Overlay narration audio on video, ducking the existing SFX track."""
    if not Path(video_path).exists():
        logger.error("add_narration: video file not found: %s", video_path)
        return False
    if not Path(narration_path).exists():
        logger.error("add_narration: narration file not found: %s", narration_path)
        return False

    # Clamp float params to prevent filter injection
    narration_volume = _clamp_float(narration_volume, "narration_volume")
    sfx_volume = _clamp_float(sfx_volume, "sfx_volume")
    fade_in = _clamp_float(fade_in, "fade_in")
    fade_out = _clamp_float(fade_out, "fade_out")

    probe = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", video_path],
        capture_output=True, text=True, timeout=30,
    )
    try:
        duration = float(probe.stdout.strip())
    except (ValueError, AttributeError):
        logger.error("ffprobe failed for %s: %s", video_path, probe.stderr[-200:] if probe.stderr else "no output")
        return False
    fade_start = max(0, duration - fade_out)

    cmd = [
        "ffmpeg", "-y", "-i", video_path, "-i", narration_path,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-filter_complex",
        f"[0:a]volume={sfx_volume}[sfx];[1:a]volume={narration_volume},afade=t=in:st=0:d={fade_in},afade=t=out:st={fade_start}:d={fade_out}[narr];[sfx][narr]amerge=inputs=2,pan=stereo|c0=c0+c2|c1=c1+c3[aout]",
        "-map", "0:v", "-map", "[aout]",
        "-shortest",
        "-movflags", "+faststart",
        output_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        logger.error("Add narration failed: %s", result.stderr[-200:])
        return False
    return True


def add_music(video_path: str, music_path: str, output_path: str,
              music_volume: float = 0.3, fade_in: float = 2.0, fade_out: float = 3.0) -> bool:
    """Overlay background music on video."""
    if not Path(video_path).exists():
        logger.error("add_music: video file not found: %s", video_path)
        return False
    if not Path(music_path).exists():
        logger.error("add_music: music file not found: %s", music_path)
        return False

    # Clamp float params to prevent filter injection
    music_volume = _clamp_float(music_volume, "music_volume")
    fade_in = _clamp_float(fade_in, "fade_in")
    fade_out = _clamp_float(fade_out, "fade_out")

    probe = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", video_path],
        capture_output=True, text=True, timeout=30,
    )
    try:
        duration = float(probe.stdout.strip())
    except (ValueError, AttributeError):
        logger.error("ffprobe failed for %s: %s", video_path, probe.stderr[-200:] if probe.stderr else "no output")
        return False
    fade_start = max(0, duration - fade_out)

    cmd = [
        "ffmpeg", "-y", "-i", video_path, "-i", music_path,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-filter_complex",
        f"[0:a]volume=1.0[orig];[1:a]volume={music_volume},afade=t=in:st=0:d={fade_in},afade=t=out:st={fade_start}:d={fade_out}[music];[orig][music]amerge=inputs=2,pan=stereo|c0=c0+c2|c1=c1+c3[aout]",
        "-map", "0:v", "-map", "[aout]",
        "-shortest",
        "-movflags", "+faststart",
        output_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        logger.error("Add music failed: %s", result.stderr[-200:])
        return False
    return True


# Ken Burns / Vox: one small continuous move. y biased to the top so baked headlines stay in frame.
MOTION_PRESET_NAMES = ("push_in", "pull_out", "pan_right", "pan_left", "hold")

_HOLD_KW = (
    "close-up", "closeup", "close up", "portrait", "headline", "stat",
    "face", "macro", "detail shot",
)
_PAN_KW = (
    "wide", "establishing", "landscape", "map", "skyline", "crowd", "cityscape",
)
_PULL_KW = (
    "pull back", "pull-out", "pull out", "ending", "resolution", "commitment",
    "epilogue", "settle",
)


def infer_motion_preset(scene: dict, *, scene_count: int | None = None) -> str:
    """Pick one Vox camera move from scene text and position."""
    order = int(scene.get("display_order") or 0)
    blob = " ".join((
        scene.get("prompt") or "",
        scene.get("video_prompt") or "",
        scene.get("narrator_text") or "",
    )).lower()
    if scene_count is not None and scene_count > 0 and order >= scene_count - 1:
        return "pull_out"
    if any(k in blob for k in _HOLD_KW):
        return "hold"
    if any(k in blob for k in _PULL_KW):
        return "pull_out"
    if any(k in blob for k in _PAN_KW):
        return "pan_right" if order % 2 == 0 else "pan_left"
    if order == 0:
        return "push_in"
    return "push_in" if order % 2 == 0 else "pan_right"


def probe_media_duration(path: str | Path) -> float | None:
    """Return duration in seconds from ffprobe, or None."""
    src = Path(path)
    if not src.exists():
        return None
    try:
        result = subprocess.run(
            [
                "ffprobe", "-v", "quiet", "-show_entries", "format=duration",
                "-of", "csv=p=0", str(src),
            ],
            capture_output=True, text=True, timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    try:
        value = float((result.stdout or "").strip())
    except ValueError:
        return None
    return value if value > 0 else None


def estimate_motion_duration(scene: dict, tts_seconds: float | None = None) -> float:
    """Fit clip length to VO when possible. Floor 3s, cap 8s."""
    if tts_seconds and tts_seconds > 0:
        return max(3.0, min(float(tts_seconds) + 0.5, 8.0))
    text = (scene.get("narrator_text") or "").strip()
    if text:
        return max(3.0, min(len(text.split()) / 3.5 + 0.5, 8.0))
    try:
        raw = float(scene.get("duration") or 8.0)
    except (TypeError, ValueError):
        raw = 8.0
    return max(3.0, min(raw, 8.0))


def _zoompan_expr(name: str, frames: int) -> str:
    n = max(frames - 1, 1)
    y = "(ih-ih/zoom)*0.12"
    cx = "iw/2-(iw/zoom/2)"
    if name == "push_in":
        step = 0.08 / n
        return f"z='min(zoom+{step:.6f},1.08)':x='{cx}':y='{y}'"
    if name == "pull_out":
        step = 0.08 / n
        return f"z='if(eq(on,1),1.08,max(zoom-{step:.6f},1.0))':x='{cx}':y='{y}'"
    if name == "pan_right":
        return f"z='1.06':x='(iw-iw/zoom)*on/{n}':y='{y}'"
    if name == "pan_left":
        return f"z='1.06':x='(iw-iw/zoom)*(1-on/{n})':y='{y}'"
    return f"z='1.04':x='{cx}':y='{y}'"


def image_to_motion_clip(
    image_path: str,
    output_path: str,
    *,
    duration: float = 8.0,
    orientation: str = "HORIZONTAL",
    preset_index: int = 0,
    preset_name: str | None = None,
    fps: int = 24,
) -> bool:
    """Turn a still image into a short Ken Burns clip with silent stereo audio."""
    src = Path(image_path)
    dest = Path(output_path)
    if not src.exists():
        logger.error("image_to_motion_clip: image not found: %s", image_path)
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)

    duration = max(2.0, min(float(duration), 20.0))
    fps = 24 if fps not in (24, 25, 30) else fps
    frames = max(int(duration * fps), fps * 2)
    if orientation.upper() == "VERTICAL":
        width, height = 1080, 1920
    else:
        width, height = 1920, 1080
    name = preset_name if preset_name in MOTION_PRESET_NAMES else MOTION_PRESET_NAMES[preset_index % 4]
    zoom = _zoompan_expr(name, frames)
    vf = (
        f"scale=8000:-1,zoompan={zoom}:d={frames}:s={width}x{height}:fps={fps},"
        f"format=yuv420p"
    )
    cmd = [
        "ffmpeg", "-y",
        "-loop", "1", "-i", str(src),
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        "-vf", vf,
        "-t", f"{duration:.2f}",
        "-c:v", "libx264", "-preset", "fast", "-crf", "18",
        "-c:a", "aac", "-b:a", "128k", "-ar", "48000", "-ac", "2",
        "-shortest",
        "-movflags", "+faststart",
        str(dest),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if result.returncode != 0:
        logger.error("Ken Burns render failed: %s", result.stderr[-400:])
        return False
    return dest.exists()
