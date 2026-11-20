<#
.SYNOPSIS
    Export a Spine project straight into the Godot character folder.

.DESCRIPTION
    Wraps the Spine CLI so an author edits `<char_id>.spine` and gets a
    Godot-ready `<char_id>.skel` + `<char_id>.atlas` + `<char_id>.png` (and the
    generated `<char_id>.tres`) inside `res://Scenes/BattleUnit/Spine/<char_id>/`.

    The project uses the spine-godot **4.2** runtime (see
    `bin/spine_godot_extension.gdextension` and `Tools/prepare_spine_portrait.py`),
    so the export MUST come from the Spine **4.2** editor. A 4.3 export will be
    rejected by the runtime.

    Export settings live in `Tools/spine/binary.json` (binary + nonessential,
    matching the committed rigs) and `Tools/spine/pack.json` (texture packer).
    The full walkthrough is `Tools/spine/README.md`.

.EXAMPLE
    pwsh -File Tools/export_spine_to_godot.ps1 -CharId striker
    pwsh -File Tools/export_spine_to_godot.ps1 -CharId striker -SpineVersion 4.2.36
    pwsh -File Tools/export_spine_to_godot.ps1 -CharId striker -DryRun
#>
[CmdletBinding()]
param(
    # Character id / folder name, e.g. striker, healer, boss_enemy.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$CharId,

    # Spine editor version to run. The project runtime is 4.2, so stay on 4.2.xx.
    [ValidatePattern('^\d+\.\d+(\.\d+|\.[xX]{2})?$')]
    [string]$SpineVersion = '4.2.xx',

    # Folder holding `<char_id>.spine`. Defaults to `<repo>/SpineSource`.
    [string]$SourceRoot,

    # Spine CLI. Defaults to the installed launcher.
    [string]$SpineExe = 'C:\Program Files\Spine\Spine.com',

    # Print the command without running it.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $SourceRoot) {
    $SourceRoot = Join-Path $repoRoot 'SpineSource'
}

$projectFile = Join-Path $SourceRoot "$CharId.spine"
$exportSettings = Join-Path $PSScriptRoot 'spine\binary.json'
$packSettings = Join-Path $PSScriptRoot 'spine\pack.json'
$outputDir = Join-Path $repoRoot "Scenes\BattleUnit\Spine\$CharId"

if (-not (Test-Path -LiteralPath $SpineExe)) {
    throw "Spine CLI not found: $SpineExe. Install the launcher, or pass -SpineExe."
}
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "Spine project not found: $projectFile. Put <char_id>.spine in $SourceRoot, or pass -SourceRoot."
}
if (-not (Test-Path -LiteralPath $exportSettings)) {
    throw "Export settings not found: $exportSettings"
}
if (-not (Test-Path -LiteralPath $packSettings)) {
    throw "Pack settings not found: $packSettings"
}
if ($SpineVersion -notlike '4.2*') {
    Write-Warning "The project runtime is Spine 4.2 but -SpineVersion is '$SpineVersion'. A non-4.2 export will not load at runtime."
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Order matters: the skeleton data first (with the atlas packed from the
# project's own attachments), then a second pass that packs the raw images
# folder so the atlas page name matches the character id.
$arguments = @(
    '-u', $SpineVersion
    '-i', $projectFile
    '-o', $outputDir
    '-e', $exportSettings
    '-i', $projectFile
    '-o', $outputDir
    '-n', $CharId
    '-p', $packSettings
)

if ($DryRun) {
    Write-Host "DRY RUN: $SpineExe $($arguments -join ' ')"
    exit 0
}

Write-Host "Exporting $CharId with Spine $SpineVersion -> $outputDir"
& $SpineExe @arguments
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "Spine export failed with exit code $exitCode."
}

# Spine writes the atlas/PNG itself; only the skeleton data goes through the
# project's normalizer, which also generates the .tres the scenes load.
$skel = Join-Path $outputDir "$CharId.skel"
$atlas = Join-Path $outputDir "$CharId.atlas"
$png = Join-Path $outputDir "$CharId.png"

if (-not (Test-Path -LiteralPath $skel)) {
    throw "Spine did not write $skel. Check the export settings."
}

Write-Host ''
Write-Host 'Normalizing the atlas and generating the .tres ...'
python (Join-Path $PSScriptRoot 'prepare_spine_portrait.py') `
    --skel $skel --atlas $atlas --png $png --name $CharId --out $outputDir

Write-Host ''
Write-Host 'Done. Open the Godot editor once so it imports the new files.'
Write-Host "Verify the runtime link with: godot --headless --path . --script res://Tools/check_spine_runtime.gd"
