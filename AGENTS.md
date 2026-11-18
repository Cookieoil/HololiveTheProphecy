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
- `res://Scenes/HUD/DebugMenuPopup.gd` — tester-only tool palette behind the `Debug` button / `F1` (card overflow spawns, resources, unit HP/status/Moxie, wave tools). It is view-only: it emits `debug_command_requested`, and `GameManager._handle_debug_command()` applies each tool as a `"debug"` action inside the normal player-action loop, so a debug tool can never desync the turn machine.
- `res://Shaders/` — Shared shaders (`FakeCard3D.gdshader`, preloaded by the card UI).
- `res://Skills/` — Ability and skill logic.
- `res://Tools/` — Editor tools, Python scripts, and utilities.

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
- **`res://Data/json/` is the single source of truth.** The game reads `skills.json`, `allies.json`, `enemies.json`, `waves.json`, and `config.json` at runtime through `Core/DataLoader.gd` (`FileAccess` + `JSON.parse_string`).
- **Never read `.xlsx` at runtime.** `res://Data/xlsx/game_data.xlsx` is a bulk-entry authoring tool only; `Tools/xlsx_reader.gd` + `Tools/dataBuilder.gd` convert it to JSON.
- **Quick balancing is a JSON edit.** Change numbers/strings in `res://Data/json/` directly; keep enum values as readable strings (`"deal_damage"`, `"pick_n_enemy"`, `"card_value"`, ...) — never numeric ordinals.
- **Effects live inside their skill.** `skills.json` embeds an `effects` array per skill (base effects first, then merged). `skill_id` is not repeated inside the effect object.
- **Regenerating JSON is explicit**, because the workbook is stale compared to hand/AI edits:
  - Editor: `Project -> Tools -> Export game_data.xlsx to JSON`
  - CLI: `godot --headless --path . --script res://Tools/export_xlsx_to_json.gd`
  - Validate: `godot --headless --path . "res://Tools/validator.tscn"` — checks the raw JSON schema/semantics, the `DataLoader` path and the workbook, then exits `1` on any error. Add `-- --json-only` to skip the workbook or `-- --strict` to also fail on warnings.
- **CI gates** (`.github/workflows/validate_game_data.yml`) run on every pull request (deliberately no `paths:` filter — a required check that never runs would block every PR) and on every push to `main`, split into three jobs:
  - `version` — resolves the Godot version from `project.godot` once, for the other jobs.
  - `validate` — the data gate: the validator with `--strict`, so any error **or warning** fails the build. Keep this job id and its missing `name:`; `main` requires the `validate` status check.
  - `project` — compiles every script and runs the gdUnit4 suite.
  Errors/warnings are annotated inline on the PR, summarised on the job page, and the JUnit/HTML report is kept as the `gdunit4-reports` artifact. A red job means bad game data or a broken script — never merge past it.
- **Local pre-flight before pushing** (the same three gates CI runs, all headless):
  - Validate data: `godot --headless --path . "res://Tools/validator.tscn" -- --strict`
  - Compile every script: `godot --headless --path . --script res://Tools/check_scripts.gd`
  - Unit tests: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://GDTest -c --ignoreHeadlessMode`
  - One-shot on Windows: `pwsh -File Tools/preflight.ps1` runs `--import` plus all three gates and exits `1` on any red gate.
  - **Windows gotcha:** Steam's `godot.exe` is a GUI-subsystem binary, so PowerShell never waits for it and `$LASTEXITCODE` stays empty (a gate can look "failed" while it actually passed). Launch each gate with `Start-Process -Wait -PassThru` and judge `.ExitCode` — that is exactly what `Tools/preflight.ps1` does.
- **Never commit `reports/`** (gdUnit4 output) or Godot's `~*` atomic-write temp files; both are gitignored.
- **Branch protection**: `main` requires **both** the `validate` and `Scripts and tests` status checks (confirmed with `gh api repos/:owner/:repo/branches/main/protection`), so never rename either job id — and keep `validate` without a `name:` so its check context stays exactly `validate`. Direct pushes are permitted (`pr_required: false`) and the branch need not be up to date with base (`strict: false`), but admins cannot bypass the rules (`enforce_admins: true`) and force pushes and deletions are disabled. Prefer a pull request for game-data changes so the gates run before the change lands.

- **JSON numbers parse as `float`.** Always coerce with the typed helpers (`_to_int` / `_get_int`, `int(float_value)`) instead of `int(dict["key"])`, which is a compile error under `unsafe_call_argument`.

## Verification
- After editing any `.gd` file, check VS Code workspace diagnostics (Godot LSP) and fix all compiler/type errors at the root cause before finishing. Never suppress warnings with `@warning_ignore`.