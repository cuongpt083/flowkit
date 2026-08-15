---
name: ideas-to-prompt
description: >
  Turn raw, unstructured content (article, notes, idea, outline — not a film
  script) into a lookbook plus numbered scene prompts for Google Flow and
  Flux 3 (bfl.ai). User pastes prompts into those tools, generates clips,
  then concatenates manually. Use when the user says /ideas-to-prompt, wants
  scene prompts from an idea, or needs Flow/Flux-ready video prompts without
  calling any local API.
---

# ideas-to-prompt

Convert raw content into a **lookbook** + **one prompt per scene**. Do not
call Flow Kit, localhost APIs, or write generation scripts. Output is text
the user copies into Google Flow or Flux 3 (https://bfl.ai).

## Usage

```
/ideas-to-prompt <path-or-paste> [--tool flow|flux|both] [--orientation vertical|horizontal] [--style <material>] [--duration <seconds>]
```

| Flag | Default | Notes |
|------|---------|--------|
| `--tool` | `both` | `flow` = 8s clips; `flux` = 8–12s (Flux 3 can go to ~20s — stay conservative); `both` writes one shared prompt + length note |
| `--orientation` | ask if missing | `vertical` (9:16) or `horizontal` (16:9) |
| `--style` | infer from content, then confirm | One locked look for the whole film (e.g. `realistic`, `3d_pixar`, `anime`, `documentary`, `oil_painting`) |
| `--duration` | infer from content | Target runtime. Scene count = ceil(duration / clip_length) |

If the user pastes text with no path, treat the message as the source. If a
path is given, read that file. If both style and orientation are missing,
ask once, then proceed.

## Hard rules

1. **Do not generate media.** Only write prompts.
2. **English prompts only** — even if the source is Vietnamese. Keep a
   Vietnamese logline in the header for the user.
3. **Lock the look once, then repeat it.** There are no reference-image IDs
   here. Every scene prompt must restate the same character/location tokens
   from the lookbook (exact wording). Drift = new face.
4. **One outfit per character** in the lookbook. Wardrobe changes belong in
   the scene action line, not a second character.
5. **One visual moment per scene.** If a paragraph has three events, split
   into three scenes.
6. **Max 2–3 shots per clip.** Camera movement is its **own sentence**.
7. **Always include lighting + audio + negative.**
8. **Safe language.** Do not use: kill, dead, blood, gore, explode, bomb,
   massacre, corpse, torture, child/kid/baby in visual prompts. Prefer
   atmosphere: aftermath, debris, tense, resolute.
9. **Real public figures.** Never put the real name in any prompt. Use an
   English role alias + physical description. Prefer back or three-quarter
   profile for famous faces. Narrator/logline may use real names.
10. **Face framing.** If a character is on screen, show a full face
    (front / 3/4 / profile) or a deliberate POV with no face. Never crop
    through the eyes.

## Clip length

| Tool | Length per scene | Shots |
|------|------------------|-------|
| Google Flow (Veo) | 8 seconds | 2–3 |
| Flux 3 | 8–12 seconds (note if user wants longer, max 20) | 2–3 |

Default when `--tool both`: write **8-second** prompts. Add a one-line
`Flux longer take` only when the beat clearly needs it.

## Workflow

### 1. Read and classify

Extract: topic, emotional arc, must-keep facts, people, places, objects.
Drop anything that cannot be shown in a single 8s shot.

If the source is documentary / news, do not invent events, dates, or
operation names. Unverified claims go in `Uncertain` — do not put them on
screen.

### 2. Lookbook (write this first)

Table of recurring visual elements. Appearance only — no biography.

| Name (alias) | Type | Locked look (copy-paste token) |
|--------------|------|--------------------------------|
| ... | character / location / prop | 1–2 sentences: hair, build, clothing, materials, palette |

**Locked look token** = the exact phrase that must appear in every scene
where that element is visible.

Also lock a **style line** used in every prompt, e.g.:

```
Photoreal documentary, 35mm, natural color, overcast northern light.
```

Cap: ≤ 6 characters, ≤ 6 locations, ≤ 6 props. Merge extras.

### 3. Beat sheet

Split the source into ordered beats. Each beat = one scene.

- Opening: wide establish
- Middle: cause → reaction → consequence
- Close: image that can end the film

Flag chain vs hard cut:

- **CHAIN** — same character + same/adjacent space, next 8 seconds
- **CUT** — new person, new place, time skip, interview

If two threads intercut (A fleeing / B chasing), keep two chains and
interleave by order. Do not morph A into B in one continuous prompt.

### 4. Write each scene

For every beat, output:

1. `start_frame` — still-image prompt (first frame). Users can generate
   this in Flow or Flux, then image-to-video.
2. `video_prompt` — motion prompt (the one they paste for video).

**start_frame formula**

```
[Locked style line]. [Shot type] of [locked character token] [action verb]
[in locked location token]. [One concrete visual detail]. [Camera/composition].
[Lighting]. Full face visible. Negative: subtitles, watermark, text overlay,
logo, extra fingers, cropped face.
```

**video_prompt formula** (100–150 words, 3–6 sentences)

```
[Shot type] of [locked character token] [action] [in locked location token].
The camera [one movement]. [Lighting + time of day]. Then cut to [second shot,
same locked tokens]. [Optional short dialogue.]

Audio: [ambience].
SFX: [2–3 concrete sounds].
Negative: subtitles, captions, watermark, text overlay, logo, blurry faces,
distorted hands.
```

Dialogue: `Name says: "≤ 8 words." (no subtitles)`. Not every scene needs
speech. Silent + SFX is valid.

Do **not** write appearance adjectives outside the locked token. Do **not**
use empty words alone: cinematic, epic, dramatic.

### 5. Save and summarize

Write the full pack to:

```
ideas-to-prompt/output/<slug>_prompts.md
```

If that folder is not writable (skill has been moved), write next to the
source file or ask where to save.

Print a short table to the user:

| # | Timecode | CUT/CHAIN | One-line action | Entities |
|---|----------|-----------|-----------------|----------|

Then: scene count, estimated runtime, output path, and how to use it
(below). Do not create a Flow Kit project.

## Output file shape

```markdown
# <Title>
Logline (source language): ...
Style: ...
Orientation: VERTICAL | HORIZONTAL
Tool: flow | flux | both
Clip length: 8s
Estimated runtime: Ns (M scenes)

## Lookbook
| Name | Type | Locked look |
|------|------|-------------|

## Style line
<one sentence copied into every prompt>

## Scenes

### Scene 01 — <short title>
- timecode: 00:00–00:08
- join: CUT | CHAIN ← Scene 00
- entities: Name, Place
- note: (optional — famous-person angle, skip if unsafe, etc.)

**start_frame**
```
...
```

**video_prompt**
```
...
```
```

## How the user uses the pack

1. Generate each `start_frame` in Flow or Flux. Reuse the same character
   stills as references if the tool allows image inputs.
2. Generate each `video_prompt` as text-to-video, or image-to-video from
   that scene's start frame.
3. Download clips in order. Concatenate in any editor (CapCut, Premiere,
   ffmpeg). Hard cuts are expected; CHAIN scenes may also use start/end
   frame if the tool supports it.

## Quality check (every scene)

- [ ] Locked tokens copied verbatim for every visible entity
- [ ] 100–150 words in `video_prompt`
- [ ] Camera movement is its own sentence
- [ ] Lighting + Audio + SFX + Negative present
- [ ] ≤ 3 shots; dialogue fits the clip
- [ ] No real celebrity names in prompts
- [ ] No blocked violence / minor language
- [ ] Face full or intentional POV

## Example (abridged)

Source: "A white cat astronaut lands on a candy planet, tastes a chocolate
river, plants a flag."

Lookbook token: `Luna, a small white cat with big blue eyes, tiny orange
space suit, round glass helmet, fluffy tail`

Scene 02 video_prompt:

```
Medium shot of Luna, a small white cat with big blue eyes, tiny orange
space suit, round glass helmet, fluffy tail, kneeling at a wide river of
dark melted chocolate with marshmallow rocks, pastel candy-planet shore.
The camera slowly dollies in. Warm golden hour light reflecting off the
chocolate. Then cut to close-up of her paw dipping in, slow-motion drip.
Luna says: "It is chocolate!" (no subtitles)

Audio: thick liquid current, warm breeze.
SFX: chocolate drip, soft gasp.
Negative: subtitles, captions, watermark, text overlay, logo, blurry faces,
distorted hands.
```
