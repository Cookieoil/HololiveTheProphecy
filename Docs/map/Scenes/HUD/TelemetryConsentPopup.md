<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/TelemetryConsentPopup.gd` — `class_name TelemetryConsentPopup` extends `Control`

`177` lines · [back to the map](../../../CODEBASE_MAP.md)

> First-launch disclosure for gameplay telemetry: a full-screen modal that asks the player whether their decisions may be collected to improve game design. Built…

Sections: Signals · Constants · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L16 `decided(agreed: bool)` — The player answered. Agreed false means "do not collect anything".

Constants:
- L20 `TITLE_TEXT: String = "Help Improve Game Balance?"`
- L21 `CARD_WIDTH: float = 620.0`
- L22 `TITLE_FONT_SIZE: int = 30`
- L23 `BODY_FONT_SIZE: int = 17`
- L24 `BUTTON_FONT_SIZE: int = 20`
- L27 `TITLE_COLOR: Color = Color(0.93, 0.83, 0.56, 1.0)` — Warm parchment on near-black, matching the result-screen palette.
- L28 `BODY_COLOR: Color = Color(0.86, 0.86, 0.90, 1.0)`
- L29 `HIGHLIGHT_COLOR: Color = Color(0.76, 0.64, 0.38, 1.0)`
- L31 `PRIVACY_BODY: String`

State:
- L49 `consent: TelemetryConsent = TelemetryConsent.load_from()` — The consent record this popup writes to. Injectable so tests can point it at a throwaway path.
- L51 `agree_button: Button` — Exposed for tests: pressing these is the same as the player clicking them.
- L52 `decline_button: Button`
- L56 `_body: RichTextLabel`

Public API:
- L69-72 `open() -> void` — Shows the panel. Callers `await decided` to hold the game until answered.
- L75-76 `is_open() -> bool`
- L80-85 `decide(agreed: bool) -> void` — Records the answer and closes. Exposed so a test can decide without a click.

Private:
- L60-64 `_ready`
- L89-145 `_build_ui`
- L148-153 `_make_button`
- L156-166 `_make_panel_style`
- L170-171 `_on_agree_pressed`
- L174-175 `_on_decline_pressed`

Uses: TelemetryConsent
Used by: GDTest/TelemetryConsentTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

