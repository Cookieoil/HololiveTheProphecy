<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleResultOverlay.gd` — `class_name BattleResultOverlay` extends `Control`

`352` lines · [back to the map](../../../CODEBASE_MAP.md)

> End-of-battle cutscene: a flat, deliberately calm Victory / Defeat banner. The battle scene is the only scene, so the result screen is built in code and mounted…

Sections: Signals · Constants · Exports · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L22 `restart_requested` — The player pressed "Play Again". The owner decides how to restart the battle (BattleScene reloads the battle scene), so this overlay never restarts itself.

Constants:
- L26 `PLACEHOLDER_VICTORY_ICON: Texture2D`
- L27 `PLACEHOLDER_DEFEAT_ICON: Texture2D`
- L31 `PANEL_WIDTH: float = 420.0` — Slab metrics. Square corners and a 2px border keep it on the same surface as the debug menu and the hover tooltip slabs.
- L32 `PADDING: int = 26`
- L33 `BORDER_WIDTH: int = 2`
- L34 `CORNER_RADIUS: int = 0`
- L35 `ROW_SEPARATION: int = 12`
- L38 `EMBLEM_SIZE: float = 72.0` — Emblem (placeholder icon) size inside its framed socket.
- L39 `EMBLEM_FRAME_PADDING: int = 10`
- L41 `TITLE_FONT_SIZE: int = 42`
- L42 `SUBTITLE_FONT_SIZE: int = 15`
- L44 `BUTTON_MIN_SIZE: Vector2 = Vector2(220.0, 44.0)`
- L45 `BUTTON_FONT_SIZE: int = 16`
- L49 `BACKDROP_FADE_TIME: float = 0.25` — Cutscene pacing. Short on purpose: it plays after the last hit, so it must not make a finished battle feel slow.
- L50 `BANNER_IN_TIME: float = 0.32`
- L51 `BUTTON_IN_TIME: float = 0.18`
- L52 `BANNER_SCALE_FROM: float = 0.96`
- L55 `BACKDROP_COLOR: Color = Color(0.04, 0.05, 0.07, 0.80)` — SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
- L56 `PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)`
- L58 `VICTORY_BORDER: Color = Color(0.62, 0.54, 0.34, 1.0)`
- L59 `VICTORY_TITLE: Color = Color(0.92, 0.80, 0.48, 1.0)`
- L60 `VICTORY_EMBLEM_TINT: Color = Color(0.96, 0.88, 0.66, 1.0)`
- L62 `DEFEAT_BORDER: Color = Color(0.52, 0.28, 0.30, 1.0)`
- L63 `DEFEAT_TITLE: Color = Color(0.86, 0.44, 0.44, 1.0)`
- L64 `DEFEAT_EMBLEM_TINT: Color = Color(0.80, 0.62, 0.62, 1.0)`
- L66 `EMBLEM_FRAME_BG: Color = Color(0.10, 0.11, 0.15, 1.0)`
- L67 `TITLE_TEXT_VICTORY: String = "VICTORY"`
- L68 `TITLE_TEXT_DEFEAT: String = "DEFEAT"`
- L69 `SUBTITLE_TEXT_VICTORY: String = "All enemies have been defeated."`
- L70 `SUBTITLE_TEXT_DEFEAT: String = "Your party has fallen."`
- L71 `SUBTITLE_COLOR: Color = Color(0.78, 0.82, 0.88, 1.0)`
- L72 `DIVIDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.12)`
- L74 `BUTTON_TEXT: String = "Play Again"`
- L75 `BUTTON_FONT_COLOR: Color = Color(0.90, 0.92, 0.96, 1.0)`
- L76 `BUTTON_BG_NORMAL: Color = Color(0.14, 0.16, 0.21, 1.0)`
- L77 `BUTTON_BG_HOVER: Color = Color(0.20, 0.23, 0.29, 1.0)`
- L78 `BUTTON_BG_PRESSED: Color = Color(0.11, 0.13, 0.17, 1.0)`

Exports:
- L83 `victory_icon: Texture2D = PLACEHOLDER_VICTORY_ICON` — Placeholder emblem for a won battle (swapped for hand-drawn art later).
- L85 `defeat_icon: Texture2D = PLACEHOLDER_DEFEAT_ICON` — Placeholder emblem for a lost battle (swapped for hand-drawn art later).

State:
- L89 `_backdrop: ColorRect`
- L90 `_center: CenterContainer`
- L91 `_banner: PanelContainer`
- L92 `_banner_style: StyleBoxFlat`
- L93 `_emblem_frame: PanelContainer`
- L94 `_emblem: TextureRect`
- L95 `_title: Label`
- L96 `_divider: ColorRect`
- L97 `_subtitle: Label`
- L98 `_restart_button: Button`
- L99 `_cutscene: Tween`
- L100 `_is_showing: bool = false`

Public API:
- L119-146 `play_cutscene(victory: bool) -> void` — Plays the cutscene for a finished battle and keeps the banner on screen until the player presses "Play Again". Callers may `await` it.
- L150-151 `is_showing() -> bool` — True while the result banner owns the screen.

Private:
- L105-113 `_init`
- L155-239 `_build_ui`
- L243-261 `_build_emblem`
- L265-279 `_configure`
- L283-299 `_emblem_frame_style`
- L304-309 `_apply_button_style`
- L312-328 `_button_style`
- L332-334 `_sync_banner_pivot`
- L337-340 `_kill_cutscene`
- L345-349 `_on_restart_pressed`

Uses: BattleScene
Used by: GDTest/BattleEndTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

