<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/check_scripts.gd` extends `SceneTree`

`85` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless compile gate: loads every project GDScript outside the excluded folders, so a type error, a stale `class_name` or a bad annotation fails CI instead of…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L16 `EXCLUDED_DIRS: PackedStringArray = [` — Folders that are not part of the shipped game code (vendor, scratch, output).
- L22 `ROOT_DIR: String = "res://"`
- L23 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"`

Private:
- L27-51 `_initialize`
- L55-70 `_collect_scripts`
- L73-77 `_is_excluded`
- L80-83 `_repo_path`

Uses: —
Used by: —
Loads: res://.godot/, res://reports/, res://Trash/, res://

