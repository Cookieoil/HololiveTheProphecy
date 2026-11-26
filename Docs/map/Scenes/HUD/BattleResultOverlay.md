<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleResultOverlay.gd` — `class_name BattleResultOverlay` extends `Control`

`276` lines · [back to the map](../../../CODEBASE_MAP.md)

> End-of-battle cutscene: a flat, deliberately calm Victory / Defeat banner. The battle scene is the only scene, so the result screen is built in code and mounted…

Sections: Signals · Constants · Exports · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L26 `restart_requested` — The player pressed "Play Again". The owner decides how to restart the battle (BattleScene reloads the battle scene), so this overlay never restarts itself.

Constants:
- L30 `PLACEHOLDER_VICTORY_ICON: Texture2D`
- L31 `PLACEHOLDER_DEFEAT_ICON: Texture2D`
- L35 `CORNER_RADIUS: int = 0` — Square corners keep the button on the same surface as the debug menu and the hover tooltip slabs.
- L36 `ROW_SEPARATION: int = 12`
- L39 `EMBLEM_SIZE: float = 72.0` — Emblem (placeholder icon) size.
- L43 `ICON_TITLE_OVERLAP: int = -26` — How far the title laps over the emblem's bottom edge. Negative, so the two read as one mark instead of a stacked list.
- L45 `TITLE_FONT_SIZE: int = 42`
- L47 `BUTTON_MIN_SIZE: Vector2 = Vector2(220.0, 44.0)`
- L48 `BUTTON_FONT_SIZE: int = 16`
- L52 `BACKDROP_FADE_TIME: float = 0.25` — Cutscene pacing. Short on purpose: it plays after the last hit, so it must not make a finished battle feel slow.
- L53 `CONTENT_IN_TIME: float = 0.32`
- L54 `BUTTON_IN_TIME: float = 0.18`
- L55 `CONTENT_SCALE_FROM: float = 0.96`
- L58 `BACKDROP_COLOR: Color = Color(0.04, 0.05, 0.07, 0.80)` — SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
- L60 `VICTORY_TITLE: Color = Color(0.92, 0.80, 0.48, 1.0)`
- L61 `VICTORY_EMBLEM_TINT: Color = Color(0.96, 0.88, 0.66, 1.0)`
- L63 `DEFEAT_TITLE: Color = Color(0.86, 0.44, 0.44, 1.0)`
- L64 `DEFEAT_EMBLEM_TINT: Color = Color(0.80, 0.62, 0.62, 1.0)`
- L66 `TITLE_TEXT_VICTORY: String = "VICTORY"`
- L67 `TITLE_TEXT_DEFEAT: String = "DEFEAT"`
- L69 `BUTTON_TEXT: String = "Play Again"`
- L70 `BUTTON_FONT_COLOR: Color = Color(0.90, 0.92, 0.96, 1.0)`
- L71 `BUTTON_BG_NORMAL: Color = Color(0.14, 0.16, 0.21, 1.0)`
- L72 `BUTTON_BG_HOVER: Color = Color(0.20, 0.23, 0.29, 1.0)`
- L73 `BUTTON_BG_PRESSED: Color = Color(0.11, 0.13, 0.17, 1.0)`

Exports:
- L78 `victory_icon: Texture2D = PLACEHOLDER_VICTORY_ICON` — Placeholder emblem for a won battle (swapped for hand-drawn art later).
- L80 `defeat_icon: Texture2D = PLACEHOLDER_DEFEAT_ICON` — Placeholder emblem for a lost battle (swapped for hand-drawn art later).

State:
- L84 `_backdrop: ColorRect`
- L85 `_center: CenterContainer`
- L86 `_column: VBoxContainer`
- L87 `_mark: VBoxContainer`
- L88 `_emblem: TextureRect`
- L89 `_title: Label`
- L90 `_button_row: CenterContainer`
- L91 `_restart_button: Button`
- L92 `_cutscene: Tween`
- L93 `_is_showing: bool = false`

Public API:
- L112-139 `play_cutscene(victory: bool) -> void` — Plays the cutscene for a finished battle and keeps the banner on screen until the player presses "Play Again". Callers may `await` it.
- L143-144 `is_showing() -> bool` — True while the result banner owns the screen.

Private:
- L98-106 `_init`
- L148-187 `_build_ui`
- L193-216 `_build_mark`
- L220-230 `_configure`
- L234-239 `_apply_button_style`
- L242-253 `_button_style`
- L257-259 `_sync_column_pivot`
- L262-265 `_kill_cutscene`
- L270-274 `_on_restart_pressed`

Uses: BattleScene
Used by: GDTest/BattleEndTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

