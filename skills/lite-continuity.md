# Lite Continuity Profile

Canonical rules when the **active video model** is Veo 3.1 Lite (`veo_3_1_i2v_lite` or `veo_3_1_i2v_lite_low_priority`).

Detect Lite:

```bash
curl -s http://127.0.0.1:8100/api/models
# Lite if any TIER_TWO frame_2_video / start_end key contains "i2v_lite"
```

Other skills **must** follow this file instead of Ultra/r2v assumptions.

## Why

Lite does not hold face, room, or speaker across 8s clips. Continuity comes from **refs + images + TTS + concat trim/xfade**, not from the video model.

## Defaults

| Setting | Lite default |
|---------|----------------|
| `audio_mode` | `tts` — one narrator voice; Veo must not speak |
| Video chain | CONTINUATION + same location → set `end_scene_media_id` to **child** image |
| Hard cut | ROOT, location change, time skip |
| Max CONTINUATION depth | **8** shots, then a new ROOT using the same refs (reset drift) |
| Concat | Trim 0.4s head/tail, `xfade=0.4` + `acrossfade` inside a chain, hard cut between ROOT segments, `loudnorm` |
| r2v | **Forbidden** (`GENERATE_VIDEO_REFS` / T3 creative-mix) |

`audio_mode=veo` or `hybrid` only if the user overrides. Do not mix Veo speech and TTS in one concat without asking.

## Detect `audio_mode`

1. User said `tts` / `veo` / `hybrid` at project create, or
2. Default `tts` whenever the video model is Lite.

Store the choice in the project `description` or story first line as `audio_mode: tts` so later skills can read it. If missing and model is Lite, assume `tts`.

## Create-project rules

- Ask `audio_mode` when model is Lite (default tts).
- One outfit per character. Do not encode wardrobe changes in the entity description.
- Split beats: new ROOT on room change, time jump, or emotional reset. Never one 40-shot CONTINUATION.
- After 8 CONTINUATION children, next scene is ROOT (same location/refs allowed).
- When `audio_mode=tts`:
  - `video_prompt`: no `says:` / `asks:` / `murmurs:` / spoken lines.
  - One camera move (hold or slow push). No “then cut to” multi-shot inside 8s.
  - Audio line: room tone + SFX only.
  - Negative includes: `dialogue, speech, talking, subtitles, watermark, text overlay`.
  - Put speech in `narrator_text` (project language). `voice_description` is for the TTS template, not Veo.
- `transition_prompt` only if the scene has a same-room child. Describe motion from this frame to the child’s frame.

## Image rules

- Do not regenerate a locked character ref mid-project unless review failed that ref.
- CONTINUATION = `EDIT_IMAGE` from parent. Shot 9+ in the same room = ROOT from **entity refs**, not from a drifted parent still.
- Review stills (board) before `/fk-gen-videos`. Drifted stills must not get video.

## Video rules

| Scene | Action |
|-------|--------|
| CONTINUATION, same location as parent, child image COMPLETED | PATCH `${ori}_end_scene_media_id` = **child** `${ori}_image_media_id`, then `GENERATE_VIDEO` (worker uses start+end) |
| ROOT / new location / time skip / reaction insert | Leave endImage null; plain i2v |
| Any Lite project | Never `GENERATE_VIDEO_REFS` |

Follow `fk-gen-chain-videos.md` for the child-map / end-id wiring. Do not point `end_scene_media_id` at the parent image.

After setting end ids, submit **one** `GENERATE_VIDEO` batch (same as `/fk-gen-videos`). Do not duplicate in-flight rows.

## Review extras (Lite)

Fail or flag:

- Face / outfit ≠ ref
- Room / lighting ≠ parent still
- Veo speech while `audio_mode=tts`
- ≥0.4s freeze at head or tail (suggest `trim_start` / `trim_end`)
- Ugly face morph on start+end clips

## Concat (runtime)

See `/fk-concat` Steps 6–7. Constants:

- `TRIM_HEAD=0.4` `TRIM_TAIL=0.4` (or scene `trim_start` / `trim_end` if set)
- `XFADE_DUR=0.4`
- `loudnorm=I=-16:TP=-1.5:LRA=11`
- Chain segment = consecutive `CONTINUATION` after a ROOT
- Do not xfade two ROOT cuts (different rooms)
- If `audio_mode=tts` and `--with-tts` but a scene has no WAV: ask or abort — do not concat Veo speech next to TTS
- Optional `output/<slug>/music.wav`: mix under speech (`volume=0.18`) after loudnorm

## Pipeline

When Lite:

- Stage VIDEOS: wire end ids for same-room CONTINUATION **before** the video batch
- Never queue r2v
- `--concat` uses `/fk-concat` trim/xfade/loudnorm (not raw `concat -c copy` only)
- Prefer `--tts` + one template; if `audio_mode=tts` and no template, pause for `/fk-gen-tts-template` or `/fk-import-voice`

## Forbidden

- Switching to Ultra/leaving to “fix continuity” unless the user changes model
- One EDIT chain longer than 8 without a ROOT reset
- r2v “for richness”
- Crossfading two different locations
