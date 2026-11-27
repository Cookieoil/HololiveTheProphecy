# AGENTS.md

## Engine & Environment
- Engine: **Godot 4.7** (GDScript 2.0).
- Never use Godot 3 syntax (`yield`, `KinematicBody2D`, `Spatial`, string-based `connect()`). Use `await`, `CharacterBody2D`/`CharacterBody3D`, and `signal_name.connect(_on_handler)`.
- The project uses an **EventBus** autoload for global signals. Use it instead of creating hard references between unrelated nodes.

## Project Map
- `res://Core/` — Core game loops and base classes, including `GameUI.gd` (the abstract UI contract `BattleScene` implements).
- `res://Data/` — Game data, resources, and configuration.
- `res://Managers/` — Global game managers (`EventBus`, `ColorUtils`, `GameManager`).
- `res://Scenes/` — All UI, flat, one level deep (the old `GameUI/GraphicalUI` nesting is gone): `BattleScene/` (main scene + `Assets/`), `BattleUnit/`, `Cards/`, `HUD/`, `Textures/`.
- `res://Scenes/HUD/DebugMenuPopup.gd` — tester-only tool palette behind the `Debug` button / `F1` (card overflow spawns, resources, unit HP/status/Moxie, wave tools). It is view-only: it emits `debug_command_requested`, and `GameManager._handle_debug_command()` applies each tool as a `"debug"` action inside the normal player-action loop, so a debug tool can never desync the turn machine. Its header is a drag handle, so the panel can be moved off whatever is being inspected.
- `res://Shaders/` — Shared shaders (`FakeCard3D.gdshader`, preloaded by the card UI).
- `res://Skills/` — Ability and skill logic.
- `res://Tools/` — Editor tools, Python scripts, and utilities.

## Code Navigation (read this before opening files)
- **`Docs/CODEBASE_MAP.md` is the generated overview — read it first.** It is deliberately small: section 1 lists every game script, section 2 every test (`class_name`, size, role), section 3 lists every `EventBus` signal with its emitters and listeners, section 4 maps scenes to scripts, and section 5 lists the shape and keys of every JSON data file.
- **Per-script detail lives in its own page:** `Docs/map/<path>.md` (e.g. `Docs/map/Scenes/Cards/CardUI.md`) carries signals, constants, exports, onready nodes and the public API with line ranges, plus `Uses` / `Used by`. Scene pages (`*.scene.md`) carry the node tree, so `@onready` paths can be checked without opening the `.tscn`.
- **Find a symbol instead of grepping sources:** `rg -n '^get_effective_value\t' Docs/symbols.tsv` returns `path:start-end` in a single line; drop the `^name\t` anchor to search loosely.
- **Read only the range the index gives you** (`Core/Card.gd:74-75`), never a whole file to find one function.
- **All of `Docs/` is generated** by `Tools/gen_code_index.gd` (the parsing lives in `Tools/CodeIndexParser.gd`) — never hand-edit it. Regenerate after changing any first-party script, scene or data file:
  `godot --headless --path . --script res://Tools/gen_code_index.gd` (or `pwsh -File Tools/preflight.ps1 -FixIndex`).
- **Staleness and correctness are a gate:** `Tools/check_navigation.gd` re-checks the committed set against the sources (declaration coverage, line ranges, links, scenes, signals, data), exercises the generator in a scratch directory (`res://reports/navigation-test/`) and prints a read-cost benchmark. `Tools/preflight.ps1` runs it (skip with `-SkipIndexCheck`) and so does the CI `project` job, so a forgotten regeneration fails the build instead of leaving a stale map behind. `-- --benchmark` prints only the cost report.
- **The parser is unit tested:** `GDTest/CodeIndexTest.gd` locks in the tricky cases with inline fixtures — wrapped signatures, header-doc detection, enum forms, function ranges, `.tscn` attributes and node depths, JSON shapes, dependency scanning.
- The index walks `res://` subfolders only: `addons/`, `Trash/`, `bin/`, `reports/`, `.godot/` and files sitting directly in the project root are ignored, which keeps the output identical on every checkout.

## Strict Coding Rules
- **100% Static Typing:** Every variable, parameter, and function return MUST have explicit types (`var speed: float = 200.0`, `func take_damage(amount: int) -> void:`). Untyped declarations are compiler errors.
- **Strict Warning Compliance:** `project.godot` has `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`, and `missing_await` set to **Error (2)**. Ensure all code compiles without warnings.
- **Signal Up, Call Down:** Child nodes must NEVER call `get_parent()` or use absolute paths to mutate parent state. Emit typed signals upward; pass child references via `@export` or `@onready`.
- **No Timer Hacks:** Never use `await get_tree().process_frame` or `create_timer()` to mask initialization race conditions. Fix node readiness order at the root cause (use `@onready` or `call_deferred`).
- **Scene Safety:** Prefer creating/editing `.gd` scripts over hand-editing complex `.tscn` files. Never invent `uid://` strings; let the Godot Editor assign UIDs.

## Code Organization & Style (GDScript)
- **Regions:** Organize all classes using `#region` and `#endregion` tags in the following exact order:
  1. `#region Signals`
  2. `#region Enums`
  3. `#region Constants`
  4. `#region Exports`
  5. `#region Public Variables`
  6. `#region Private Variables`
  7. `#region Onready Variables`
  8. `#region Lifecycle Methods` (e.g., `_ready`, `_process`)
  9. `#region Public Methods`
  10. `#region Private Methods`
  11. `#region Signal Handlers`
- **Naming Conventions:**
  - Classes/Nodes: `PascalCase`
  - Functions & Variables: `snake_case`
  - Constants: `UPPER_SNAKE_CASE`
  - Signals: `snake_case` (past tense, e.g., `health_depleted`)
  - Private variables/functions: prefix with `_` (e.g., `_internal_counter`)
- **Godot Annotations:** Always use `@export` for inspector variables and `@onready` for node references. Place them under their respective regions.

## Game Data Pipeline
- **`res://Data/json/` is the single source of truth.** The game reads `skills.json`, `allies.json`, `enemies.json`, `waves.json`, `config.json` and `features.json` at runtime through `Core/DataLoader.gd` (`FileAccess` + `JSON.parse_string`).
- **Feature flags are a JSON edit too.** Add an entry to `res://Data/json/features.json`: `{"flags": {"my_experiment": {"enabled": true, "rollout_percent": 25, "description": "what is being tried"}}}`. `enabled` is the kill switch, `rollout_percent` is the share of runs (bucketed on the run seed, so an assignment is reproducible and needs no player identifier), and the description is required — an undocumented experiment is one nobody can revisit. **Only those three keys are read**: an unknown key (a `rollout_pct` typo) is a data-gate error, because it would otherwise read as "rollout unset" and silently roll out to 100%. Read it with `FeatureFlags.is_active(state.flags, "my_experiment")`, force one for a local test through `BattleScene.flag_overrides`, and read the result under "Staged feature flags" in `python Tools/analyze_telemetry.py` (or `v_flag_cohorts` on the server — both scope the control group to the same `balance_hash`). Unknown flags are always off, so a typo cannot switch something on.
- **Never read `.xlsx` at runtime.** `res://Data/xlsx/game_data.xlsx` is a bulk-entry authoring tool only; `Tools/xlsx_reader.gd` + `Tools/dataBuilder.gd` convert it to JSON.
- **Quick balancing is a JSON edit.** Change numbers/strings in `res://Data/json/` directly; keep enum values as readable strings (`"deal_damage"`, `"pick_n_enemy"`, `"card_value"`, ...) — never numeric ordinals.
- **Effects live inside their skill.** `skills.json` embeds an `effects` array per skill (base effects first, then merged). `skill_id` is not repeated inside the effect object.
- **Regenerating JSON is explicit**, because the workbook is stale compared to hand/AI edits:
  - Editor: `Project -> Tools -> Export game_data.xlsx to JSON`
  - CLI: `godot --headless --path . --script res://Tools/export_xlsx_to_json.gd`
  - Validate: `godot --headless --path . "res://Tools/validator.tscn"` — checks the raw JSON schema/semantics, the `DataLoader` path and the workbook, then exits `1` on any error. Add `-- --json-only` to skip the workbook or `-- --strict` to also fail on warnings.
- **CI gates** (`.github/workflows/validate_game_data.yml`) run on every pull request (deliberately no `paths:` filter — a required check that never runs would block every PR) and on every push to `main`, split into four jobs:
  - `version` — resolves the Godot version from `project.godot` once, for the other jobs.
  - `validate` — the data gate: the validator with `--strict`, so any error **or warning** fails the build, plus the anti-slop lint (`python3 Tools/line_godot_slop.py --strict`). Keep this job id and its missing `name:`; `main` requires the `validate` status check.
  - `project` — compiles every script, verifies the generated symbol index in `Docs/` still matches the sources, renders the UI snapshots, and runs the gdUnit4 suite.
  - `review` — the second-pass review: `Tools/review_diff.gd` summarises the diff and posts it as one sticky pull-request comment. Advisory only (it never blocks a merge and never fails a fork build, which gets a read-only token); the branch-protection blockers stay `validate` and `Scripts and tests`.
  Errors/warnings are annotated inline on the PR, summarised on the job page, and the JUnit/HTML report is kept as the `gdunit4-reports` artifact. A red job means bad game data or a broken script — never merge past it.
- **Local pre-flight before pushing** (the same gates CI runs, all headless):
  - Validate data: `godot --headless --path . "res://Tools/validator.tscn" -- --strict`
  - Compile every script: `godot --headless --path . --script res://Tools/check_scripts.gd`
  - Symbol index is current: `godot --headless --path . --script res://Tools/check_navigation.gd`
  - Unit tests: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://GDTest -c --ignoreHeadlessMode`
  - Anti-slop lint: `python Tools/line_godot_slop.py --strict` — bans `create_timer()`, frame pumps and upward tree walks, keeps `Core/` pure logic, and ratchets four metrics against `Tools/slop_baseline.json`: file lines (900), function lines (80), a function's branch score (1 + one point per `if`/`elif`/`for`/`while`/`match`, 12) and `get_parent()` calls per file (0). Baseline entries may only shrink — split the class, extract a helper or flatten the branches instead of raising one — and `--strict` is what makes a stale entry fail rather than warn.
  - One-shot on Windows: `pwsh -File Tools/preflight.ps1` runs `--import` plus all five gates and exits `1` on any red gate. Add `-FixIndex` to regenerate `Docs/` before the gates run, or `-SkipIndexCheck` to leave the generated index alone while iterating.
  - **See the UI instead of guessing it:** `godot --audio-driver Dummy --position -4000,-4000 --path . res://Tools/snapshot_runner.tscn` (or `pwsh -File Tools/preflight.ps1 -Snapshots`) mounts a seeded battle with the real OpenGL renderer, writes the canonical screens to `reports/ui-snapshots/` plus a `manifest.json`, and sanity-checks each PNG (size, non-blank). Headless runs use the dummy renderer, which rasterises nothing, so a layout or shader regression is invisible to the five gates. CI runs it under `xvfb` and uploads the `ui-snapshots` artifact.
  - **Deterministic replays:** `BattleScene.fixed_seed_override` pins the deal, the rolls and the enemy intents; `BattleScene.consent_path_override` points the telemetry disclosure at a throwaway file so tooling never overwrites a real `user://` answer.
  - **Second-pass review before opening a PR:** commit first, then run `godot --headless --path . --script res://Tools/review_diff.gd -- --base origin/main` — it diffs the branch against the base, so it reviews what is committed. It prints a diff-scoped report (change summary, new public API, missing tests, banned patterns, size-ceiling files). Run it with `--strict` to fail on the high-signal rules (`undocumented_api`, `core_purity`) and fix those before pushing — `untested_change` and the rest stay advisory, because this repo names suites by behaviour (a filename match would be wrong as often as it is right); `pwsh -File Tools/preflight.ps1 -Review` does the same. CI (`review` job) posts the report as a sticky comment on every pull request.
  - **Windows gotcha:** Steam's `godot.exe` is a GUI-subsystem binary, so PowerShell never waits for it and `$LASTEXITCODE` stays empty (a gate can look "failed" while it actually passed). Launch each gate with `Start-Process -Wait -PassThru` and judge `.ExitCode` — that is exactly what `Tools/preflight.ps1` does.
  - **Windows gotcha (detached runs):** a detached `pwsh -File Tools/preflight.ps1` inherits the *session* PATH, so after prepending the user-space toolchain (which drops Steam's entry) it exits at once with `Godot executable not found: godot` — pass `-Godot` explicitly. And `Start-Process -ArgumentList` joins array elements with spaces **without quoting them**, so that same path silently truncates at the space (`Godot executable not found: C:\Program`); give the path element its own quotes, e.g. `$g = '"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.exe"'; Start-Process pwsh -ArgumentList '-NoProfile','-File','Tools/preflight.ps1','-Godot',$g`.
- **Never commit `reports/`** (gdUnit4 output) or Godot's `~*` atomic-write temp files; both are gitignored.
- **Branch protection**: `main` requires **both** the `validate` and `Scripts and tests` status checks (confirmed with `gh api repos/:owner/:repo/branches/main/protection`), so never rename either job id — and keep `validate` without a `name:` so its check context stays exactly `validate`. A required check must be *reported* before `main` accepts a commit, so a direct `git push origin main` of new commits is **rejected** (`remote: error: GH006: Protected branch update failed ... 2 of 2 required status checks are expected`) — the checks cannot exist for a commit that has never been pushed, and admins cannot bypass the rule (`enforce_admins: true`) while force pushes and deletions are disabled. Land work through a branch and a pull request instead: push the branch, let `validate` and `Scripts and tests` run on the PR, then merge once both are green — no review is required and the branch need not be up to date with base (`strict: false`), so nothing else blocks the merge. Merge with `--merge` rather than `--squash` so each Conventional Commit stays a separate commit on `main` (linear history is not required), and prefer a pull request for game-data changes so the gates run before the change lands.

- **JSON numbers parse as `float`.** Always coerce with the typed helpers (`_to_int` / `_get_int`, `int(float_value)`) instead of `int(dict["key"])`, which is a compile error under `unsafe_call_argument`.

## Verification
- After editing any `.gd` file, check VS Code workspace diagnostics (Godot LSP) and fix all compiler/type errors at the root cause before finishing. Never suppress warnings with `@warning_ignore`.