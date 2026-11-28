<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/SnapshotRunner.gd` extends `Node`

`395` lines · [back to the map](../../CODEBASE_MAP.md)

> Renders the canonical battle screens to PNGs for the "align visually" loop. Every normal gate is headless, and Godot's headless display driver is the dummy rend…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L34 `SCENE_PATH: String`
- L35 `OUTPUT_DIR: String = "res://reports/ui-snapshots"`
- L36 `MANIFEST_NAME: String = "manifest.json"`
- L38 `CONSENT_FILE_NAME: String = "_snapshot_consent.json"` — Throwaway consent file: a capture must never touch the real `user://` answer.
- L41 `SEED: int = 424242` — A fixed seed makes the dealt hand, the rolls and the enemy intents identical on every machine, so two captures of the same code are comparable.
- L44 `SETTLE_FRAMES: int = 45` — Frames to wait after a state changes so layout and the deal animation have settled before the pixels are read.
- L46 `MAX_WAIT_FRAMES: int = 600` — Hard cap on waiting for a state, so a broken build cannot hang CI forever.
- L48 `WINDOW_SIZE: Vector2i = Vector2i(1280, 720)` — The project window size the snapshots are taken at.
- L51 `MIN_DISTINCT_COLORS: int = 8` — A blank frame is dummy-renderer output; this many distinct sampled colours proves the real renderer drew the screen.
- L52 `COLOR_SAMPLE_STEP: int = 24`
- L55 `EFFECT_SETTLE_FRAMES: int = 12` — Short settles for the shots that photograph something mid-animation (a cast ripple, a card in flight). At 60 frames a second these are fractions of a second by…
- L56 `FLIGHT_SETTLE_FRAMES: int = 16`
- L59 `FLIGHT_STAGGER: float = 0.08` — Stagger between two cards leaving the deck, in seconds, for the deal-in shot. Chosen so one frame catches several different points of the flight (see `_capture_…
- L60 `ARG_OUTPUT_DIR: String = "--output-dir"`

State:
- L65 `_output_abs: String = ""`
- L66 `_shots: Array[Dictionary] = []`
- L67 `_failures: PackedStringArray = PackedStringArray()`

Private:
- L71-78 `_ready`
- L84-89 `_output_dir`
- L91-140 `_capture`
- L147-165 `_capture_orb_states`
- L171-181 `_capture_cast_effects`
- L187-202 `_capture_card_flight`
- L205-217 `_open_scene`
- L220-222 `_wait_frames`
- L225-226 `_settle`
- L229-234 `_wait_for_consent`
- L237-242 `_wait_for_board`
- L245-248 `_board_is_ready`
- L251-256 `_show_ultimate_callout`
- L260-269 `_unit_uis`
- L274-280 `_orbs`
- L283-287 `_orb_for`
- L291-294 `_fill_moxie`
- L299-306 `_callout_data`
- L310-340 `_shot`
- L345-354 `_distinct_colors`
- L357-363 `_file_size`
- L366-378 `_write_manifest`
- L381-383 `_fail`
- L386-393 `_finish`

Uses: BattleScene, CardUI, MoxieOrbUI, Unit, UnitUI
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://reports/ui-snapshots

