"""Every executable fk-* skill has a PowerShell twin (or is policy-only)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
PS = ROOT / "scripts" / "ps"

POLICY_ONLY = {
    "research",
    "story-telling-design",
    "camera-guide",
    "thumbnail-guide",
    "creative-mix",
    "youtube-seo",
}

# Shipped twins (PR2–PR6).
PR2_TWINS = {
    "create-project",
    "gen-refs",
    "gen-images",
    "gen-videos",
    "gen-chain-videos",
    "status",
    "switch-project",
    "refresh-urls",
    "insert-scene",
    "fix-uuids",
    "concat",
    "concat-fit-narrator",
    "brand-logo",
    "thumbnail",
    "pipeline",
    "monitor",
    "change-model",
    "change-provider",
    "add-material",
    "doctor",
    "upload-image",
    "review-video",
    "render-motion",
    "gen-music",
    "gen-tts-template",
    "import-voice",
    "gen-narrator",
    "gen-text-overlays",
    "review-board",
    "youtube-upload",
    "dashboard",
}


def test_every_fk_skill_is_twin_or_policy_only():
    names = {p.stem[len("fk-") :] for p in SKILLS.glob("fk-*.md")}
    unknown = names - PR2_TWINS - POLICY_ONLY
    assert not unknown, f"skills missing twin or allowlist: {sorted(unknown)}"
    extra = POLICY_ONLY - names
    assert not extra, f"allowlist names not on disk: {sorted(extra)}"


def test_pr2_http_twins_exist():
    for name in sorted(PR2_TWINS):
        path = PS / f"fk-{name}.ps1"
        assert path.is_file(), f"missing PowerShell twin: {path}"
        text = path.read_text(encoding="utf-8")
        assert "FkCommon.psm1" in text
        assert "curl -" not in text


def test_pr2_skills_have_windows_routing():
    for name in sorted(PR2_TWINS):
        md = SKILLS / f"fk-{name}.md"
        text = md.read_text(encoding="utf-8")
        assert "## Windows (PowerShell)" in text, f"{md.name} missing Windows section"
        assert f"fk-{name}.ps1" in text
