#!/usr/bin/env pwsh
# Runs the exact same headless gates CI runs (.github/workflows/validate_game_data.yml).
#
# Usage:
#   pwsh -File Tools/preflight.ps1
#   pwsh -File Tools/preflight.ps1 -Godot 'C:\path\to\godot.exe'
#   pwsh -File Tools/preflight.ps1 -FixIndex          # regenerate Docs/ first
#   pwsh -File Tools/preflight.ps1 -SkipIndexCheck    # leave Docs/ alone
#   pwsh -File Tools/preflight.ps1 -Snapshots         # also render UI snapshots
#   pwsh -File Tools/preflight.ps1 -Review            # also review the branch vs origin/main
#
# Exits 0 when every gate is green, 1 otherwise.
param(
    [string]$Godot = 'godot',
    [switch]$FixIndex,
    [switch]$SkipIndexCheck,
    [switch]$Snapshots,
    [switch]$Review
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

$failed = @()
# Gates that could not run on this machine (a missing optional tool). They are printed
# in the summary, never swallowed: a skipped gate is not a passing gate.
$skipped = @()

# -FixIndex regenerates the symbol index before the gates run, so a stale index
# is repaired in the same invocation instead of costing another round trip.
if ($FixIndex) {
    Write-Host ''
    Write-Host '=== Regenerate symbol index (-FixIndex) ===' -ForegroundColor Cyan
    $fixArgs = @('--headless', '--path', '.', '--script', 'res://Tools/gen_code_index.gd')
    $fix = Start-Process -FilePath $godotExe -ArgumentList $fixArgs -NoNewWindow -Wait -PassThru
    if ($fix.ExitCode -ne 0) {
        Write-Host ('FAILED (exit ' + $fix.ExitCode + '): Regenerate symbol index') -ForegroundColor Red
        $failed += 'Regenerate symbol index'
    }
    else {
        Write-Host 'PASSED: Regenerate symbol index' -ForegroundColor Green
    }
}

$gates = @(
    @{ Name = 'Import project';       Args = @('--headless', '--path', '.', '--import') },
    @{ Name = 'Validate game data';   Args = @('--headless', '--path', '.', 'res://Tools/validator.tscn', '--', '--strict') },
    @{ Name = 'Compile all scripts';  Args = @('--headless', '--path', '.', '--script', 'res://Tools/check_scripts.gd') },
    # The replay CLI is the command a seed from a telemetry report or a bug report is
    # reproduced with, and it shares Tools/BattleSimulator.gd with the determinism suite,
    # so a smoke run of three shipped seeds keeps its argument parsing and the shipped
    # battle honest. Same command the CI `project` job runs.
    @{ Name = 'Replay a seed';        Args = @('--headless', '--path', '.', 'res://Tools/simulate_runs.tscn', '--', '--seeds', '3') },
    @{ Name = 'Unit tests (gdUnit4)'; Args = @('--headless', '--path', '.', '-s', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'res://GDTest', '-c', '--ignoreHeadlessMode') }
)

# The generated navigation set (Docs/) must still match the sources, otherwise
# the map the next reader trusts is lying. The harness also checks coverage,
# ranges, links, scenes, signals and data against the sources, exercises the
# generator in a scratch directory, and prints the read-cost benchmark. Same
# command the CI `project` job runs.
if ($SkipIndexCheck) {
    Write-Host 'Skipping the navigation index gate (-SkipIndexCheck).' -ForegroundColor Yellow
}
else {
    $gates += @{ Name = 'Navigation index checks'; Args = @('--headless', '--path', '.', '--script', 'res://Tools/check_navigation.gd') }
}

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

# Anti-slop lint: banned patterns plus the size / branching / get_parent ratchets.
# --strict so a stale ratchet entry fails the run instead of warning, which is what
# keeps the ceiling one-way. Same script the CI `validate` job runs.
Write-Host ''
Write-Host '=== Anti-slop lint ===' -ForegroundColor Cyan
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
# `py` is the Windows launcher, and it is the only one of the three that survives a
# detached shell whose PATH has been trimmed (the WindowsApps `python.exe` alias and
# the Store shim both go missing there).
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Host 'FAILED: python not found (required by Tools/line_godot_slop.py)' -ForegroundColor Red
    $failed += 'Anti-slop lint'
}
else {
    $lint = Start-Process -FilePath $python.Source -ArgumentList 'Tools/line_godot_slop.py', '--strict' -NoNewWindow -Wait -PassThru
    if ($lint.ExitCode -ne 0) {
        Write-Host ('FAILED (exit ' + $lint.ExitCode + '): Anti-slop lint') -ForegroundColor Red
        $failed += 'Anti-slop lint'
    }
    else {
        Write-Host 'PASSED: Anti-slop lint' -ForegroundColor Green
    }
}

# The two Python tools are covered by their own dependency-free suites
# (Tools/<module>_test.py, the same shape as rig_combat_actor_test.py): the lint's rules
# and the balance report's maths, which is what a wrong number in a design decision would
# come from. rig_combat_actor_test.py was always in that shape and is run here too - it
# was the only Python tool in the repository with no gate at all. `python` was resolved
# above for the anti-slop gate; if it is missing, that gate has already reported it, so
# this one is skipped rather than failed three times.
Write-Host ''
Write-Host '=== Python tooling tests ===' -ForegroundColor Cyan
if (-not $python) {
    Write-Host 'SKIPPED: python not found (reported by the anti-slop gate above)' -ForegroundColor Red
}
else {
    $pythonSuites = @(
        @{ Name = 'Anti-slop lint rules'; Script = 'Tools/line_godot_slop_test.py' },
        @{ Name = 'Telemetry report maths'; Script = 'Tools/analyze_telemetry_test.py' },
        @{ Name = 'Spine rig patcher'; Script = 'Tools/rig_combat_actor_test.py' },
        # The only tool that can see a UI regression, so its decoder is pinned before it is
        # trusted: a comparison whose PNG reader is wrong reports "no change" for two
        # images that differ, which is a green tick over something nobody looked at.
        @{ Name = 'Snapshot comparator'; Script = 'Tools/compare_snapshots_test.py' }
    )
    foreach ($suite in $pythonSuites) {
        $suites = Start-Process -FilePath $python.Source -ArgumentList $suite.Script -NoNewWindow -Wait -PassThru
        if ($suites.ExitCode -ne 0) {
            Write-Host ('FAILED (exit ' + $suites.ExitCode + '): ' + $suite.Name) -ForegroundColor Red
            $failed += ('Python tooling tests (' + $suite.Name + ')')
        }
        else {
            Write-Host ('PASSED: ' + $suite.Name) -ForegroundColor Green
        }
    }
}

# The telemetry-ingest Edge Function is TypeScript, and its row shapes, HTTP rules and
# write order are unit tested with the Node the toolchain already has (no Deno, no
# network, no database). Same command the CI `validate` job runs.
Write-Host ''
Write-Host '=== Telemetry ingest tests (Node) ===' -ForegroundColor Cyan
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Host 'FAILED: node not found (required for the telemetry-ingest suite)' -ForegroundColor Red
    $failed += 'Telemetry ingest tests'
}
else {
    $nodeArgs = @('--test', 'Server/supabase/functions/telemetry-ingest/*.test.ts')
    $nodeTests = Start-Process -FilePath $node.Source -ArgumentList $nodeArgs -NoNewWindow -Wait -PassThru
    if ($nodeTests.ExitCode -ne 0) {
        Write-Host ('FAILED (exit ' + $nodeTests.ExitCode + '): Telemetry ingest tests') -ForegroundColor Red
        $failed += 'Telemetry ingest tests'
    }
    else {
        Write-Host 'PASSED: Telemetry ingest tests' -ForegroundColor Green
    }
}

# index.ts is the one file the Node suite cannot import: it owns the
# `https://esm.sh/@supabase/supabase-js@2` import and the `Deno.serve` call. `deno
# check` typechecks it against the real client types, so the entrypoint is verified
# rather than eyeballed. Install with:
#   curl.exe -sSL -o deno.zip https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip
#   Expand-Archive deno.zip -DestinationPath "$env:USERPROFILE\Tools\bin" -Force
Write-Host ''
Write-Host '=== Telemetry ingest types (deno check) ===' -ForegroundColor Cyan
$deno = Get-Command deno -ErrorAction SilentlyContinue
if (-not $deno) {
    Write-Host 'FAILED: deno not found (required for `deno check` on the ingest entrypoint).' -ForegroundColor Red
    Write-Host '       See the install command in the comment above this gate.' -ForegroundColor DarkGray
    $failed += 'Telemetry ingest types'
}
else {
    $denoArgs = @('check', 'Server/supabase/functions/telemetry-ingest/index.ts')
    $denoCheck = Start-Process -FilePath $deno.Source -ArgumentList $denoArgs -NoNewWindow -Wait -PassThru
    if ($denoCheck.ExitCode -ne 0) {
        Write-Host ('FAILED (exit ' + $denoCheck.ExitCode + '): Telemetry ingest types') -ForegroundColor Red
        $failed += 'Telemetry ingest types'
    }
    else {
        Write-Host 'PASSED: Telemetry ingest types' -ForegroundColor Green
    }
}

# The migrations were, until this gate existed, only ever *read*: `create or replace
# view` cannot add a column in the middle of a view, so
# Server/supabase/migrations/004_flag_cohorts_by_balance.sql never applied to a fresh
# database at all - `supabase db push` stopped there, before 005 or 006 ran. This
# applies 001-006 in order to a real PostgreSQL server and then asserts what the views
# answer, using the fixtures Tools/analyze_telemetry_test.py already covers. Same gate
# the CI `validate` job runs.
#
# `psql` is not part of the toolchain this repo installs, and the assertion file runs in
# CI on every pull request, so a machine without it reports a SKIP rather than a failure
# - but the skip is always printed. Connection settings come from libpq's own
# environment (PGHOST / PGUSER / PGPASSWORD); the scratch database is dropped and
# recreated, so nothing else on the server is touched.
Write-Host ''
Write-Host '=== Migration parity (PostgreSQL) ===' -ForegroundColor Cyan
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host 'SKIPPED: psql not found. Install PostgreSQL 13+ and set PGHOST/PGUSER/PGPASSWORD to run this locally; CI runs it on every pull request.' -ForegroundColor Yellow
    $skipped += 'Migration parity'
}
else {
    $scratchDb = 'telemetry_test'
    $migrationOk = $true
    & $psql.Source '-v' 'ON_ERROR_STOP=1' '-d' 'postgres' '-q' '-c' ("drop database if exists $scratchDb with (force)")
    if ($LASTEXITCODE -ne 0) { $migrationOk = $false }
    if ($migrationOk) {
        & $psql.Source '-v' 'ON_ERROR_STOP=1' '-d' 'postgres' '-q' '-c' ("create database $scratchDb")
        if ($LASTEXITCODE -ne 0) { $migrationOk = $false }
    }
    if ($migrationOk) {
        foreach ($migration in (Get-ChildItem -LiteralPath 'Server/supabase/migrations' -Filter '*.sql' | Sort-Object Name)) {
            Write-Host ('  applying ' + $migration.Name) -ForegroundColor DarkGray
            & $psql.Source '-v' 'ON_ERROR_STOP=1' '-d' $scratchDb '-q' '-f' $migration.FullName
            if ($LASTEXITCODE -ne 0) { $migrationOk = $false; break }
        }
    }
    if ($migrationOk) {
        & $psql.Source '-v' 'ON_ERROR_STOP=1' '-d' $scratchDb '-f' 'Server/supabase/tests/migrations_test.sql'
        if ($LASTEXITCODE -ne 0) { $migrationOk = $false }
    }
    if ($migrationOk) {
        Write-Host 'PASSED: Migration parity' -ForegroundColor Green
    }
    else {
        Write-Host 'FAILED: Migration parity' -ForegroundColor Red
        $failed += 'Migration parity'
    }
}

# -Snapshots renders the canonical UI screens with the real OpenGL renderer (the
# headless gates cannot see pixels) and sanity-checks the PNGs. Off by default:
# it opens a window and is slower than every other gate together. `--fixed-fps 60` is
# deliberate: with a wall-clock delta the shots are not reproducible, so they cannot be
# compared against a baseline with `python Tools/compare_snapshots.py`.
if ($Snapshots) {
    Write-Host ''
    Write-Host '=== UI snapshots (rendered) ===' -ForegroundColor Cyan
    $snapArgs = @('--audio-driver', 'Dummy', '--position', '-4000,-4000', '--fixed-fps', '60', '--path', '.', 'res://Tools/snapshot_runner.tscn')
    $snap = Start-Process -FilePath $godotExe -ArgumentList $snapArgs -NoNewWindow -Wait -PassThru
    if ($snap.ExitCode -ne 0) {
        Write-Host ('FAILED (exit ' + $snap.ExitCode + '): UI snapshots') -ForegroundColor Red
        $failed += 'UI snapshots'
    }
    else {
        Write-Host 'PASSED: UI snapshots (reports/ui-snapshots/)' -ForegroundColor Green
    }
}

# -Review is the optional second-pass diff review. It is deliberately not one of the
# CI gates: CI posts the same report as a pull-request comment, while -Review (with
# --strict) fails locally on the high-signal rules so a branch can be fixed first.
if ($Review) {
    Write-Host ''
    Write-Host '=== Second-pass review (-Review) ===' -ForegroundColor Cyan
    $reviewArgs = @('--headless', '--path', '.', '--script', 'res://Tools/review_diff.gd', '--', '--base', 'origin/main', '--strict')
    $review = Start-Process -FilePath $godotExe -ArgumentList $reviewArgs -NoNewWindow -Wait -PassThru
    if ($review.ExitCode -ne 0) {
        Write-Host ('FAILED (exit ' + $review.ExitCode + '): Second-pass review') -ForegroundColor Red
        $failed += 'Second-pass review'
    }
    else {
        Write-Host 'PASSED: Second-pass review' -ForegroundColor Green
    }
}

Write-Host ''
if ($skipped.Count -gt 0) {
    Write-Host ('PRE-FLIGHT SKIPPED (missing tool, CI runs them): ' + ($skipped -join ', ')) -ForegroundColor Yellow
}
if ($failed.Count -gt 0) {
    Write-Host ('PRE-FLIGHT FAILED: ' + ($failed -join ', ')) -ForegroundColor Red
    exit 1
}

if ($skipped.Count -gt 0) {
    Write-Host ('PRE-FLIGHT PASSED: every gate that could run is green (' + $skipped.Count + ' skipped).') -ForegroundColor Green
    exit 0
}

Write-Host 'PRE-FLIGHT PASSED: every gate is green.' -ForegroundColor Green
exit 0
