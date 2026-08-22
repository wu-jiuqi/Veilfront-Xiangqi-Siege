[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactPath,

    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath).Path

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -eq $godotCommand) {
        $godotCommand = Get-Command godot4 -ErrorAction SilentlyContinue
    }
    if ($null -eq $godotCommand) {
        throw "找不到 Godot 命令，请通过 -GodotExecutable 指定 Godot 4.7.1 可执行文件。"
    }
    $GodotExecutable = $godotCommand.Source
}

$output = & $GodotExecutable `
    --headless `
    --main-pack $resolvedArtifact `
    --script res://tests/game/network/run_formal_lan_full_stack_loopback.gd 2>&1
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }

if ($exitCode -ne 0) {
    throw "成品包联机回归失败，Godot 退出码：$exitCode"
}

$passMarker = "FORMAL_LAN_FULL_STACK_LOOPBACK_PASS ux=ready-start-match-submit-disconnect"
if (($output -join "`n") -notmatch [regex]::Escape($passMarker)) {
    throw "成品包未输出预期的正式局域网全栈通过标记。"
}

Write-Output "WINDOWS_LAN_EXPORT_VERIFY_PASS artifact=$resolvedArtifact"
