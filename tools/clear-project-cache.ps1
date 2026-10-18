[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'pubspec.yaml')) -or
    -not (Test-Path -LiteralPath (Join-Path $projectRoot 'unity/Pawdo3D/Assets/Pawdo'))) {
    throw 'This command must be run from the Pawdo project tools directory.'
}

# Only reproducible derivatives. Keep exported Unity runtime, package downloads,
# app data, signing keys, source assets, screenshots and test evidence.
$relativeTargets = @(
    'build',
    'android/.gradle',
    'unity/Pawdo3D/Library/Bee',
    'unity/Pawdo3D/Library/BurstCache',
    'unity/Pawdo3D/Library/ShaderCache',
    'unity/Pawdo3D/Library/TempArtifacts',
    'unity/Pawdo3D/Temp',
    'unity/Pawdo3D/Logs'
)
$boundary = $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$candidates = foreach ($relative in $relativeTargets) {
    $absolute = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    if (-not $absolute.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe cleanup target: $absolute"
    }
    if (-not (Test-Path -LiteralPath $absolute)) { continue }
    # Refuse junctions/symlinks both in the target and any ancestor below the root.
    $cursor = Get-Item -LiteralPath $absolute -Force
    while ($cursor.FullName -ne $projectRoot) {
        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Cleanup refuses a reparse point: $($cursor.FullName)"
        }
        $cursor = $cursor.Parent
    }
    $descendants = @(Get-ChildItem -LiteralPath $absolute -Recurse -Force)
    if ($descendants | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }) {
        throw "Cleanup refuses a linked descendant inside $absolute"
    }
    $bytes = ($descendants | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
    [pscustomobject]@{ Path = $absolute; Bytes = [long]$bytes; MiB = [math]::Round($bytes / 1MB, 1) }
}

$candidates | Format-Table Path, MiB -AutoSize
if (-not $Apply) {
    Write-Output 'Preview only. Pass -Apply to remove these regenerable caches.'
    return
}
if (Get-Process -Name Unity,bee_backend,UnityShaderCompiler -ErrorAction SilentlyContinue) {
    throw 'Finish or close Unity builds before clearing caches.'
}

$removedBytes = 0L
foreach ($candidate in $candidates) {
    if ($PSCmdlet.ShouldProcess($candidate.Path, 'Remove regenerable project cache')) {
        Remove-Item -LiteralPath $candidate.Path -Recurse -Force
        $removedBytes += $candidate.Bytes
    }
}
Write-Output ('Removed {0:N1} MiB. Build tools regenerate these files; source and app data were preserved.' -f ($removedBytes / 1MB))
