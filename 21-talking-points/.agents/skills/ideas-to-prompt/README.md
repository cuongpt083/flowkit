# ideas-to-prompt

Standalone skill. Not part of Flow Kit. Move this whole folder out of the
repo — nothing else in the codebase references it.

Turns raw text (article, notes, idea) into a lookbook + per-scene prompts
for Google Flow and Flux 3 (bfl.ai). No local API. User generates clips
in those websites and concatenates by hand.

## Use it

After moving the folder, drop it where your agent loads skills:

| Harness | Path |
|---------|------|
| Grok CLI | `<repo>/.grok/skills/ideas-to-prompt/SKILL.md` or `~/.grok/skills/ideas-to-prompt/` |
| OpenCode | `.opencode/skills/ideas-to-prompt/SKILL.md` |
| Claude Code | `.claude/skills/ideas-to-prompt/SKILL.md` |

Keep the directory name `ideas-to-prompt` and the file name `SKILL.md`.

Then: `/ideas-to-prompt path/to/notes.md`

Output defaults to `ideas-to-prompt/output/<slug>_prompts.md` (created on
first run). If you have already moved the skill, the agent writes next to
the source file or asks.
