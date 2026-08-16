Download and concatenate all scene videos into a single video with optional TTS narration.

Usage: `/fk-concat <video_id> [--with-tts] [--4k]`

Default: uses best available quality (4K upscale > regular video), preserves original audio.

## Step 1: Get project, video, and scenes

```bash
curl -s http://127.0.0.1:8100/api/videos/<VID>
# Get project_id from video response
curl -s http://127.0.0.1:8100/api/projects/<PID>
curl -s "http://127.0.0.1:8100/api/scenes?video_id=<VID>"
```

Note: project name (for output folder), orientation (HORIZONTAL or VERTICAL).
Sort scenes by `display_order`.

## Step 2: Determine video source for each scene

Priority order for each scene:
1. **Local 4K file** that `ffprobe` accepts and is **> 10KB**: `${OUTDIR}/4k/scene_${IDX3}_${scene_id}.mp4` then `${OUTDIR}/4k/{scene_id}.mp4`. A 111–400 byte file is a saved 403 body — delete it and treat as missing.
2. **Motion clip:** `${OUTDIR}/motion/scene_${IDX3}_${scene_id}.mp4` (`render_mode=motion`)
3. **Signed URL** (`Expires=` in the future) on `horizontal_upscale_url` / `horizontal_video_url` (or vertical)
4. If the only URL is unsigned or `Expires=` is past → **do not curl it**. Refresh first (below).

Check orientation from project or first scene. Use matching prefix (`horizontal_` or `vertical_`).

### Step 2b: Refresh expired / unsigned URLs

If any scene still needs a file and its URL is unsigned or expired:

```bash
# Flow project tab must be open
curl -sS -X POST "http://127.0.0.1:8100/api/flow/refresh-urls/<PID>"
# Re-read scenes; only curl URLs that now contain Expires= and are in the future
curl -s "http://127.0.0.1:8100/api/scenes?video_id=<VID>"
```

If refresh returns `found: 0`, ask the user to reload the Flow Kit extension, open the project tab, scroll the board, then retry refresh. Do **not** tell them every URL is dead if the tab still plays the clips.

**ABORT** if any scene has no video source (no local file **and** no `*_video_url` / `*_upscale_url`). Tell the user to run `/fk-gen-videos` first.

A missing file under `output/.../4k/scene_*.mp4` is **not** a failed generation. Download it in Step 4. Do **not** treat “file missing or &lt; 1000 bytes” as “submit `GENERATE_VIDEO` again”.

**Do not** start video generation from `/fk-concat`. Do not write `/tmp/regen_batch.json`. Do not `python3 -c "..." > /tmp/*.json` (that mixes `print()` text with JSON and then `json.load` fails). Concat only downloads + merges clips that already exist.

## Step 3: Setup output directory

```bash
# Get project output directory (creates dir + meta.json if needed)
PROJ_OUT=$(curl -s http://127.0.0.1:8100/api/projects/<PID>/output-dir)
OUTDIR=$(echo "$PROJ_OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
SLUG=$(echo "$PROJ_OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['slug'])")
mkdir -p "${OUTDIR}/4k" "${OUTDIR}/narrated" "${OUTDIR}/norm"
```

## Step 4: Download videos (skip if local file exists)

```bash
# IDX3 = zero-padded 3-digit display_order (e.g. 000, 001, ...)
IDX3=$(printf "%03d" $DISPLAY_ORDER)
CANONICAL="${OUTDIR}/4k/scene_${IDX3}_${SCENE_ID}.mp4"
LEGACY="${OUTDIR}/4k/${SCENE_ID}.mp4"

# Skip / replace tiny 403 bodies
if [ -f "$CANONICAL" ] && [ "$(wc -c < "$CANONICAL")" -lt 10000 ]; then
  rm -f "$CANONICAL"
fi

if [ -f "$CANONICAL" ]; then
  : # already present, skip download
elif [ -f "$LEGACY" ] && [ "$(wc -c < "$LEGACY")" -gt 10000 ]; then
  cp "$LEGACY" "$CANONICAL"
else
  # Only signed URLs (must contain Expires=)
  curl -L --fail -o "$CANONICAL" "${SIGNED_VIDEO_URL}"
fi
```

After each download: `ffprobe` must show a video stream. If it fails, delete the file (it is probably a 403 HTML/XML body).

## Step 5: Determine output resolution

- If `--4k` flag: use `3840:2160` (HORIZONTAL) or `2160:3840` (VERTICAL)
- Otherwise: match source resolution from first downloaded scene via ffprobe

**IMPORTANT: Never downscale 4K videos. If source is 3840x2160, output must be 3840x2160.**

## Step 6: Normalize + mix audio

### Option A: Without TTS (default)
Preserve original video audio (sound effects from Google Flow):
```bash
# CANONICAL = "${OUTDIR}/4k/scene_${IDX3}_${SCENE_ID}.mp4" (set in Step 4)
ffmpeg -y -i "$CANONICAL" \
  -c:v libx264 -preset fast -crf 18 \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2" \
  -r 24 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  -movflags +faststart "${OUTDIR}/norm/scene_${IDX3}_${SCENE_ID}.mp4"
```

### Option B: With TTS narration (`--with-tts`)
Mix TTS audio WITH video sound effects using `amix` filter:

```bash
# Find matching TTS wav
TTS_WAV="${OUTDIR}/tts/scene_${IDX3}_${SCENE_ID}.wav"

if [ -f "$TTS_WAV" ]; then
  # MIX: video SFX at 30% volume + TTS narrator at 150% volume
  ffmpeg -y -i "$CANONICAL" -i "$TTS_WAV" \
    -filter_complex "[0:a]volume=0.3[bg];[1:a]volume=1.5[fg];[bg][fg]amix=inputs=2:duration=first[aout]" \
    -map 0:v -map "[aout]" \
    -c:v libx264 -preset fast -crf 18 \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2" \
    -r 24 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -movflags +faststart "${OUTDIR}/narrated/scene_${IDX3}_${SCENE_ID}.mp4"
else
  # No TTS for this scene — normalize with original audio only
  ffmpeg -y -i "$CANONICAL" \
    -c:v libx264 -preset fast -crf 18 \
    -vf "scale=${W}:${H}" -r 24 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -movflags +faststart "${OUTDIR}/narrated/scene_${IDX3}_${SCENE_ID}.mp4"
fi
```

**CRITICAL: Do NOT use `-an` (strips all audio). Always preserve or mix audio.**

## Step 7: Create concat list and merge

```bash
# Use narrated/ if --with-tts, otherwise norm/
SRC_DIR="${OUTDIR}/narrated"  # or "${OUTDIR}/norm"

> concat.txt
# scenes array must be sorted by display_order; each entry has display_order and id
for scene in "${SCENES[@]}"; do
  IDX3=$(printf "%03d" "${scene[display_order]}")
  SCENE_ID="${scene[id]}"
  CANONICAL_NORM="${SRC_DIR}/scene_${IDX3}_${SCENE_ID}.mp4"
  # Fallback to legacy 2-digit name if canonical not found
  LEGACY_NORM="${SRC_DIR}/scene_$(printf "%02d" ${scene[display_order]}).mp4"
  if [ -f "$CANONICAL_NORM" ]; then
    echo "file '$CANONICAL_NORM'" >> concat.txt
  elif [ -f "$LEGACY_NORM" ]; then
    echo "file '$LEGACY_NORM'" >> concat.txt
  else
    echo "ERROR: missing normalized file for scene ${IDX3}_${SCENE_ID}" >&2
    exit 1
  fi
done

ffmpeg -y -f concat -safe 0 -i concat.txt -c copy -movflags +faststart \
  "${OUTDIR}/${SLUG}_final.mp4"
```

## Step 8: Verify and output

```bash
# Verify final video
ffprobe -v quiet -show_entries stream=width,height,codec_name,codec_type -of csv=p=0 "${OUTDIR}/${SLUG}_final.mp4"
ls -lh "${OUTDIR}/${SLUG}_final.mp4"
ffprobe -v quiet -show_entries format=duration -of csv=p=0 "${OUTDIR}/${SLUG}_final.mp4"

# Verify audio is present (not silent)
ffmpeg -t 10 -i "${OUTDIR}/${SLUG}_final.mp4" -af "volumedetect" -f null /dev/null 2>&1 | grep "mean_volume"
# mean_volume should be between -30 and -10 dB (not -inf which means silent)
```

Print:
```
Concat complete: <project_name>
  Output: ${OUTDIR}/${SLUG}_final.mp4
  Duration: X:XX
  Resolution: WxH
  Audio: AAC (SFX + TTS narrator) or AAC (SFX only)
  Size: XXX MB
  Scenes: N
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| No audio in final | Used `-an` in normalize step | Remove `-an`, use `-c:a aac` |
| TTS not audible | TTS wav not mixed, only video audio used | Use `amix` filter with `-filter_complex` |
| Video is 1080p not 4K | Normalize used wrong scale | Match source resolution, never downscale |
| Signed URL expired | GCS URLs have ~8h TTL | Check local `${OUTDIR}/4k/` files first |
| `curl` 403 on `flow-content.google` | URL is unsigned (`/video/<uuid>` only) or `Expires=` is in the past. The Flow **tab** still plays because the page fetches a new signed URL with cookies | Do not regenerate. Use a local file if size &gt; 10KB. Open the Flow project tab, `POST /api/flow/refresh-urls/<PID>`, then download. Never treat a 111–400 byte "mp4" (XML/HTML 403 body) as a clip |
| Scene order wrong | Not sorted by display_order | Sort scenes before processing |
| `json.load('/tmp/regen_batch.json')` / `JSONDecodeError` | Script printed `Pending: N` then JSON into the same file, or used `echo`/`\"` inside `python3 -c` | Not part of this skill. Abort concat. Download missing files from scene URLs. Run `/fk-gen-videos` only if the scene has no URL and no COMPLETED request |
| `SyntaxError: unexpected character after line continuation` in `python3 -c` | Nested `\"` inside a single-quoted `-c` string (`open(\"/tmp/...\")`) | Do not nest `python3 -c` inside `echo $(...)`. Use `json.dump` only, or skip the temp file |
| Missing `output/.../4k/*.mp4` | File never downloaded | Step 4 `curl` the scene URL. Do not `GENERATE_VIDEO` |
