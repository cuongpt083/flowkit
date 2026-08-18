Generate videos for all scenes in a video.

Usage: `/fk-gen-videos <project_id> <video_id>`

## Step 0: Detect orientation

```bash
PROJ_OUT=$(curl -s http://127.0.0.1:8100/api/projects/<PID>/output-dir)
OUTDIR=$(echo "$PROJ_OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
ORI=$(cat ${OUTDIR}/meta.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('orientation','HORIZONTAL'))")
ori=$(echo "$ORI" | tr '[:upper:]' '[:lower:]')
```
**NEVER hardcode VERTICAL or HORIZONTAL.** Use `${ORI}` for API params, `${ori}_*` for DB field lookups.

## Step 0b: Lite Continuity

If `GET /api/models` uses `veo_3_1_i2v_lite` or `veo_3_1_i2v_lite_low_priority`, read `skills/lite-continuity.md`.

Before the video batch:
1. **Never** submit `GENERATE_VIDEO_REFS` / r2v.
2. Build the child map (`parent_scene_id` → child). For each scene that has a child **in the same location / same CONTINUATION chain**, PATCH `${ori}_end_scene_media_id` to the **child's** `${ori}_image_media_id` (see `/fk-gen-chain-videos`). Chain tail and standalone ROOT: leave endImage null.
3. Then submit `GENERATE_VIDEO` as below (worker uses start+end when end id is set).

Wrong end id (parent image) makes the cut harder, not smoother.

## Step 1: Pre-check — all scene images must be ready

```bash
curl -s "http://127.0.0.1:8100/api/scenes?video_id=<VID>"
```

**ABORT** if any scene is missing `${ori}_image_media_id` or `${ori}_image_status` != `"COMPLETED"`. Tell user to run `/fk-gen-images` first.

If `GET /api/projects/<PID>` has `"render_mode": "motion"`, still submit `GENERATE_VIDEO` the same way. The server turns each still into a Ken Burns clip locally (no Flow/Veo cost). Scene image **URL** must be present (`${ori}_image_url`). Do not require UUID `media_id` for motion. After success, continue with `/fk-concat` or `/fk-concat-fit-narrator` as usual.

## Step 2: Filter scenes needing video

Only scenes where `${ori}_video_status` != `"COMPLETED"` **and** there is not already an in-flight request.

```bash
curl -s "http://127.0.0.1:8100/api/requests?video_id=<VID>"
```

**Do not submit** `GENERATE_VIDEO` for a `scene_id` if any existing request of type `GENERATE_VIDEO` / `REGENERATE_VIDEO` / `GENERATE_VIDEO_REFS` is `PENDING` or `PROCESSING`.

- `PROCESSING` or `PENDING` **with** `request_id` or `media_id` → worker is polling Flow. Wait. Poll `/batch-status` every 180s.
- `PENDING` with `request_id` null **and** another row for the same scene is `PROCESSING` → that PENDING is a **duplicate**. Do not add a third. Do not restart the agent.
- Scene `video_status=PENDING` while a request is `PROCESSING` is normal (scene updates only on COMPLETED).

## Step 3: Submit ALL remaining requests at once

The server handles throttling automatically (max 5 concurrent, 10s cooldown). Submit only scenes that passed Step 2. Veo Low Priority clips commonly take **15–30 minutes** per scene.

```bash
curl -X POST http://127.0.0.1:8100/api/requests/batch \
  -H "Content-Type: application/json" \
  -d '{
    "requests": [
      {"type": "GENERATE_VIDEO", "scene_id": "<SID1>", "project_id": "<PID>", "video_id": "<VID>", "orientation": "${ORI}"},
      {"type": "GENERATE_VIDEO", "scene_id": "<SID2>", "project_id": "<PID>", "video_id": "<VID>", "orientation": "${ORI}"}
    ]
  }'
```

Build the `requests` array from ALL scenes filtered in Step 2. Do NOT manually batch or loop.

**Do not** decide “needs GENERATE_VIDEO” from a missing `output/.../4k/scene_*.mp4`. That file is created at concat/download time. A COMPLETED scene with a URL only needs download.

**Do not** write `/tmp/regen_batch.json` by redirecting a script that also `print`s diagnostics. If you POST a batch, pipe **only** JSON:

```bash
python3 -c '
import json, sys
reqs = [...]  # from Step 2 only
json.dump({"requests": reqs}, sys.stdout)
' | curl -sS -X POST http://127.0.0.1:8100/api/requests/batch \
  -H "Content-Type: application/json" --data-binary @-
```

Never: `print(...); print(json.dumps(...)) > /tmp/foo.json`  
Never: `echo "$(python3 -c 'print(len(json.load(open(\"/tmp/foo.json\"))))')"`

Poll aggregate status every **180 seconds (3 minutes)** until done. Do **not** poll more often — each `curl` costs LLM tokens and videos take 15–30 minutes.

```bash
sleep 180
curl -s "http://127.0.0.1:8100/api/requests/batch-status?video_id=<VID>&type=GENERATE_VIDEO"
# Wait for: "done": true
# If "all_succeeded": false → some failed, check individual failures
```

## Step 4: Verify

```bash
curl -s "http://127.0.0.1:8100/api/scenes?video_id=<VID>" | python3 -c "
import sys, json
from collections import Counter
scenes = json.load(sys.stdin)
print('Scene video statuses:', Counter(s.get('${ori}_video_status') for s in scenes))
for s in sorted(scenes, key=lambda x: x.get('display_order') or 0):
    mid = s.get('${ori}_video_media_id') or ''
    print(f\"  Scene {s.get('display_order')}: {s.get('${ori}_video_status')} mid={mid[:16]}\")
"
```

`*_media_id` and `*_url` may be JSON `null`. Always use `(s.get('…') or '')[:n]` — never `s.get('…', '')[:n]`.

## Step 5: Output

Print results table:
| Scene | Order | video_status | video_media_id | video_url |
|-------|-------|-------------|---------------|-----------|

Print: "All videos ready. Run /fk-concat <VID> to download and merge (trim + xfade + loudnorm)."
If Lite: remind TTS default — `/fk-gen-narrator` then `/fk-concat --with-tts` when `audio_mode=tts`.

## Important rules

- **GENERATE vs REGENERATE:** `GENERATE_VIDEO` skips scenes already `COMPLETED`. To force-regenerate, reset `${ori}_video_status` to `PENDING` first, then submit. Never create a second request while one is still PENDING/PROCESSING.
- **UNUSUAL_ACTIVITY / TOO_MUCH_TRAFFIC:** stop new `GENERATE_VIDEO` submits. Wait at least 15 minutes. Do not restart the agent to force pickup. Job rows already submitted (`request_id` set) may still complete.
- **PENDING ≠ worker dead:** if `/health` shows `extension_connected: true` and any video request is `PROCESSING`, the worker is running. Extra PENDING rows without `request_id` are waiting for a free slot or a traffic hold.
- **Cascade on regen:** Regenerating a video auto-clears the upscale status for that scene.
- **Chain video prompt rule (CRITICAL):** Chain scenes with children use `transition_prompt` for video generation, NOT `video_prompt`. This is because the video transitions from the current scene's image to the child scene's image. When fixing chain scene videos, always update `transition_prompt`. `video_prompt` is only used for ROOT scenes or leaf scenes (no children).
- **Chain cascade (CRITICAL):** When regenerating a scene that has CONTINUATION children, you MUST also regenerate images + videos for all descendants in the chain. The child's image was EDIT_IMAGE'd from the parent's old image — if the parent's video changes, the child's start frame won't match the parent's end frame.
  - Walk the full chain to the leaf: `parent_scene_id` links form the chain
  - Regen child images **sequentially** (each child depends on parent completing first)
  - **Update `end_scene_media_id`**: After each child image regen completes, PATCH parent's `${ori}_end_scene_media_id` = child's new `${ori}_image_media_id`. This is CRITICAL — without it, video gen uses stale end frame and the video won't transition to the child's image.
  - After all images complete + end_scene_media_ids updated, regen the **parent video too** (so its end frame matches child's new start image)
  - Then batch regen videos for all children (parent + children can be parallel)
  - **Always proactively propose this cascade to the user** — don't wait for them to notice the mismatch
