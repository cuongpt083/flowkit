# fk-render-motion — Vox-style Ken Burns from scene stills

Render editorial explainer clips locally with ffmpeg. **No Veo / no paid video API.**

Usage: `/fk-render-motion` (or set `render_mode` then `/fk-gen-videos`)

The Vox look is born in the **still**. Motion only adds one slow camera move. If the image is photoreal cinematic, the clip will look like a slideshow — use material `vox_collage`.

## When to use

Documentary explainers, talking-points, cheap UAT. Not live-action character acting.

Do **not** run `/fk-gen-chain-videos`, upscale, or `GENERATE_VIDEO_REFS`.

## Recipe

```
material vox_collage + render_mode=motion
  → /fk-gen-refs → /fk-gen-images   (posters: layered cut-outs, one flat color, short headline)
  → /fk-gen-videos                  (Ken Burns: push_in / pull_out / pan / hold)
  → /fk-gen-narrator + overlays
  → /fk-concat-fit-narrator
```

Prefer `/fk-story-telling-design` first. Duration of each clip follows TTS (3–8s), not a hard 8s Veo slot.

## Step 1 — Project flags

```bash
curl -s http://127.0.0.1:8100/api/projects/<PID>
```

If needed:

```bash
curl -s -X PATCH http://127.0.0.1:8100/api/projects/<PID> \
  -H "Content-Type: application/json" \
  -d '{"render_mode":"motion","material":"vox_collage"}'
```

Use `vox_collage` unless the user picked another print style on purpose. `realistic` + motion is a Ken Burns slideshow, not Vox.

## Step 2 — Stills must be collage posters

Each scene `prompt` (after `scene_prefix`) should describe **separate paper cut-outs**, one bold flat background color, and an optional 2–3 word headline in quotes baked into the image. Real people: photographic sticker, do not redraw the face.

Images must be `COMPLETED` with a usable `${ori}_image_url`.

## Step 3 — Render clips

```bash
# same batch as cinematic — worker branches to Ken Burns
# POST GENERATE_VIDEO for scenes missing motion video
```

Follow `/fk-gen-videos` batch + no-duplicate rules. Worker:

- Downloads the still
- Picks **one** move: `push_in`, `pull_out`, `pan_right` / `pan_left`, `hold` (from prompt + first/last beat)
- Length = TTS wav + 0.5s, else narrator word estimate, else `duration`, clamped 3–8s
- Zoom ≤ 1.08; y biased to keep top headlines in frame
- Writes `output/<slug>/motion/scene_NNN_<id>.mp4` and copies to `4k/`

## Step 4 — Voice, type, concat

`/fk-gen-narrator` then `/fk-gen-text-overlays` then `/fk-concat-fit-narrator`.  
Do not ask Veo to speak. Burn captions in concat, not in the Ken Burns pass.

## Motion map

| Cue | Move |
|-----|------|
| First scene / default hook | `push_in` |
| wide / establishing / map | `pan_right` or `pan_left` |
| close-up / headline / stat / face | `hold` |
| Last scene / ending / commitment | `pull_out` |

One move per clip. No punch-in, snap zoom, or multi-cut inside 8s.

## Next

Print: motion clips path + duration/preset if logged. Then narrator → concat.
