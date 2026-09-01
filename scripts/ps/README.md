# Flow Kit — PowerShell twins (Windows 10/11)

Windows executable counterparts for `/fk-*` skills. Canonical **policy** stays in `skills/fk-*.md`. These scripts are what an agent should **run** when the host shell is PowerShell.

## Requirements

- Windows 10 or 11
- **Windows PowerShell 5.1** (default) or PowerShell 7
- Python 3.10+ from [python.org](https://www.python.org/downloads/) (not the Microsoft Store stub under `WindowsApps`)
- `ffmpeg` / `ffprobe` on PATH (`winget install Gyan.FFmpeg`)
- Chrome + Flow Kit extension, agent at `http://127.0.0.1:8100`

## Setup

From the repo root in PowerShell:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\setup.ps1
.\venv\Scripts\Activate.ps1
python -m agent.main
```

## Module

Import from any twin script:

```powershell
Import-Module "$PSScriptRoot\FkCommon.psm1" -Force
```

Rules baked into `FkCommon.psm1`:

- **Never** call the `curl` alias (it is `Invoke-WebRequest` on Windows). Use `Invoke-FkApi` or `curl.exe`.
- Temp files go to `$env:TEMP\flowkit`, never `/tmp`.
- JSON uses `ConvertTo-Json -Depth 20` (PowerShell 5.1 defaults to depth 2).
- ffmpeg concat lists use forward slashes (`Write-FkConcatList`).
- Target **5.1**: no `&&`, `??`, `$IsWindows`, or PS7 ternary.

## Agent routing

On Windows PowerShell, after reading `skills/fk-<name>.md`, run:

```powershell
.\scripts\ps\fk-<name>.ps1
```

Do not translate the markdown ```bash``` blocks yourself.

## HTTP pipeline twins (PR2)

| Script | Skill |
|--------|--------|
| `fk-create-project.ps1` | `/fk-create-project` (`-JsonPath` / `-ListMaterials`) |
| `fk-gen-refs.ps1` | `/fk-gen-refs` |
| `fk-gen-images.ps1` | `/fk-gen-images` (ROOT then CONTINUATION waves) |
| `fk-gen-videos.ps1` | `/fk-gen-videos` (skip in-flight, poll 180s) |
| `fk-gen-chain-videos.ps1` | `/fk-gen-chain-videos` |
| `fk-status.ps1` | `/fk-status` |
| `fk-switch-project.ps1` | `/fk-switch-project` |
| `fk-refresh-urls.ps1` | `/fk-refresh-urls` |
| `fk-insert-scene.ps1` | `/fk-insert-scene` |
| `fk-fix-uuids.ps1` | `/fk-fix-uuids` |

ffmpeg twins (`fk-concat.ps1`, …) are a later PR. This folder always contains `FkCommon.psm1`.

## Tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ps\FkCommon.Tests.ps1
```
