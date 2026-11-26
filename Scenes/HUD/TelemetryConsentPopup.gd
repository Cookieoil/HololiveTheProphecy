class_name TelemetryConsentPopup
extends Control
## First-launch disclosure for gameplay telemetry: a full-screen modal that asks
## the player whether their decisions may be collected to improve game design.
##
## Built in code (like DebugMenuPopup and BattleResultOverlay) so the battle
## scene carries no extra nodes to keep in sync. The panel blocks input while it
## is open, and the game only ever records anything after an explicit "Agree" -
## a "Decline" leaves the recorder a complete no-op.
##
## @author TheGreatJellyfish
## @version 11/26/2026

#region Signals
## The player answered. Agreed false means "do not collect anything".
signal decided(agreed: bool)
#endregion

#region Constants
const TITLE_TEXT: String = "Help Improve Game Balance?"
const CARD_WIDTH: float = 620.0
const TITLE_FONT_SIZE: int = 30
const BODY_FONT_SIZE: int = 17
const BUTTON_FONT_SIZE: int = 20

## Warm parchment on near-black, matching the result-screen palette.
const TITLE_COLOR: Color = Color(0.93, 0.83, 0.56, 1.0)
const BODY_COLOR: Color = Color(0.86, 0.86, 0.90, 1.0)
const HIGHLIGHT_COLOR: Color = Color(0.76, 0.64, 0.38, 1.0)

const PRIVACY_BODY: String = """This game can collect anonymous gameplay data to help improve game design and balance.

[b]What is collected[/b]
- Which cards you play, merge or convert
- Which ally and skill you target
- Which enemies you face, and how the battle ends

[b]What is never collected[/b]
- Your name, email or account
- Your IP address or device identifiers
- Any personal or private information

You can decline and still play the full game."""
#endregion

#region Public Variables
## The consent record this popup writes to. Injectable so tests can point it at a
## throwaway path.
var consent: TelemetryConsent = TelemetryConsent.load_from()
## Exposed for tests: pressing these is the same as the player clicking them.
var agree_button: Button
var decline_button: Button
#endregion

#region Private Variables
var _body: RichTextLabel
#endregion

#region Lifecycle Methods
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false
#endregion

#region Public Methods
## Shows the panel. Callers `await decided` to hold the game until answered.
func open() -> void:
	visible = true
	if agree_button != null:
		agree_button.grab_focus()


func is_open() -> bool:
	return visible


## Records the answer and closes. Exposed so a test can decide without a click.
func decide(agreed: bool) -> void:
	if consent == null:
		consent = TelemetryConsent.new()
	consent.decide(agreed)
	visible = false
	decided.emit(agreed)
#endregion

#region Private Methods
func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = TITLE_TEXT
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)

	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(CARD_WIDTH - 40.0, 0.0)
	_body.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
	_body.add_theme_color_override("default_color", BODY_COLOR)
	_body.text = PRIVACY_BODY
	column.add_child(_body)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)

	decline_button = _make_button("Decline")
	decline_button.name = "DeclineButton"
	decline_button.pressed.connect(_on_decline_pressed)
	buttons.add_child(decline_button)

	agree_button = _make_button("Agree")
	agree_button.name = "AgreeButton"
	agree_button.pressed.connect(_on_agree_pressed)
	buttons.add_child(agree_button)


func _make_button(label: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150.0, 44.0)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	return button


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.10, 0.98)
	style.border_color = HIGHLIGHT_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	return style
#endregion

#region Signal Handlers
func _on_agree_pressed() -> void:
	decide(true)


func _on_decline_pressed() -> void:
	decide(false)
#endregion
