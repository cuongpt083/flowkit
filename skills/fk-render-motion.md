Render Vox-style / motion-graphic clips from scene stills (Ken Burns). No AI video API.

Usage: `/fk-render-motion` (or set `render_mode` then `/fk-gen-videos`)

## When to use

Cheap UAT, documentary slideshow, explainers. Not live-action character motion.

## Steps

1. Ensure the project has `"render_mode": "motion"`:

```bash
curl -s http://127.0.0.1:8100/api/projects/<PID>
# If render_mode is cinematic:
curl -s -X PATCH http://127.0.0.1:8100/api/projects/<PID> \
  -H "Content-Type: application/json" \
  -d '{"render_mode":"motion"}'
```

2. Scene images must be `COMPLETED` with a usable `${ori}_image_url`.

3. Run `/fk-gen-videos <PID> <VID>` — same batch API. Worker renders `output/<slug>/motion/scene_NNN_<id>.mp4`.

4. Optional: `/fk-gen-narrator`, `/fk-gen-text-overlays`, `/fk-concat-fit-narrator`.

Do not run upscale or `/fk-gen-chain-videos` in motion mode (unsupported). Chain stills still crossfade at concat time.
