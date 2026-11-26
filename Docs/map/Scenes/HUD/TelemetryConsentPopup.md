<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/TelemetryConsentPopup.gd` — `class_name TelemetryConsentPopup` extends `Control`

`289` lines · [back to the map](../../../CODEBASE_MAP.md)

> First-launch disclosure for gameplay telemetry: a full-screen modal that asks the player whether their decisions may be collected to improve game design. Built…

Sections: Signals · Constants · Public Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L16 `decided(agreed: bool)` — The player answered. Agreed false means "do not collect anything".

Constants:
- L20 `HEADER_TEXT: String = "Data Consent"`
- L21 `MAIN_TEXT: String`
- L22 `SUB_TEXT: String = \`
- L25 `ALLOW_TEXT: String = "Allow"`
- L26 `DECLINE_TEXT: String = "Decline"`
- L29 `PANEL_WIDTH: float = 660.0` — Panel geometry and type scale.
- L30 `HEADER_FONT_SIZE: int = 30`
- L31 `MAIN_FONT_SIZE: int = 21`
- L32 `SUB_FONT_SIZE: int = 17`
- L33 `BUTTON_FONT_SIZE: int = 21`
- L36 `HEADER_PAD_X: int = 46` — Padding around the header text, so the plate hugs the title instead of spanning the whole window.
- L37 `HEADER_PAD_Y: int = 12`
- L41 `FRAME_BORDER: int = 2` — The frame is thin; the header plate sits inside it with a deliberately thicker blue border, which is what makes the top read as the heavier edge.
- L42 `HEADER_BORDER: int = 4`
- L45 `DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.88)` — Near-black stage, so the window is the only thing lit on screen.
- L47 `FRAME_BG: Color = Color(0.06, 0.07, 0.10, 1.0)` — Window: black plate with a blue frame, matching the disclosure mock-up.
- L48 `FRAME_BORDER_COLOR: Color = Color(0.24, 0.48, 0.74, 1.0)`
- L49 `HEADER_BG: Color = Color(0.11, 0.19, 0.30, 1.0)`
- L50 `HEADER_BORDER_COLOR: Color = Color(0.34, 0.62, 0.89, 1.0)`
- L52 `HEADER_COLOR: Color = Color(0.96, 0.97, 1.0, 1.0)`
- L53 `MAIN_COLOR: Color = Color(0.93, 0.94, 0.97, 1.0)`
- L54 `SUB_COLOR: Color = Color(0.70, 0.74, 0.81, 1.0)`
- L58 `ALLOW_BG: Color = Color(0.40, 0.72, 0.34, 1.0)` — Buttons: a green "Allow" and a red "Decline", each with a darker outline and near-black label ink, as in the mock-up.
- L59 `ALLOW_HOVER: Color = Color(0.47, 0.80, 0.40, 1.0)`
- L60 `ALLOW_BORDER: Color = Color(0.16, 0.38, 0.14, 1.0)`
- L61 `DECLINE_BG: Color = Color(0.85, 0.42, 0.45, 1.0)`
- L62 `DECLINE_HOVER: Color = Color(0.92, 0.50, 0.53, 1.0)`
- L63 `DECLINE_BORDER: Color = Color(0.52, 0.19, 0.23, 1.0)`
- L64 `BUTTON_INK: Color = Color(0.09, 0.11, 0.10, 1.0)`
- L65 `BUTTON_SIZE: Vector2 = Vector2(220.0, 58.0)`

State:
- L71 `consent: TelemetryConsent = TelemetryConsent.load_from()` — The consent record this popup writes to. Injectable so tests can point it at a throwaway path.
- L73 `agree_button: Button` — Exposed for tests: pressing these is the same as the player clicking them.
- L74 `decline_button: Button`
- L76 `header_label: Label` — Exposed for tests, so the required wording and button order can be locked.
- L77 `main_label: Label`
- L78 `sub_label: Label`
- L79 `buttons_row: HBoxContainer`

Public API:
- L99-103 `open() -> void` — Shows the panel. Callers `await decided` to hold the game until answered.
- L106-107 `is_open() -> bool`
- L111-116 `decide(agreed: bool) -> void` — Records the answer and closes. Exposed so a test can decide without a click.

Private:
- L83-94 `_ready`
- L123-127 `_sync_to_viewport`
- L130-156 `_build_ui`
- L161-179 `_build_header`
- L182-200 `_build_body`
- L204-219 `_build_buttons`
- L222-230 `_make_wrapped_label`
- L233-246 `_make_button`
- L249-255 `_make_button_style`
- L258-265 `_make_frame_style`
- L268-278 `_make_header_style`
- L282-283 `_on_agree_pressed`
- L286-287 `_on_decline_pressed`

Uses: TelemetryConsent
Used by: GDTest/TelemetryConsentTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

