[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactPath,

    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath).Path

$artifactExtension = [IO.Path]::GetExtension($resolvedArtifact).ToLowerInvariant()
if ($artifactExtension -eq ".exe") {
    $output = & $resolvedArtifact `
        --headless `
        --audio-driver Dummy `
        --quit-after 120 2>&1
}
else {
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
        --audio-driver Dummy `
        --main-pack $resolvedArtifact `
        --quit-after 120 2>&1
}
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }

if ($exitCode -ne 0) {
    throw "成品包启动失败，Godot 退出码：$exitCode"
}

$errors = @($output | Where-Object { [string]$_ -match '(^|\s)(SCRIPT )?ERROR:' })
if ($errors.Count -gt 0) {
    throw "成品包启动日志包含错误：$($errors.Count)"
}

Write-Output "WINDOWS_LAN_EXPORT_VERIFY_PASS artifact=$resolvedArtifact frames=120"
