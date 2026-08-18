Download and concatenate all scene videos into a single video with optional TTS narration.

Usage: `/fk-concat <video_id> [--with-tts] [--4k] [--hard-cut]`

Default: uses best available quality (4K upscale > regular video), preserves original audio.

**Continuity (always on unless `--hard-cut`):** trim 0.4s off head and tail of each clip, `xfade=0.4` + `acrossfade` inside a CONTINUATION chain, hard cut between ROOT segments, then `loudnorm`. Lite policy: `skills/lite-continuity.md`. Do not `ffmpeg concat -c copy` raw 8s clips — that is what makes cuts feel spliced.

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

## Step 6: Trim + normalize + mix audio

Constants (override per scene if `trim_start` / `trim_end` exist on the scene object):

```
TRIM_HEAD=0.4
TRIM_TAIL=0.4
```

`--hard-cut`: set both trims to `0`.

Probe duration first. If `VIDEO_DUR <= TRIM_HEAD + TRIM_TAIL + 0.5`, skip trim (clip too short).

```bash
KEEP=$(python3 -c "print(max(0.5, ${VIDEO_DUR} - ${TRIM_HEAD} - ${TRIM_TAIL}))")
```

### Option A: Without TTS (default)

```bash
ffmpeg -y -ss ${TRIM_HEAD} -i "$CANONICAL" -t ${KEEP} \
  -c:v libx264 -preset fast -crf 18 \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2" \
  -r 24 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart "${OUTDIR}/norm/scene_${IDX3}_${SCENE_ID}.mp4"
```

### Option B: With TTS (`--with-tts`)

Lite default `audio_mode=tts`. If a scene is missing `${OUTDIR}/tts/scene_${IDX3}_${SCENE_ID}.wav`, **ask or abort** — do not mix Veo speech next to TTS.

```bash
TTS_WAV="${OUTDIR}/tts/scene_${IDX3}_${SCENE_ID}.wav"

ffmpeg -y -ss ${TRIM_HEAD} -i "$CANONICAL" -i "$TTS_WAV" -t ${KEEP} \
  -filter_complex "[0:a]volume=0.3[bg];[1:a]volume=1.5[fg];[bg][fg]amix=inputs=2:duration=first[aout]" \
  -map 0:v -map "[aout]" \
  -c:v libx264 -preset fast -crf 18 \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2" \
  -r 24 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart "${OUTDIR}/narrated/scene_${IDX3}_${SCENE_ID}.mp4"
```

`-ss` before `-i` on the **video** only (skips Lite freeze / overlap frames). TTS starts at 0.

**CRITICAL: Do NOT use `-an`. Always preserve or mix audio.**
**CRITICAL: Always `-ar 48000 -ac 2`.**

## Step 7: Chain xfade + loudnorm + merge

`SRC_DIR` = `narrated/` if `--with-tts`, else `norm/`.

### 7a. Group by chain

```python
segments = []
current = []
for scene in sorted_scenes:
    path = f"{SRC_DIR}/scene_{scene['display_order']:03d}_{scene['id']}.mp4"
    if scene.get('chain_type') == 'CONTINUATION' and current:
        current.append(path)
    else:
        if current:
            segments.append(current)
        current = [path]
if current:
    segments.append(current)
```

A ROOT starts a new segment. Consecutive CONTINUATION stay in the same segment.

### 7b. Single-scene segment

Copy/keep the trimmed file as that segment’s output.

### 7c. Multi-scene chain — xfade (skip if `--hard-cut`)

```
XFADE_DUR=0.4
```

Same filter pattern as `/fk-concat-fit-narrator` Step 7b: `xfade=transition=fade:duration=0.4` + `acrossfade=d=0.4`. Offset = cumulative duration − `XFADE_DUR`. Write `${OUTDIR}/norm/chain_${seg:03d}.mp4` (or `narrated/`).

Do **not** xfade two different locations (those are separate ROOT segments).

### 7d. loudnorm each segment

```bash
ffmpeg -y -i "$SEG" \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 \
  "${SEG%.mp4}_ln.mp4"
```

Use `*_ln.mp4` in the final list.

Optional bed: if `${OUTDIR}/music.wav` exists, mix under the **final** file at `volume=0.18` after concat (duck; do not replace speech).

### 7e. Final concat

```bash
> concat.txt
# one file= line per loudnorm'd segment
ffmpeg -y -f concat -safe 0 -i concat.txt -c copy -movflags +faststart \
  "${OUTDIR}/${SLUG}_final.mp4"
```

`--hard-cut`: skip 7c; concat loudnorm’d per-scene files in `display_order`.

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
  Audio: AAC (SFX + TTS narrator) or AAC (SFX only), loudnorm I=-16
  Size: XXX MB
  Scenes: N
  Continuity: trim 0.4/0.4, xfade 0.4 in-chain (or --hard-cut)
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
| Harsh / freeze at cuts | Raw `concat -c copy` of full 8s Lite clips | Do not skip trim + in-chain xfade |
| Face morph smear | xfade across a ROOT / new room | Hard cut at ROOT; only xfade CONTINUATION |
| TTS vs Veo speech clash | Mixed audio_mode | Abort missing WAV when `--with-tts` |
| `json.load('/tmp/regen_batch.json')` / `JSONDecodeError` | Script printed `Pending: N` then JSON into the same file, or used `echo`/`\"` inside `python3 -c` | Not part of this skill. Abort concat. Download missing files from scene URLs. Run `/fk-gen-videos` only if the scene has no URL and no COMPLETED request |
| `SyntaxError: unexpected character after line continuation` in `python3 -c` | Nested `\"` inside a single-quoted `-c` string (`open(\"/tmp/...\")`) | Do not nest `python3 -c` inside `echo $(...)`. Use `json.dump` only, or skip the temp file |
| Missing `output/.../4k/*.mp4` | File never downloaded | Step 4 `curl` the scene URL. Do not `GENERATE_VIDEO` |
