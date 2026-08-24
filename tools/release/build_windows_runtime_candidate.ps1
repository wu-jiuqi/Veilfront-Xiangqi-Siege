[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotExecutable,

    [string]$ArtifactPath = "builds/windows/Veilfront_Xiangqi_Siege_Formal_LAN.exe",
    [string]$PackPath = "builds/windows/Veilfront_runtime_manifest.zip"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
$resolvedGodot = (Resolve-Path -LiteralPath $GodotExecutable).Path
$resolvedArtifact = [IO.Path]::GetFullPath((Join-Path $projectRoot $ArtifactPath))
$resolvedPack = [IO.Path]::GetFullPath((Join-Path $projectRoot $PackPath))
$buildDirectory = Split-Path -Parent $resolvedArtifact
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null

function Invoke-GodotStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    $output = & $resolvedGodot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllLines($LogPath, [string[]]$output)
    $errors = @($output | Where-Object { [string]$_ -match '(^|\s)(SCRIPT )?ERROR:' })
    if ($exitCode -ne 0 -or $errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Output $_ }
        throw "$Name 失败：exit=$exitCode errors=$($errors.Count)，详见 $LogPath"
    }
    Write-Output "WINDOWS_RUNTIME_BUILD_STEP_PASS step=$Name log=$LogPath"
}

Push-Location $projectRoot
try {
    Invoke-GodotStep `
        -Name "import" `
        -Arguments @("--headless", "--editor", "--path", ".", "--import") `
        -LogPath (Join-Path $buildDirectory "runtime_import.log")
    Invoke-GodotStep `
        -Name "interaction-performance-contract" `
        -Arguments @("--headless", "--path", ".", "--script", "res://tests/game/performance/run_match_interaction_performance_contract.gd") `
        -LogPath (Join-Path $buildDirectory "runtime_interaction_performance.log")
    Invoke-GodotStep `
        -Name "formal-lan-full-stack-contract" `
        -Arguments @("--headless", "--path", ".", "--script", "res://tests/game/network/run_formal_lan_full_stack_loopback.gd") `
        -LogPath (Join-Path $buildDirectory "runtime_formal_lan_full_stack.log")
    Invoke-GodotStep `
        -Name "export-pack" `
        -Arguments @("--headless", "--path", ".", "--export-pack", "Windows Desktop Formal LAN", $resolvedPack) `
        -LogPath (Join-Path $buildDirectory "runtime_pack_export.log")
    Invoke-GodotStep `
        -Name "export-release" `
        -Arguments @("--headless", "--path", ".", "--export-release", "Windows Desktop Formal LAN", $resolvedArtifact) `
        -LogPath (Join-Path $buildDirectory "runtime_release_export.log")

    & (Join-Path $PSScriptRoot "verify_windows_runtime_budget.ps1") `
        -ArtifactPath $resolvedArtifact `
        -PackPath $resolvedPack
    if ($LASTEXITCODE -ne 0) {
        throw "Windows 运行时预算验证失败。"
    }
    & (Join-Path $PSScriptRoot "verify_windows_lan_export.ps1") `
        -ArtifactPath $resolvedArtifact `
        -GodotExecutable $resolvedGodot
    if ($LASTEXITCODE -ne 0) {
        throw "Windows 成品启动验证失败。"
    }
    Write-Output "WINDOWS_RUNTIME_CANDIDATE_PASS artifact=$resolvedArtifact pack=$resolvedPack"
}
finally {
    Pop-Location
}
