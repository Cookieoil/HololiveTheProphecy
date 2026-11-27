<!--
Keep this to one screen. The gates (`validate`, `Scripts and tests`) carry the detail;
this template exists so a reader sees the blast radius, the rollback and the proof
without opening the diff. Paste results, do not describe them. Delete a section only if
it truly does not apply.
-->

## What & why
<!-- One or two sentences: the behaviour change, not the file list. -->

## Blast radius
<!-- `godot --headless --path . --script res://Tools/review_diff.gd -- --base origin/main`
     prints the tier; the fan-in comes from `Docs/map/<path>.md` -> `Used by`. -->

- [ ] **Trunk** — `Core/`, `Managers/`, the EventBus, `Data/json/config.json`, `project.godot`, CI, or any script the map shows many others depend on. A human reads every line.
- [ ] **Leaf** — an isolated scene/component, one skill or data entry. Skim it, and lean on the gates plus the proof below.

Touched: `…`

## Feature gate & rollback
- Flag: `<name in Data/json/features.json>`, rollout `…%` — or `N/A (bugfix / refactor, no new behaviour)`
- With the flag off, the previous behaviour is unchanged: `yes / no / N/A`
- Rollback: flip `enabled` to `false` (kill switch) — or revert commit `…`

## Proof (paste the output)
- [ ] `pwsh -File Tools/preflight.ps1` — every gate green (paste the last line)
- [ ] Deterministic replay: seed `…` reproduces the change
- [ ] Tests added/changed: `<GDTest/…>` asserting `<the behaviour>`
- [ ] UI proof — required if `Scenes/` or `Shaders/` changed: `reports/ui-snapshots/` before/after
- [ ] Data change: `godot --headless --path . "res://Tools/validator.tscn" -- --strict`

## Confidence & residual risk
- **Confidence:** high / medium / low
- **Sharpest risk for the reviewer to eyeball:** <!-- one line, the edge case you are least sure of -->
