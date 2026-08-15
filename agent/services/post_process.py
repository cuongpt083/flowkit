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


# Ken Burns / Vox-style still → clip. Preset strings are fixed (no user input).
_MOTION_PRESETS = (
    "z='min(zoom+0.0012,1.12)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'",
    "z='if(eq(on,1),1.12,max(zoom-0.0012,1.0))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'",
    "z='1.08':x='(iw-iw/zoom)*on/{frames}':y='ih/2-(ih/zoom/2)'",
    "z='1.08':x='(iw-iw/zoom)*(1-on/{frames})':y='ih/2-(ih/zoom/2)'",
)


def image_to_motion_clip(
    image_path: str,
    output_path: str,
    *,
    duration: float = 8.0,
    orientation: str = "HORIZONTAL",
    preset_index: int = 0,
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
    preset = _MOTION_PRESETS[preset_index % len(_MOTION_PRESETS)]
    zoom = preset.replace("{frames}", str(max(frames - 1, 1)))
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
