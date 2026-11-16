# AGENTS.md

## Engine & Environment
- Engine: **Godot 4.6** (GDScript 2.0).
- Never use Godot 3 syntax (`yield`, `KinematicBody2D`, `Spatial`, string-based `connect()`). Use `await`, `CharacterBody2D`/`CharacterBody3D`, and `signal_name.connect(_on_handler)`.
- The project uses an **EventBus** autoload for global signals. Use it instead of creating hard references between unrelated nodes.

## Project Map
- `res://Core/` — Core game loops and base classes.
- `res://Data/` — Game data, resources, and configuration.
- `res://Managers/` — Global game managers.
- `res://Scenes/` — Game scenes (`.tscn`), UI, and related assets.
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

## Verification
- After editing any `.gd` file, check VS Code workspace diagnostics (Godot LSP) and fix all compiler/type errors at the root cause before finishing. Never suppress warnings with `@warning_ignore`.