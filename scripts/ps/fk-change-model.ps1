# Twin of skills/fk-change-model.md
param(
    [ValidateSet('lite-lp', 'lite', 'leaving', 'ultra', '')][string]$Preset = '',
    [string]$PatchJson
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($Preset) {
    $body = $null
    if ($Preset -eq 'lite-lp') {
        $body = '{"video_models":{"PAYGATE_TIER_TWO":{"frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_lite_low_priority","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_lite_low_priority"},"start_end_frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_lite_low_priority","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_lite_low_priority"}}}}'
    }
    elseif ($Preset -eq 'lite') {
        $body = '{"video_models":{"PAYGATE_TIER_TWO":{"frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_lite","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_lite"},"start_end_frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_lite","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_lite"}}}}'
    }
    elseif ($Preset -eq 'leaving') {
        $body = '{"video_models":{"PAYGATE_TIER_TWO":{"frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_s_fast_ultra_relaxed","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_s_fast_ultra_relaxed"},"start_end_frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_s_fast_ultra_relaxed","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_s_fast_ultra_relaxed"},"reference_frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_r2v_fast_landscape_ultra_relaxed","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_r2v_fast_landscape_ultra_relaxed"}}}}'
    }
    elseif ($Preset -eq 'ultra') {
        $body = '{"video_models":{"PAYGATE_TIER_TWO":{"frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_s_fast_ultra","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_s_fast_portrait_ultra"},"start_end_frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_1_i2v_s_fast_ultra_fl","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_1_i2v_s_fast_portrait_ultra_fl"},"reference_frame_2_video":{"VIDEO_ASPECT_RATIO_LANDSCAPE":"veo_3_0_r2v_fast_ultra","VIDEO_ASPECT_RATIO_PORTRAIT":"veo_3_0_r2v_fast_portrait_ultra"}}}}'
    }
    Invoke-FkApi -Method PATCH -Path '/api/models' -Body $body | Out-Null
    Write-Host ("Applied preset {0}. Lite presets: follow skills/lite-continuity.md" -f $Preset)
}

if ($PatchJson) {
    $raw = [IO.File]::ReadAllText($PatchJson)
    Invoke-FkApi -Method PATCH -Path '/api/models' -Body $raw | Out-Null
    Write-Host "Patched models from JSON file"
}

Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/models'))
