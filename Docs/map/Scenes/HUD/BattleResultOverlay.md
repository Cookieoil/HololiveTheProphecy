<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleResultOverlay.gd` — `class_name BattleResultOverlay` extends `Control`

`259` lines · [back to the map](../../../CODEBASE_MAP.md)

> End-of-battle cutscene: a flat, deliberately calm Victory / Defeat banner. The battle scene is the only scene, so the result screen is built in code and mounted…

Sections: Signals · Constants · Exports · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L27 `restart_requested` — The player pressed "Play Again". The owner decides how to restart the battle (BattleScene reloads the battle scene), so this overlay never restarts itself.

Constants:
- L31 `PLACEHOLDER_VICTORY_ICON: Texture2D`
- L32 `PLACEHOLDER_DEFEAT_ICON: Texture2D`
- L36 `EMBLEM_SIZE: float = 96.0` — Emblem size, and how far the title laps over its bottom edge. The negative separation is what makes the two read as one mark instead of a stacked list.
- L37 `ICON_TITLE_OVERLAP: int = -18`
- L40 `BUTTON_ROW_GAP: int = 30` — Space between that mark and the button below it.
- L42 `TITLE_FONT_SIZE: int = 44`
- L43 `BUTTON_MIN_SIZE: Vector2 = Vector2(220.0, 44.0)`
- L44 `BUTTON_FONT_SIZE: int = 16`
- L45 `BUTTON_CORNER_RADIUS: int = 3`
- L49 `CONTENT_FADE_TIME: float = 0.25` — Cutscene pacing. Short on purpose: it plays after the last hit, so it must not make a finished battle feel slow.
- L50 `CONTENT_IN_TIME: float = 0.32`
- L51 `BUTTON_IN_TIME: float = 0.18`
- L52 `CONTENT_SCALE_FROM: float = 0.96`
- L55 `VICTORY_TITLE: Color = Color(0.92, 0.80, 0.48, 1.0)` — SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
- L56 `VICTORY_EMBLEM_TINT: Color = Color(0.96, 0.88, 0.66, 1.0)`
- L58 `DEFEAT_TITLE: Color = Color(0.86, 0.44, 0.44, 1.0)`
- L59 `DEFEAT_EMBLEM_TINT: Color = Color(0.80, 0.62, 0.62, 1.0)`
- L61 `TITLE_TEXT_VICTORY: String = "VICTORY"`
- L62 `TITLE_TEXT_DEFEAT: String = "DEFEAT"`
- L66 `BUTTON_TEXT: String = "Play Again"` — The button is the one piece of chrome left: a solid muted slab (no border, no glow) so "Play Again" stays obviously clickable on its own.
- L67 `BUTTON_TEXT_COLOR: Color = Color(0.07, 0.08, 0.11, 1.0)`

Exports:
- L72 `victory_icon: Texture2D = PLACEHOLDER_VICTORY_ICON` — Placeholder emblem for a won battle (swapped for hand-drawn art later).
- L74 `defeat_icon: Texture2D = PLACEHOLDER_DEFEAT_ICON` — Placeholder emblem for a lost battle (swapped for hand-drawn art later).

State:
- L78 `_center: CenterContainer`
- L79 `_column: VBoxContainer`
- L80 `_mark: VBoxContainer`
- L81 `_emblem: TextureRect`
- L82 `_title: Label`
- L83 `_button_row: CenterContainer`
- L84 `_restart_button: Button`
- L85 `_cutscene: Tween`
- L86 `_is_showing: bool = false`

Public API:
- L105-129 `play_cutscene(victory: bool) -> void` — Plays the cutscene for a finished battle and keeps the banner on screen until the player presses "Play Again". Callers may `await` it.
- L133-134 `is_showing() -> bool` — True while the result banner owns the screen.

Private:
- L91-99 `_init`
- L138-152 `_build_ui`
- L156-179 `_build_mark`
- L182-199 `_build_button_row`
- L203-212 `_configure`
- L217-222 `_apply_button_style`
- L225-236 `_button_style`
- L240-242 `_sync_mark_pivot`
- L245-248 `_kill_cutscene`
- L253-257 `_on_restart_pressed`

Uses: BattleScene
Used by: GDTest/BattleEndTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

