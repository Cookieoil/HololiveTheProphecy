#!/usr/bin/env pwsh
# Runs the exact same headless gates CI runs (.github/workflows/validate_game_data.yml).
#
# Usage:
#   pwsh -File Tools/preflight.ps1
#   pwsh -File Tools/preflight.ps1 -Godot 'C:\path\to\godot.exe'
#   pwsh -File Tools/preflight.ps1 -SkipIndexCheck
#
# Exits 0 when every gate is green, 1 otherwise.
param(
    [string]$Godot = 'godot',
    [switch]$SkipIndexCheck
)

$ErrorActionPreference = 'Continue'

# Steam ships godot.exe as a GUI-subsystem binary: PowerShell neither waits for it
# nor sets $LASTEXITCODE, so every gate must be launched with -Wait -PassThru and
# judged on the process exit code.
$godotExe = $Godot
if (-not (Test-Path -LiteralPath $godotExe)) {
    $resolved = Get-Command $Godot -ErrorAction SilentlyContinue
    if ($resolved) { $godotExe = $resolved.Source }
}

if (-not (Test-Path -LiteralPath $godotExe)) {
    Write-Host ('Godot executable not found: ' + $Godot) -ForegroundColor Red
    exit 1
}

Write-Host ('Godot: ' + $godotExe) -ForegroundColor DarkGray

$gates = @(
    @{ Name = 'Import project';       Args = @('--headless', '--path', '.', '--import') },
    @{ Name = 'Validate game data';   Args = @('--headless', '--path', '.', 'res://Tools/validator.tscn', '--', '--strict') },
    @{ Name = 'Compile all scripts';  Args = @('--headless', '--path', '.', '--script', 'res://Tools/check_scripts.gd') },
    @{ Name = 'Unit tests (gdUnit4)'; Args = @('--headless', '--path', '.', '-s', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'res://GDTest', '-c', '--ignoreHeadlessMode') }
)

# The generated symbol index (Docs/) must still match the sources, otherwise the
# map the next reader trusts is lying. Same command the CI `project` job runs.
if ($SkipIndexCheck) {
    Write-Host 'Skipping the symbol index gate (-SkipIndexCheck).' -ForegroundColor Yellow
}
else {
    $gates += @{ Name = 'Symbol index up to date'; Args = @('--headless', '--path', '.', '--script', 'res://Tools/gen_code_index.gd', '--', '--check') }
}

$failed = @()

foreach ($gate in $gates) {
    Write-Host ''
    Write-Host ('=== ' + $gate.Name + ' ===') -ForegroundColor Cyan
    $a = [string[]]$gate.Args
    $proc = Start-Process -FilePath $godotExe -ArgumentList $a -NoNewWindow -Wait -PassThru
    $code = $proc.ExitCode
    if ($code -ne 0) {
        Write-Host ('FAILED (exit ' + $code + '): ' + $gate.Name) -ForegroundColor Red
        $failed += $gate.Name
    }
    else {
        Write-Host ('PASSED: ' + $gate.Name) -ForegroundColor Green
    }
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host ('PRE-FLIGHT FAILED: ' + ($failed -join ', ')) -ForegroundColor Red
    exit 1
}

Write-Host 'PRE-FLIGHT PASSED: every gate is green.' -ForegroundColor Green
exit 0
