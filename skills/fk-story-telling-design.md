# fk-story-telling-design — Design story structure before creating a Flow project

Design a compelling beat sheet using shared storytelling rules. Runs **before** `/fk-create-project`. Does **not** POST projects, write Veo prompts, or invent production specs.

Usage: `/fk-story-telling-design [topic or @file] [--mode education|short_film|documentary] [--skip-research]`

`--skip-research` only when the user **explicitly** says the piece is pure fiction and they accept no fact-check.

## Do not do

- `POST /api/projects` or create scenes
- Write `prompt` / `video_prompt` / camera language for Veo
- Silently change user claims to match research
- Use a 12-step hero journey on a 1–5 minute film

## Spine (every mode)

The beat sheet must answer:

1. Who must change (character or viewer)?
2. What do they want at the open?
3. Why can't they have it (obstacle / false belief / force)?
4. What is the **single** turn (one idea, not a list)?
5. What concrete action follows the turn?
6. What is different in the last shot?

If any answer is missing, the sheet is not ready.

### Pull rules

- Hook in the first 8–15 seconds: question, contradiction, or image that violates expectation. No channel greeting, no definition open.
- One spine. Supporting lists (5 tips, stats) sit **inside** the middle beats; they are not five stories.
- Each beat costs more than the last (emotion or consequence). Flat 1–2–3–4–5 lists fail.
- Concrete over abstract.
- Close on an action or commitment, not a slogan. A tagline may sit on the last frame; it does not replace the last beat.
- Duration sets beat count: ~60s → 3 beats; ~5 min → 4–6 beats.
- Ear and eye share one arc. TTS later narrates the spine; picture illustrates it.

### Mode skins (same 6 questions)

| Mode | Rhythm | The turn is |
|------|--------|-------------|
| `education` | Hook → false belief → cost → one principle → commitment | Flip one belief |
| `short_film` | Relationship → friction → confession → choice → closing gesture | One decision between people |
| `documentary` | Ground → person → escalating events → consequence → meaning | A **verified** fact (from research), never invented |

Pick mode from `--mode`, user wording, or ask once.

## Step 0 — Inputs

Collect:

- Topic, pasted notes, or `@file`
- Target duration and audience (ask if missing)
- Language of the beat sheet (same as the eventual film)

Do not ask material, orientation, or wardrobe here.

## Step 1 — Research gate (required)

`/fk-research` **must** have been run for this topic, unless `--skip-research` was given **in this turn**.

```
.omc/research/{topic_slug}_research.md
```

If the file is missing:

- Documentary / education / any real names, dates, stats, health claims → **ABORT**. Tell the user to run `/fk-research "<topic>"` first, then re-run this skill.
- User says the work is pure fiction **and** `--skip-research` → continue. Write `research: skipped (user fiction)` on the sheet.

If a research file exists, read it. Extra facts the user never claimed may be offered later as `[from research]` — the user may drop them. That is **not** a conflict.

## Step 2 — Conflict table (stop if any row)

A **conflict** is the same claim, two values: user input vs research (date, number, who did what, operation name, real person, causal claim).

If none: continue.

If any: **do not write the beat sheet yet**. Print:

```
| # | User said | Research (source) | Choose |
|---|-----------|-------------------|--------|
| 1 | …         | …                 | keep_user / use_research / rewrite |
```

Ask the user to pick **per row**. Do not continue until every row has a choice.

- `keep_user` → beat sheet follows the user. Put the research value under **Contradicted / unverified**. Never treat it as narrator fact.
- `use_research` → beat sheet uses the researched value. Note `resolved: use_research`.
- `rewrite` → user supplies the new wording; use that.

Never rewrite the user's content to match research without that choice.

## Step 3 — Draft the beat sheet

Write in the film language (Vietnamese if the film is Vietnamese).

```markdown
# Story: [working title]
**Mode:** education | short_film | documentary
**Duration:** ~Xm
**Audience:** …
**Language:** …
**Research:** .omc/research/… | skipped (user fiction)
**Conflicts:** none | see table (all resolved)

## Logline
One sentence.

## Spine answers
1. Who changes: …
2. Want at open: …
3. Obstacle: …
4. Turn: …
5. Action after turn: …
6. Last-shot difference: …

## Beats (4–6, or 3 if ≤60s)
### Beat 1 — [name]
- Emotion: …
- Who is on frame: …
- Key line (dialogue or narrator intent, not 8s-cut): …
- Source: user | research | resolved:keep_user | resolved:use_research

### Beat 2 — …
…

## Roles (story function only — no Flow wardrobe)
| Name | Function in the story |
|------|------------------------|
| …    | …                      |

## Places (story function)
| Place | Function |
|-------|----------|

## Line the viewer should remember
One sentence.

## Contradicted / unverified
- [research claim user rejected, or uncited leftover]
```

Reject the draft yourself if: no hook in beat 1, more than one spine, beats are a flat list, close is only a slogan, or a documentary turn is not in the research file (unless the user chose `keep_user` on that claim).

## Step 4 — Save draft

```
.omc/stories/{slug}_beats.md
```

Create `.omc/stories/` if needed. Front matter or first lines must include `status: draft`.

Show the full sheet. Ask:

```
Duyệt beat sheet này?
- "ok" / "đồng ý" → chốt và chạy /fk-create-project
- "sửa beat N: …" → PATCH file, vẫn draft, hỏi lại
- "đổi mode" → quay Step 3
```

Do **not** create a Flow project on this turn unless they approve.

## Step 5 — Approve → create-project

On explicit approval only:

1. Set `status: approved` in `.omc/stories/{slug}_beats.md`.
2. Tell the user the file is the story source of truth.
3. **Immediately** follow `skills/fk-create-project.md` in the same turn:
   - `story` ← logline + spine (short)
   - Characters / locations ← Roles / Places; **ask wardrobe and visual descriptions** (not in the beat sheet)
   - Still ask material, orientation, scene count, render mode, audio mode
   - Map beats → ROOT / CONTINUATION and 8s scenes **inside create-project**, not here
   - If Lite, also apply `skills/lite-continuity.md`

If they refuse or only want edits: stay on the draft file. Do not call create-project.

## Handoff contract for `/fk-create-project`

Create-project must **not** invent a new plot. It adapts the approved sheet:

| Beat field | Becomes |
|------------|---------|
| Logline + spine | `project.story` |
| Key lines | `narrator_text` and/or Veo dialogue **after** audio_mode is known |
| Roles / places | entity names; visuals asked now |
| Beat order | `display_order` groups; new ROOT on place change or every 8 CONTINUATION (Lite) |

## Pipeline

```
/fk-research                 ← required (unless explicit fiction skip)
    ↓
/fk-story-telling-design     ← this skill (conflict gate + beat sheet + approve)
    ↓
/fk-create-project           ← only after status: approved
    ↓
/fk-pipeline                 ← unchanged
```
