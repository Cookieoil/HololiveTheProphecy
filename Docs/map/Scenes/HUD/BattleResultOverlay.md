<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleResultOverlay.gd` — `class_name BattleResultOverlay` extends `Control`

`383` lines · [back to the map](../../../CODEBASE_MAP.md)

> End-of-battle cutscene, staged like a big-budget result screen. The battle scene is the only scene, so the result screen is built in code and mounted on its own…

Sections: Signals · Constants · Exports · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L33 `restart_requested` — The player pressed "Play Again". The owner decides how to restart the battle (BattleScene reloads the battle scene), so this overlay never restarts itself.

Constants:
- L37 `BACKDROP_SHADER: Shader`
- L38 `EMBLEM_SHADER: Shader`
- L40 `PLACEHOLDER_VICTORY_ICON: Texture2D`
- L41 `PLACEHOLDER_DEFEAT_ICON: Texture2D`
- L45 `EMBLEM_SIZE: float = 112.0` — Emblem size, and how far the title laps over its bottom edge. Negative, so the two read as one mark instead of a stacked list.
- L46 `ICON_TITLE_OVERLAP: int = -30`
- L49 `ROW_SEPARATION: int = 16` — Space between the mark and the action prompt below it.
- L51 `TITLE_FONT_SIZE: int = 56`
- L54 `TITLE_TRACK_FROM: int = 22` — Tracking at the start of the reveal and where it locks. Condensing the letters into place is what makes the title feel stamped rather than simply faded in.
- L55 `TITLE_TRACK_TO: int = 14`
- L56 `GHOST_FONT_TRACK: int = 16`
- L62 `GHOST_PEAK_ALPHA: float = 0.12` — The ghost imprint: a wider, fainter copy of the same word that appears with the title, then drifts outward and thins away behind it. Kept very low contrast and…
- L63 `GHOST_SCALE: float = 1.04`
- L64 `GHOST_IN_TIME: float = 0.22`
- L65 `GHOST_DRIFT_TIME: float = 0.70`
- L66 `GHOST_FADE_TIME: float = 0.50`
- L70 `BACKDROP_FADE_TIME: float = 0.24` — Cutscene pacing. Short on purpose: it plays after the last hit, so it must not make a finished battle feel slow. Three beats - the hush, the stamp, the prompt.
- L71 `BAND_OPEN_TIME: float = 0.42`
- L72 `RULE_WIPE_TIME: float = 0.52`
- L73 `BEAT_GAP: float = 0.06`
- L74 `MARK_IN_TIME: float = 0.34`
- L75 `CONTENT_SCALE_FROM: float = 0.97`
- L76 `PROMPT_GAP: float = 0.34`
- L77 `PROMPT_IN_TIME: float = 0.24`
- L80 `VICTORY_TITLE: Color = Color(0.93, 0.83, 0.56, 1.0)` — SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
- L81 `DEFEAT_TITLE: Color = Color(0.86, 0.42, 0.40, 1.0)`
- L83 `VICTORY_SEAL: Color = Color(0.76, 0.64, 0.38, 1.0)` — The seal's ink: burnished antique gold for a win, weathered iron for a loss.
- L84 `DEFEAT_SEAL: Color = Color(0.58, 0.27, 0.27, 1.0)`
- L86 `VICTORY_GRADE: Color = Color(0.86, 0.80, 0.68, 1.0)` — What the drained battlefield leans towards: warm parchment or cold ash.
- L87 `DEFEAT_GRADE: Color = Color(0.62, 0.66, 0.72, 1.0)`
- L89 `TITLE_TEXT_VICTORY: String = "VICTORY"`
- L90 `TITLE_TEXT_DEFEAT: String = "DEFEAT"`

Exports:
- L95 `victory_icon: Texture2D = PLACEHOLDER_VICTORY_ICON` — Placeholder emblem for a won battle (swapped for hand-drawn art later).
- L97 `defeat_icon: Texture2D = PLACEHOLDER_DEFEAT_ICON` — Placeholder emblem for a lost battle (swapped for hand-drawn art later).
- L100 `raw_emblem_mode: bool = false` — Draw the emblem as authored instead of etching it into a seal. Turn this on once a bespoke crest replaces the placeholder icons.

State:
- L104 `_backdrop: ColorRect`
- L105 `_backdrop_mat: ShaderMaterial`
- L106 `_center: CenterContainer`
- L107 `_column: VBoxContainer`
- L108 `_mark: VBoxContainer`
- L109 `_emblem: TextureRect`
- L110 `_emblem_mat: ShaderMaterial`
- L111 `_title_stack: MarginContainer`
- L112 `_title: Label`
- L113 `_title_ghost: Label`
- L114 `_title_variation: FontVariation`
- L115 `_ghost_variation: FontVariation`
- L116 `_prompt: BattleResultPrompt`
- L117 `_cutscene: Tween`
- L118 `_ghost_tween: Tween`
- L119 `_is_showing: bool = false`

Public API:
- L139-184 `play_cutscene(victory: bool) -> void` — Plays the cutscene for a finished battle and keeps the banner on screen until the player presses "Play Again". Callers may `await` it.
- L188-189 `is_showing() -> bool` — True while the result banner owns the screen.

Private:
- L124-133 `_init`
- L193-225 `_build_ui`
- L231-265 `_build_mark`
- L270-278 `_build_title_label`
- L283-298 `_configure`
- L303-312 `_reset_cutscene_pose`
- L318-332 `_start_ghost_tween`
- L335-336 `_set_band_open`
- L341-343 `_sync_screen_size`
- L346-347 `_set_rule_wipe`
- L350-351 `_set_title_tracking`
- L355-357 `_sync_column_pivot`
- L361-363 `_sync_ghost_pivot`
- L366-372 `_kill_cutscene`
- L377-381 `_on_restart_pressed`

Uses: BattleResultPrompt, BattleScene
Used by: GDTest/BattleEndTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: res://Scenes/HUD/BattleResultBackdrop.gdshader, res://Scenes/HUD/BattleResultEmblem.gdshader, res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

