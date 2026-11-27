<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/SnapshotRunner.gd` extends `Node`

`242` lines · [back to the map](../../CODEBASE_MAP.md)

> Renders the canonical battle screens to PNGs for the "align visually" loop. Every normal gate is headless, and Godot's headless display driver is the dummy rend…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L27 `SCENE_PATH: String`
- L28 `OUTPUT_DIR: String = "res://reports/ui-snapshots"`
- L29 `MANIFEST_NAME: String = "manifest.json"`
- L31 `CONSENT_FILE_NAME: String = "_snapshot_consent.json"` — Throwaway consent file: a capture must never touch the real `user://` answer.
- L34 `SEED: int = 424242` — A fixed seed makes the dealt hand, the rolls and the enemy intents identical on every machine, so two captures of the same code are comparable.
- L36 `SETTLE_FRAMES: int = 12` — Frames to wait after a state changes so layout and animations have settled.
- L38 `MAX_WAIT_FRAMES: int = 600` — Hard cap on waiting for a state, so a broken build cannot hang CI forever.
- L40 `WINDOW_SIZE: Vector2i = Vector2i(1280, 720)` — The project window size the snapshots are taken at.
- L43 `MIN_DISTINCT_COLORS: int = 8` — A blank frame is dummy-renderer output; this many distinct sampled colours proves the real renderer drew the screen.
- L44 `COLOR_SAMPLE_STEP: int = 24`

State:
- L48 `_output_abs: String = ""`
- L49 `_shots: Array[Dictionary] = []`
- L50 `_failures: PackedStringArray = PackedStringArray()`

Private:
- L54-61 `_ready`
- L65-100 `_capture`
- L103-115 `_open_scene`
- L118-120 `_wait_frames`
- L123-124 `_settle`
- L127-132 `_wait_for_consent`
- L135-140 `_wait_for_board`
- L143-146 `_board_is_ready`
- L149-154 `_show_ultimate_callout`
- L157-187 `_shot`
- L192-201 `_distinct_colors`
- L204-210 `_file_size`
- L213-225 `_write_manifest`
- L228-230 `_fail`
- L233-240 `_finish`

Uses: BattleScene
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://reports/ui-snapshots

