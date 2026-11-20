<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/check_spine_runtime.gd` extends `SceneTree`

`142` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless link and compatibility gate for the spine-godot GDExtension. Proves three things: 1. the runtime in `bin/` loaded and exposes the Spine classes the gam…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L25 `REQUIRED_CLASSES: PackedStringArray = [` — Classes the game scripts touch through `ClassDB` or dynamic `call()`.
- L33 `RIG_DIR: String = "res://Scenes/BattleUnit/Spine/"` — Folder scanned for `<char_id>/<char_id>.tres` rigs.
- L36 `REQUIRED_SPINE_VERSION: String = "4.3"` — Major.minor of the spine-godot runtime in `bin/`. A rig exported from any other Spine version is rejected by the runtime at load time.
- L38 `REQUIRED_BONES: PackedStringArray` — Combat-rig contract (task I-1). Reported, not enforced, until the rigs land.
- L39 `REQUIRED_EVENTS: PackedStringArray = ["event_vfx_spawn", "event_hit_frame"]`

Private:
- L43-71 `_initialize`
- L75-80 `_check_classes`
- L83-96 `_collect_rigs`
- L99-140 `_check_rig`

Uses: —
Used by: —
Loads: res://Scenes/BattleUnit/Spine/

