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
const HEADER_TEXT: String = "Data Consent"
const MAIN_TEXT: String = "We need your consent to collect anonymous gameplay data."
const SUB_TEXT: String = \
	"Your data will only be used to help improve the game design and balance. " \
	+ "None of your personal data will be recorded."
const ALLOW_TEXT: String = "Allow"
const DECLINE_TEXT: String = "Decline"

## Panel geometry and type scale.
const PANEL_WIDTH: float = 660.0
const HEADER_FONT_SIZE: int = 30
const MAIN_FONT_SIZE: int = 21
const SUB_FONT_SIZE: int = 17
const BUTTON_FONT_SIZE: int = 21

## The frame is thin; the header plate sits inside it with a deliberately thicker
## blue border, which is what makes the top read as the heavier edge.
const FRAME_BORDER: int = 2
const HEADER_BORDER: int = 4

## Near-black stage, so the window is the only thing lit on screen.
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.88)
## Window: black plate with a blue frame, matching the disclosure mock-up.
const FRAME_BG: Color = Color(0.06, 0.07, 0.10, 1.0)
const FRAME_BORDER_COLOR: Color = Color(0.24, 0.48, 0.74, 1.0)
const HEADER_BG: Color = Color(0.11, 0.19, 0.30, 1.0)
const HEADER_BORDER_COLOR: Color = Color(0.34, 0.62, 0.89, 1.0)

const HEADER_COLOR: Color = Color(0.96, 0.97, 1.0, 1.0)
const MAIN_COLOR: Color = Color(0.93, 0.94, 0.97, 1.0)
const SUB_COLOR: Color = Color(0.70, 0.74, 0.81, 1.0)

## Buttons: a green "Allow" and a red "Decline", each with a darker outline and
## near-black label ink, as in the mock-up.
const ALLOW_BG: Color = Color(0.40, 0.72, 0.34, 1.0)
const ALLOW_HOVER: Color = Color(0.47, 0.80, 0.40, 1.0)
const ALLOW_BORDER: Color = Color(0.16, 0.38, 0.14, 1.0)
const DECLINE_BG: Color = Color(0.85, 0.42, 0.45, 1.0)
const DECLINE_HOVER: Color = Color(0.92, 0.50, 0.53, 1.0)
const DECLINE_BORDER: Color = Color(0.52, 0.19, 0.23, 1.0)
const BUTTON_INK: Color = Color(0.09, 0.11, 0.10, 1.0)
const BUTTON_SIZE: Vector2 = Vector2(220.0, 58.0)
#endregion

#region Public Variables
## The consent record this popup writes to. Injectable so tests can point it at a
## throwaway path.
var consent: TelemetryConsent = TelemetryConsent.load_from()
## Exposed for tests: pressing these is the same as the player clicking them.
var agree_button: Button
var decline_button: Button
## Exposed for tests, so the required wording and button order can be locked.
var header_label: Label
var main_label: Label
var sub_label: Label
var buttons_row: HBoxContainer
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
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	frame.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(frame)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 0)
	frame.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_body())


## The top plate, whose blue border is the thicker one.
func _build_header() -> PanelContainer:
	var header: PanelContainer = PanelContainer.new()
	header.name = "Header"
	header.add_theme_stylebox_override("panel", _make_header_style())

	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = HEADER_TEXT
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	header_label.add_theme_color_override("font_color", HEADER_COLOR)
	header.add_child(header_label)
	return header


func _build_body() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Body"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 28)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "BodyColumn"
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	main_label = _make_wrapped_label("MainText", MAIN_TEXT, MAIN_FONT_SIZE, MAIN_COLOR)
	column.add_child(main_label)
	sub_label = _make_wrapped_label("SubText", SUB_TEXT, SUB_FONT_SIZE, SUB_COLOR)
	column.add_child(sub_label)
	column.add_child(_build_buttons())
	return margin


## "Allow" on the left, "Decline" on the right.
func _build_buttons() -> HBoxContainer:
	buttons_row = HBoxContainer.new()
	buttons_row.name = "Buttons"
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 34)

	agree_button = _make_button(ALLOW_TEXT, ALLOW_BG, ALLOW_HOVER, ALLOW_BORDER)
	agree_button.name = "AllowButton"
	agree_button.pressed.connect(_on_agree_pressed)
	buttons_row.add_child(agree_button)

	decline_button = _make_button(DECLINE_TEXT, DECLINE_BG, DECLINE_HOVER, DECLINE_BORDER)
	decline_button.name = "DeclineButton"
	decline_button.pressed.connect(_on_decline_pressed)
	buttons_row.add_child(decline_button)
	return buttons_row


func _make_wrapped_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(label: String, base: Color, hover: Color, border: Color) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", BUTTON_INK)
	button.add_theme_color_override("font_hover_color", BUTTON_INK)
	button.add_theme_color_override("font_pressed_color", BUTTON_INK)
	button.add_theme_color_override("font_focus_color", BUTTON_INK)
	button.add_theme_stylebox_override("normal", _make_button_style(base, border))
	button.add_theme_stylebox_override("hover", _make_button_style(hover, border))
	button.add_theme_stylebox_override("pressed", _make_button_style(base, border))
	button.add_theme_stylebox_override("focus", _make_button_style(hover, border))
	return button


func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style


func _make_frame_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.border_color = FRAME_BORDER_COLOR
	style.set_border_width_all(FRAME_BORDER)
	style.set_corner_radius_all(12)
	# No content margin: the header plate is meant to sit flush with the frame.
	return style


func _make_header_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HEADER_BG
	style.border_color = HEADER_BORDER_COLOR
	style.set_border_width_all(HEADER_BORDER)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
#endregion

#region Signal Handlers
func _on_agree_pressed() -> void:
	decide(true)


func _on_decline_pressed() -> void:
	decide(false)
#endregion
