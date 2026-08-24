[CmdletBinding()]
param(
    [string]$OutputRoot = "",
    [string]$FilePattern = "*"
)

$ErrorActionPreference = "Stop"
$SampleRate = 48000
$BitDepth = 16
$Channels = 1

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot "..\..\assets\audio\sfx"
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
[System.IO.Directory]::CreateDirectory($OutputRoot) | Out-Null

function Get-Envelope {
    param([double]$Time, [double]$Duration, [double]$Attack = 0.006, [double]$Release = 0.08)
    $attackGain = [Math]::Min(1.0, $Time / [Math]::Max(0.0001, $Attack))
    $releaseStart = [Math]::Max(0.0, $Duration - $Release)
    $releaseGain = if ($Time -le $releaseStart) { 1.0 } else {
        [Math]::Max(0.0, ($Duration - $Time) / [Math]::Max(0.0001, $Release))
    }
    return $attackGain * $releaseGain
}

function Get-Noise {
    param([int]$Index, [int]$Seed)
    $value = ([uint64]($Index + 1) * 1103515245 + [uint64]$Seed * 12345 + 1013904223) -band 0x7fffffff
    return ([double]$value / 1073741823.5) - 1.0
}

function Get-Sample {
    param(
        [string]$Recipe,
        [double]$Time,
        [double]$Duration,
        [int]$Index,
        [int]$Seed
    )
    $tau = 2.0 * [Math]::PI
    $env = Get-Envelope -Time $Time -Duration $Duration
    $noise = Get-Noise -Index $Index -Seed $Seed
    switch ($Recipe) {
        "ui_activate" { return $env * (0.42 * [Math]::Sin($tau * 720 * $Time) + 0.20 * [Math]::Sin($tau * 1080 * $Time)) }
        "ui_cancel" { $f = 440 - 170 * ($Time / $Duration); return $env * 0.48 * [Math]::Sin($tau * $f * $Time) }
        "ui_reject" { return $env * (0.30 * [Math]::Sin($tau * 185 * $Time) + 0.12 * [Math]::Sin($tau * 197 * $Time) + 0.05 * $noise) }
		"opening_gate_strain" { $rise = [Math]::Min(1.0, $Time / 0.24); return $env * $rise * (0.30 * [Math]::Sin($tau * 58 * $Time) + 0.18 * [Math]::Sin($tau * 91 * $Time) + 0.12 * $noise) }
		"opening_gate_open" { $grind = 0.16 * $noise + 0.24 * [Math]::Sin($tau * (43 + 6 * [Math]::Sin($tau * 0.42 * $Time)) * $Time); $pulse = 0.72 + 0.28 * [Math]::Sin($tau * 2.4 * $Time); return $env * $pulse * ($grind + 0.10 * [Math]::Sin($tau * 79 * $Time)) }
		"opening_fog_reveal" { $sweep = 270 + 540 * ($Time / $Duration); return $env * (0.17 * $noise + 0.23 * [Math]::Sin($tau * $sweep * $Time) + 0.10 * [Math]::Sin($tau * 135 * $Time)) }
		"opening_menu_reveal" { return $env * [Math]::Exp(-2.2 * $Time) * (0.34 * [Math]::Sin($tau * 392 * $Time) + 0.22 * [Math]::Sin($tau * 588 * $Time) + 0.13 * [Math]::Sin($tau * 784 * $Time)) }
        "board_select" { return $env * (0.34 * [Math]::Sin($tau * 560 * $Time) + 0.16 * $noise) * [Math]::Exp(-12 * $Time) }
        "move_foot" { return $env * (0.42 * [Math]::Sin($tau * 115 * $Time) + 0.18 * $noise) * [Math]::Exp(-7 * $Time) }
        "move_cavalry" { $pulse = [Math]::Exp(-90 * [Math]::Abs(($Time % 0.105) - 0.012)); return $env * $pulse * (0.32 * $noise + 0.28 * [Math]::Sin($tau * 230 * $Time)) }
        "move_chariot" { return $env * (0.22 * $noise + 0.32 * [Math]::Sin($tau * 72 * $Time) + 0.12 * [Math]::Sin($tau * 143 * $Time)) }
        "move_cannon" { return $env * (0.34 * [Math]::Sin($tau * 165 * $Time) + 0.19 * [Math]::Sin($tau * 430 * $Time) + 0.08 * $noise) }
        "pass" { return $env * (0.46 * [Math]::Sin($tau * 390 * $Time) + 0.14 * $noise) * [Math]::Exp(-10 * $Time) }
        "timeout" { $gate = if (($Time -lt 0.13) -or ($Time -gt 0.22 -and $Time -lt 0.35)) { 1.0 } else { 0.0 }; return $env * $gate * 0.48 * [Math]::Sin($tau * 880 * $Time) }
        "capture" { return $env * (0.38 * $noise + 0.42 * [Math]::Sin($tau * 88 * $Time)) * [Math]::Exp(-5 * $Time) }
        "casualty" { return $env * (0.36 * [Math]::Sin($tau * 142 * $Time) + 0.12 * $noise) * [Math]::Exp(-4 * $Time) }
        "bombard_launch" { $f = 95 + 520 * ($Time / $Duration); return $env * (0.28 * [Math]::Sin($tau * $f * $Time) + 0.16 * $noise * ($Time / $Duration)) }
        "bombard_impact" { $sum = 0.0; foreach ($hit in @(0.04, 0.27, 0.51)) { $dt = $Time - $hit; if ($dt -ge 0 -and $dt -lt 0.18) { $sum += [Math]::Exp(-24 * $dt) * (0.34 * $noise + 0.38 * [Math]::Sin($tau * 67 * $dt)) } }; return $env * $sum }
        "advisor_sacrifice" { return $env * (0.34 * [Math]::Sin($tau * 310 * $Time) + 0.20 * [Math]::Sin($tau * 465 * $Time)) * [Math]::Exp(-2.8 * $Time) }
        "advisor_resurrect" { $f = 260 + 420 * ($Time / $Duration); return $env * (0.34 * [Math]::Sin($tau * $f * $Time) + 0.14 * [Math]::Sin($tau * $f * 1.5 * $Time)) }
        "wall_breach" { return $env * (0.34 * $noise + 0.42 * [Math]::Sin($tau * 54 * $Time)) * [Math]::Exp(-2.7 * $Time) }
        "wall_repairing" { $pulse = [Math]::Exp(-75 * [Math]::Abs(($Time % 0.13) - 0.018)); return $env * $pulse * (0.34 * [Math]::Sin($tau * 330 * $Time) + 0.14 * $noise) }
        "wall_repaired" { return $env * (0.42 * [Math]::Sin($tau * 104 * $Time) + 0.16 * [Math]::Sin($tau * 312 * $Time)) * [Math]::Exp(-4 * $Time) }
        "flag_discovered" { return $env * (0.33 * [Math]::Sin($tau * 520 * $Time) + 0.24 * [Math]::Sin($tau * 780 * $Time)) }
        "flag_progress" { return $env * (0.40 * [Math]::Sin($tau * 610 * $Time) + 0.12 * [Math]::Sin($tau * 915 * $Time)) }
        "flag_captured" { $f = 390 + 260 * [Math]::Floor(4 * $Time / $Duration); return $env * (0.32 * [Math]::Sin($tau * $f * $Time) + 0.16 * [Math]::Sin($tau * $f * 1.5 * $Time)) }
        "flag_cancelled" { $f = 510 - 250 * ($Time / $Duration); return $env * 0.42 * [Math]::Sin($tau * $f * $Time) }
        "fog_reveal" { return $env * (0.19 * $noise + 0.25 * [Math]::Sin($tau * (360 + 220 * $Time) * $Time)) }
        "contact" { $pulse = if ($Time -lt 0.16) { 1.0 } elseif ($Time -gt 0.24 -and $Time -lt 0.40) { 0.7 } else { 0.0 }; return $env * $pulse * 0.36 * [Math]::Sin($tau * 245 * $Time) }
        "reveal_piece" { return $env * (0.34 * [Math]::Sin($tau * 690 * $Time) + 0.16 * $noise) }
        "elephant_field" { return $env * (0.28 * [Math]::Sin($tau * 205 * $Time) + 0.18 * [Math]::Sin($tau * 307.5 * $Time)) }
        "turn" { $f = if ($Time -lt $Duration / 2) { 520 } else { 690 }; return $env * 0.42 * [Math]::Sin($tau * $f * $Time) }
        "victory" { $f = 330 * [Math]::Pow(2, [Math]::Floor(4 * $Time / $Duration) / 6.0); return $env * (0.34 * [Math]::Sin($tau * $f * $Time) + 0.18 * [Math]::Sin($tau * $f * 2 * $Time)) }
        "defeat" { $f = 330 - 170 * ($Time / $Duration); return $env * (0.36 * [Math]::Sin($tau * $f * $Time) + 0.14 * [Math]::Sin($tau * $f * 0.5 * $Time)) }
        "draw" { return $env * (0.30 * [Math]::Sin($tau * 294 * $Time) + 0.22 * [Math]::Sin($tau * 392 * $Time)) }
        default { throw "Unknown recipe: $Recipe" }
    }
}

function Write-MonoWav {
    param([string]$FileName, [string]$Recipe, [double]$Duration, [int]$Seed)
    $sampleCount = [int][Math]::Ceiling($SampleRate * $Duration)
    $dataSize = $sampleCount * 2
    $path = Join-Path $OutputRoot $FileName
    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $writer.Write([int](36 + $dataSize))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]$Channels)
        $writer.Write([int]$SampleRate)
        $writer.Write([int]($SampleRate * $Channels * ($BitDepth / 8)))
        $writer.Write([int16]($Channels * ($BitDepth / 8)))
        $writer.Write([int16]$BitDepth)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $writer.Write([int]$dataSize)
        for ($index = 0; $index -lt $sampleCount; $index++) {
            $time = [double]$index / $SampleRate
            $sample = Get-Sample -Recipe $Recipe -Time $time -Duration $Duration -Index $index -Seed $Seed
            $sample = [Math]::Max(-0.92, [Math]::Min(0.92, $sample))
            $writer.Write([int16][Math]::Round($sample * 32767.0))
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    [pscustomobject]@{ file = $FileName; recipe = $Recipe; duration = $Duration; seed = $Seed; sha256 = $hash }
}

$recipes = @(
    @("sfx_ui_activate_v01.wav", "ui_activate", 0.13, 1101),
    @("sfx_ui_cancel_v01.wav", "ui_cancel", 0.16, 1102),
    @("sfx_ui_reject_v01.wav", "ui_reject", 0.20, 1103),
	@("sfx_opening_gate_strain_v01.wav", "opening_gate_strain", 0.64, 1111),
	@("sfx_opening_gate_open_v01.wav", "opening_gate_open", 3.95, 1112),
	@("sfx_opening_fog_reveal_v01.wav", "opening_fog_reveal", 1.05, 1113),
	@("sfx_opening_menu_reveal_v01.wav", "opening_menu_reveal", 0.58, 1114),
    @("sfx_board_select_v01.wav", "board_select", 0.14, 1201),
    @("sfx_move_foot_v01.wav", "move_foot", 0.24, 1301),
    @("sfx_move_cavalry_v01.wav", "move_cavalry", 0.34, 1302),
    @("sfx_move_chariot_v01.wav", "move_chariot", 0.40, 1303),
    @("sfx_move_cannon_v01.wav", "move_cannon", 0.36, 1304),
    @("sfx_action_pass_v01.wav", "pass", 0.20, 1401),
    @("sfx_turn_timeout_v01.wav", "timeout", 0.44, 1402),
    @("sfx_capture_impact_v01.wav", "capture", 0.32, 1501),
    @("sfx_casualty_public_v01.wav", "casualty", 0.28, 1502),
    @("sfx_bombard_launch_v01.wav", "bombard_launch", 0.50, 1601),
    @("sfx_bombard_impact_bed_v01.wav", "bombard_impact", 0.78, 1602),
    @("sfx_advisor_sacrifice_v01.wav", "advisor_sacrifice", 0.68, 1701),
    @("sfx_advisor_resurrect_v01.wav", "advisor_resurrect", 0.74, 1702),
    @("sfx_wall_breached_v01.wav", "wall_breach", 0.82, 1801),
    @("sfx_wall_repairing_v01.wav", "wall_repairing", 0.46, 1802),
    @("sfx_wall_repaired_v01.wav", "wall_repaired", 0.44, 1803),
    @("sfx_flag_discovered_v01.wav", "flag_discovered", 0.48, 1901),
    @("sfx_flag_capture_progress_v01.wav", "flag_progress", 0.28, 1902),
    @("sfx_flag_captured_v01.wav", "flag_captured", 0.84, 1903),
    @("sfx_flag_capture_cancelled_v01.wav", "flag_cancelled", 0.34, 1904),
    @("sfx_fog_reveal_v01.wav", "fog_reveal", 0.58, 2001),
    @("sfx_contact_unknown_v01.wav", "contact", 0.48, 2002),
    @("sfx_reveal_piece_v01.wav", "reveal_piece", 0.36, 2003),
    @("sfx_special_elephant_field_v01.wav", "elephant_field", 0.58, 2004),
    @("sfx_turn_local_start_v01.wav", "turn", 0.30, 2101),
    @("sfx_match_victory_v01.wav", "victory", 0.98, 2201),
    @("sfx_match_defeat_v01.wav", "defeat", 0.98, 2202),
    @("sfx_match_draw_v01.wav", "draw", 0.84, 2203)
)

$manifest = foreach ($recipe in $recipes | Where-Object { $_[0] -like $FilePattern }) {
    Write-MonoWav -FileName $recipe[0] -Recipe $recipe[1] -Duration $recipe[2] -Seed $recipe[3]
}
$manifest | ConvertTo-Json -Depth 4
