[CmdletBinding()]
param(
    [string]$ArtifactPath = "builds/windows/Veilfront_Xiangqi_Siege_Formal_LAN.exe",
    [string]$PackPath = "builds/windows/Veilfront_runtime_manifest.zip",
    [string]$PolicyPath = "tools/release/windows_runtime_manifest.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path

function Resolve-ProjectFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $projectRoot $Path)).Path
}

$resolvedArtifact = Resolve-ProjectFile -Path $ArtifactPath
$resolvedPack = Resolve-ProjectFile -Path $PackPath
$resolvedPolicy = Resolve-ProjectFile -Path $PolicyPath
$policy = Get-Content -LiteralPath $resolvedPolicy -Raw | ConvertFrom-Json
$presetPath = Join-Path $projectRoot "export_presets.cfg"
$presetText = Get-Content -LiteralPath $presetPath -Raw

if ($presetText -notmatch 'export_filter="resources"') {
    throw "Windows 导出没有使用 selected resources 白名单。"
}
if ($presetText -match 'export_filter="all_resources"') {
    throw "Windows 导出仍在使用 all_resources。"
}
if ($presetText -notmatch 'binary_format/embed_pck=true') {
    throw "Windows 导出没有启用 embedded PCK。"
}

$exportFilesLine = [regex]::Match($presetText, '(?m)^export_files=.*$').Value
$actualSelected = @(
    [regex]::Matches($exportFilesLine, 'res://[^\"]+') |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique
)
$expectedSelected = @($policy.selected_resources | Sort-Object -Unique)
$selectionDrift = @(Compare-Object -ReferenceObject $expectedSelected -DifferenceObject $actualSelected)
if ($selectionDrift.Count -gt 0) {
    $details = ($selectionDrift | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join "; "
    throw "export_presets.cfg 与运行时 manifest 的资源白名单不一致：$details"
}

foreach ($selectedResource in $policy.selected_resources) {
    $sourcePath = Join-Path $projectRoot ([string]$selectedResource).Substring(6)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "manifest 指向不存在的运行时资源：$selectedResource"
    }
}

foreach ($includedFile in $policy.included_non_resources) {
    if ($presetText -notmatch [regex]::Escape([string]$includedFile)) {
        throw "导出 include_filter 缺少非 Resource 文件：$includedFile"
    }
}

foreach ($dynamicAsset in $policy.required_dynamic_assets) {
    $dynamicAssetPath = ([string]$dynamicAsset).Substring(6)
    if ($presetText -notmatch [regex]::Escape($dynamicAssetPath)) {
        throw "导出 include_filter 缺少 HUD 动态资产：$dynamicAsset"
    }
}

foreach ($runtimeImage in $policy.required_runtime_images) {
    $runtimeImagePath = ([string]$runtimeImage).Substring(6)
    $sourcePath = Join-Path $projectRoot $runtimeImagePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "manifest 指向不存在的运行时图片：$runtimeImage"
    }
    if ($presetText -notmatch [regex]::Escape($runtimeImagePath)) {
        throw "导出 include_filter 缺少运行时图片：$runtimeImage"
    }
}

$catalogPath = Join-Path $projectRoot ([string]$policy.dynamic_asset_catalog)
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$catalogAssets = @(
    $catalog.ui_catalog |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.asset) } |
        ForEach-Object { [string]$_.asset } |
        Sort-Object -Unique
)
$expectedDynamicAssets = @($policy.required_dynamic_assets | Sort-Object -Unique)
$catalogDrift = @(Compare-Object -ReferenceObject $expectedDynamicAssets -DifferenceObject $catalogAssets)
if ($catalogDrift.Count -gt 0) {
    $details = ($catalogDrift | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join "; "
    throw "HUD 动态资产目录与 manifest 不一致：$details"
}

$artifactBytes = (Get-Item -LiteralPath $resolvedArtifact).Length
$exeBudget = [int64]$policy.budgets.windows_exe_max_bytes
if ($artifactBytes -gt $exeBudget) {
    throw "Windows EXE 超出预算：$artifactBytes > $exeBudget bytes"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedPack)
try {
    $entries = @($archive.Entries)
    $entryNames = @($entries | ForEach-Object { $_.FullName.Replace('\', '/').ToLowerInvariant() })
    foreach ($selectedResource in $policy.selected_resources) {
        $requiredRemap = ([string]$selectedResource).Substring(6).ToLowerInvariant() + ".remap"
        if ($requiredRemap -notin $entryNames) {
            throw "运行时包缺少白名单资源映射：$selectedResource"
        }
    }
    foreach ($dynamicAsset in $policy.required_dynamic_assets) {
        $requiredImport = ([string]$dynamicAsset).Substring(6).ToLowerInvariant() + ".import"
        if ($requiredImport -notin $entryNames) {
            throw "运行时包缺少 HUD 动态资产：$dynamicAsset"
        }
    }
    foreach ($runtimeImage in $policy.required_runtime_images) {
        $requiredImport = ([string]$runtimeImage).Substring(6).ToLowerInvariant() + ".import"
        if ($requiredImport -notin $entryNames) {
            throw "运行时包缺少运行时图片：$runtimeImage"
        }
    }
    foreach ($requiredEntry in $policy.required_pack_entries) {
        if ([string]$requiredEntry.ToLowerInvariant() -notin $entryNames) {
            throw "运行时包缺少必要条目：$requiredEntry"
        }
    }
    foreach ($forbiddenFragment in $policy.forbidden_pack_path_fragments) {
        $needle = [string]$forbiddenFragment.ToLowerInvariant()
        $hit = $entryNames | Where-Object { $_.Contains($needle) } | Select-Object -First 1
        if ($null -ne $hit) {
            throw "运行时包包含禁止条目：$hit"
        }
    }

    $expandedBytes = [int64](($entries | Measure-Object -Property Length -Sum).Sum)
    $textureBytes = [int64](($entries | Where-Object { $_.FullName.EndsWith('.ctex') } | Measure-Object -Property Length -Sum).Sum)
    $fontBytes = [int64](($entries | Where-Object { $_.FullName.EndsWith('.fontdata') } | Measure-Object -Property Length -Sum).Sum)
    if ($expandedBytes -gt [int64]$policy.budgets.runtime_pack_expanded_max_bytes) {
        throw "运行时包展开体积超出预算：$expandedBytes bytes"
    }
    if ($textureBytes -gt [int64]$policy.budgets.runtime_texture_max_bytes) {
        throw "运行时纹理超出预算：$textureBytes bytes"
    }
    if ($fontBytes -gt [int64]$policy.budgets.runtime_font_max_bytes) {
        throw "运行时字体超出预算：$fontBytes bytes"
    }

    $headroomBytes = $exeBudget - $artifactBytes
    Write-Output (
        "WINDOWS_RUNTIME_BUDGET_PASS " +
        "exe_bytes=$artifactBytes exe_headroom_bytes=$headroomBytes " +
        "pack_zip_bytes=$((Get-Item -LiteralPath $resolvedPack).Length) " +
        "pack_expanded_bytes=$expandedBytes texture_bytes=$textureBytes " +
        "font_bytes=$fontBytes entries=$($entries.Count)"
    )
}
finally {
    $archive.Dispose()
}
