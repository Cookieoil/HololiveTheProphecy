<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/SnapshotRunner.gd` extends `Node`

`250` lines · [back to the map](../../CODEBASE_MAP.md)

> Renders the canonical battle screens to PNGs for the "align visually" loop. Every normal gate is headless, and Godot's headless display driver is the dummy rend…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L27 `SCENE_PATH: String`
- L28 `OUTPUT_DIR: String = "res://reports/ui-snapshots"`
- L29 `MANIFEST_NAME: String = "manifest.json"`
- L31 `CONSENT_FILE_NAME: String = "_snapshot_consent.json"` — Throwaway consent file: a capture must never touch the real `user://` answer.
- L34 `SEED: int = 424242` — A fixed seed makes the dealt hand, the rolls and the enemy intents identical on every machine, so two captures of the same code are comparable.
- L37 `SETTLE_FRAMES: int = 45` — Frames to wait after a state changes so layout and the deal animation have settled before the pixels are read.
- L39 `MAX_WAIT_FRAMES: int = 600` — Hard cap on waiting for a state, so a broken build cannot hang CI forever.
- L41 `WINDOW_SIZE: Vector2i = Vector2i(1280, 720)` — The project window size the snapshots are taken at.
- L44 `MIN_DISTINCT_COLORS: int = 8` — A blank frame is dummy-renderer output; this many distinct sampled colours proves the real renderer drew the screen.
- L45 `COLOR_SAMPLE_STEP: int = 24`

State:
- L49 `_output_abs: String = ""`
- L50 `_shots: Array[Dictionary] = []`
- L51 `_failures: PackedStringArray = PackedStringArray()`

Private:
- L55-62 `_ready`
- L66-108 `_capture`
- L111-123 `_open_scene`
- L126-128 `_wait_frames`
- L131-132 `_settle`
- L135-140 `_wait_for_consent`
- L143-148 `_wait_for_board`
- L151-154 `_board_is_ready`
- L157-162 `_show_ultimate_callout`
- L165-195 `_shot`
- L200-209 `_distinct_colors`
- L212-218 `_file_size`
- L221-233 `_write_manifest`
- L236-238 `_fail`
- L241-248 `_finish`

Uses: BattleScene
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://reports/ui-snapshots

