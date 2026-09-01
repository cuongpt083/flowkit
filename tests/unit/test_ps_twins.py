"""PR2: HTTP pipeline skills must have a PowerShell twin."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
PS = ROOT / "scripts" / "ps"

# Shipped in PR2 + PR3.
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
}


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
