<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/TelemetryConsentPopup.gd` — `class_name TelemetryConsentPopup` extends `Control`

`339` lines · [back to the map](../../../CODEBASE_MAP.md)

> First-launch disclosure for gameplay telemetry: a full-screen modal that asks the player whether their decisions may be collected to improve game design. Built…

Sections: Signals · Constants · Public Variables · Private Variables · Public Methods · Lifecycle Methods · Public Methods · Private Methods · (+1 more)

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
- L46 `DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)` — Stage behind the window: dark enough to read against, light enough that the battle stays visible through it.
- L48 `FRAME_BG: Color = Color(0.06, 0.07, 0.10, 1.0)` — Window: black plate with a blue frame, matching the disclosure mock-up.
- L49 `FRAME_BORDER_COLOR: Color = Color(0.24, 0.48, 0.74, 1.0)`
- L50 `HEADER_BG: Color = Color(0.11, 0.19, 0.30, 1.0)`
- L51 `HEADER_BORDER_COLOR: Color = Color(0.34, 0.62, 0.89, 1.0)`
- L53 `HEADER_COLOR: Color = Color(0.96, 0.97, 1.0, 1.0)`
- L54 `MAIN_COLOR: Color = Color(0.93, 0.94, 0.97, 1.0)`
- L55 `SUB_COLOR: Color = Color(0.70, 0.74, 0.81, 1.0)`
- L59 `ALLOW_BG: Color = Color(0.40, 0.72, 0.34, 1.0)` — Buttons: a green "Allow" and a red "Decline", each with a darker outline and near-black label ink, as in the mock-up.
- L60 `ALLOW_HOVER: Color = Color(0.47, 0.80, 0.40, 1.0)`
- L61 `ALLOW_BORDER: Color = Color(0.16, 0.38, 0.14, 1.0)`
- L62 `DECLINE_BG: Color = Color(0.85, 0.42, 0.45, 1.0)`
- L63 `DECLINE_HOVER: Color = Color(0.92, 0.50, 0.53, 1.0)`
- L64 `DECLINE_BORDER: Color = Color(0.52, 0.19, 0.23, 1.0)`
- L65 `BUTTON_INK: Color = Color(0.09, 0.11, 0.10, 1.0)`
- L66 `BUTTON_SIZE: Vector2 = Vector2(220.0, 58.0)`

State:
- L72 `consent: TelemetryConsent = TelemetryConsent.load_from()` — The consent record this popup writes to. Injectable so tests can point it at a throwaway path.
- L74 `agree_button: Button` — Exposed for tests: pressing these is the same as the player clicking them.
- L75 `decline_button: Button`
- L77 `header_label: Label` — Exposed for tests, so the required wording and button order can be locked.
- L78 `main_label: Label`
- L79 `sub_label: Label`
- L80 `buttons_row: HBoxContainer`
- L87 `_asked_this_launch: bool = false` — True once this launch has asked. Static on purpose: "Play Again" reloads the battle scene in the same process and must not ask a second time, while a fresh proc…
- L89 `_header_slot: MarginContainer` — Slot that lifts the header plate onto the window's top edge.
- L90 `_header_row: CenterContainer`

Public API:
- L99-100 `static should_prompt_this_launch() -> bool` — True while this launch has not asked yet. Deliberately ignores the stored answer: the disclosure is shown once per launch so a returning player still sees what…
- L104-105 `static reset_launch_flag() -> void` — Test seam: forgets the launch flag so the once-per-launch rule can be checked.
- L125-130 `open() -> void` — Shows the panel. Callers `await decided` to hold the game until answered.
- L133-134 `is_open() -> bool`
- L138-143 `decide(agreed: bool) -> void` — Records the answer and closes. Exposed so a test can decide without a click.

Private:
- L109-120 `_ready`
- L150-154 `_sync_to_viewport`
- L157-183 `_build_ui`
- L189-214 `_build_header`
- L221-229 `_sync_header_lift`
- L232-250 `_build_body`
- L254-269 `_build_buttons`
- L272-280 `_make_wrapped_label`
- L283-296 `_make_button`
- L299-305 `_make_button_style`
- L308-315 `_make_frame_style`
- L318-328 `_make_header_style`
- L332-333 `_on_agree_pressed`
- L336-337 `_on_decline_pressed`

Uses: TelemetryConsent
Used by: GDTest/SkillContextFactoryTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, GDTest/TurnLoopTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

