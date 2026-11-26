# res://Scenes/HUD/BattleResultOverlay.gd
class_name BattleResultOverlay
extends Control
## End-of-battle cutscene: a flat, deliberately calm Victory / Defeat banner.
##
## The battle scene is the only scene, so the result screen is built in code and
## mounted on its own CanvasLayer (like DebugMenuPopup and SkillTooltipPopup) -
## no .tscn has to be hand-edited for it.
##
## The look is intentionally plain: no OutlineGlow, no HDR/neon bloom (the
## project runs `viewport/hdr_2d=true`, so any channel above 1.0 would glow), just
## a matte backdrop, one slate slab with a crisp 2px accent border and a single
## "Play Again" button. Both emblems are placeholder art until the hand-drawn
## icons land, so they are exported and can be swapped from the inspector.
##
## @author TheGreatJellyfish
## @version 11/25/2026

#region Signals
## The player pressed "Play Again". The owner decides how to restart the battle
## (BattleScene reloads the battle scene), so this overlay never restarts itself.
signal restart_requested()
#endregion

#region Constants
const PLACEHOLDER_VICTORY_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon2.png")
const PLACEHOLDER_DEFEAT_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")

## Slab metrics. Square corners and a 2px border keep it on the same surface as
## the debug menu and the hover tooltip slabs.
const PANEL_WIDTH: float = 420.0
const PADDING: int = 26
const BORDER_WIDTH: int = 2
const CORNER_RADIUS: int = 0
const ROW_SEPARATION: int = 12

## Emblem (placeholder icon) size inside its framed socket.
const EMBLEM_SIZE: float = 72.0
const EMBLEM_FRAME_PADDING: int = 10

const TITLE_FONT_SIZE: int = 42
const SUBTITLE_FONT_SIZE: int = 15

const BUTTON_MIN_SIZE: Vector2 = Vector2(220.0, 44.0)
const BUTTON_FONT_SIZE: int = 16

## Cutscene pacing. Short on purpose: it plays after the last hit, so it must not
## make a finished battle feel slow.
const BACKDROP_FADE_TIME: float = 0.25
const BANNER_IN_TIME: float = 0.32
const BUTTON_IN_TIME: float = 0.18
const BANNER_SCALE_FROM: float = 0.96

## SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
const BACKDROP_COLOR: Color = Color(0.04, 0.05, 0.07, 0.80)
const PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)

const VICTORY_BORDER: Color = Color(0.62, 0.54, 0.34, 1.0)
const VICTORY_TITLE: Color = Color(0.92, 0.80, 0.48, 1.0)
const VICTORY_EMBLEM_TINT: Color = Color(0.96, 0.88, 0.66, 1.0)

const DEFEAT_BORDER: Color = Color(0.52, 0.28, 0.30, 1.0)
const DEFEAT_TITLE: Color = Color(0.86, 0.44, 0.44, 1.0)
const DEFEAT_EMBLEM_TINT: Color = Color(0.80, 0.62, 0.62, 1.0)

const EMBLEM_FRAME_BG: Color = Color(0.10, 0.11, 0.15, 1.0)
const TITLE_TEXT_VICTORY: String = "VICTORY"
const TITLE_TEXT_DEFEAT: String = "DEFEAT"
const SUBTITLE_TEXT_VICTORY: String = "All enemies have been defeated."
const SUBTITLE_TEXT_DEFEAT: String = "Your party has fallen."
const SUBTITLE_COLOR: Color = Color(0.78, 0.82, 0.88, 1.0)
const DIVIDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.12)

const BUTTON_TEXT: String = "Play Again"
const BUTTON_FONT_COLOR: Color = Color(0.90, 0.92, 0.96, 1.0)
const BUTTON_BG_NORMAL: Color = Color(0.14, 0.16, 0.21, 1.0)
const BUTTON_BG_HOVER: Color = Color(0.20, 0.23, 0.29, 1.0)
const BUTTON_BG_PRESSED: Color = Color(0.11, 0.13, 0.17, 1.0)
#endregion

#region Exports
## Placeholder emblem for a won battle (swapped for hand-drawn art later).
@export var victory_icon: Texture2D = PLACEHOLDER_VICTORY_ICON
## Placeholder emblem for a lost battle (swapped for hand-drawn art later).
@export var defeat_icon: Texture2D = PLACEHOLDER_DEFEAT_ICON
#endregion

#region Private Variables
var _backdrop: ColorRect
var _center: CenterContainer
var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _emblem_frame: PanelContainer
var _emblem: TextureRect
var _title: Label
var _divider: ColorRect
var _subtitle: Label
var _restart_button: Button
var _cutscene: Tween
var _is_showing: bool = false
#endregion


#region Lifecycle Methods
func _init() -> void:
	name = "BattleResultOverlay"
	visible = false
	# Opaque to clicks: the result screen must never let a click reach the board
	# or the hand behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_banner.resized.connect(_sync_banner_pivot)
#endregion

#region Public Methods
## Plays the cutscene for a finished battle and keeps the banner on screen until
## the player presses "Play Again". Callers may `await` it.
func play_cutscene(victory: bool) -> void:
	_configure(victory)
	_is_showing = true
	visible = true
	_restart_button.disabled = true

	_kill_cutscene()
	_cutscene = create_tween()
	_cutscene.set_parallel(true)

	_backdrop.modulate.a = 0.0
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(BANNER_SCALE_FROM, BANNER_SCALE_FROM)
	_restart_button.modulate.a = 0.0

	_cutscene.tween_property(_backdrop, "modulate:a", 1.0, BACKDROP_FADE_TIME)
	_cutscene.tween_property(_banner, "modulate:a", 1.0, BANNER_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cutscene.tween_property(_banner, "scale", Vector2.ONE, BANNER_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_cutscene.set_parallel(false)
	_cutscene.tween_interval(BANNER_IN_TIME * 0.5)
	_cutscene.tween_property(_restart_button, "modulate:a", 1.0, BUTTON_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await _cutscene.finished
	_restart_button.disabled = false


## True while the result banner owns the screen.
func is_showing() -> bool:
	return _is_showing
#endregion

#region Private Methods
func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = BACKDROP_COLOR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner_style = StyleBoxFlat.new()
	_banner_style.bg_color = PANEL_BG
	_banner_style.border_width_left = BORDER_WIDTH
	_banner_style.border_width_top = BORDER_WIDTH
	_banner_style.border_width_right = BORDER_WIDTH
	_banner_style.border_width_bottom = BORDER_WIDTH
	_banner_style.corner_radius_top_left = CORNER_RADIUS
	_banner_style.corner_radius_top_right = CORNER_RADIUS
	_banner_style.corner_radius_bottom_left = CORNER_RADIUS
	_banner_style.corner_radius_bottom_right = CORNER_RADIUS
	_banner.add_theme_stylebox_override("panel", _banner_style)
	_center.add_child(_banner)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", PADDING)
	margin.add_theme_constant_override("margin_top", PADDING)
	margin.add_theme_constant_override("margin_right", PADDING)
	margin.add_theme_constant_override("margin_bottom", PADDING)
	_banner.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", ROW_SEPARATION)
	margin.add_child(column)

	column.add_child(_build_emblem())

	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_constant_override("outline_size", 0)
	column.add_child(_title)

	_divider = ColorRect.new()
	_divider.name = "Divider"
	_divider.custom_minimum_size = Vector2(0.0, 1.0)
	_divider.color = DIVIDER_COLOR
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_divider)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	column.add_child(_subtitle)

	var button_row := CenterContainer.new()
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(button_row)

	_restart_button = Button.new()
	_restart_button.name = "PlayAgainButton"
	_restart_button.text = BUTTON_TEXT
	_restart_button.custom_minimum_size = BUTTON_MIN_SIZE
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	_restart_button.add_theme_color_override("font_color", BUTTON_FONT_COLOR)
	_restart_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_restart_button.add_theme_color_override("font_pressed_color", BUTTON_FONT_COLOR)
	_restart_button.pressed.connect(_on_restart_pressed)
	button_row.add_child(_restart_button)


## The framed socket that holds the placeholder emblem.
func _build_emblem() -> Control:
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_emblem_frame = PanelContainer.new()
	_emblem_frame.name = "EmblemFrame"
	_emblem_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem_frame.add_theme_stylebox_override("panel", _emblem_frame_style(VICTORY_BORDER))
	row.add_child(_emblem_frame)

	_emblem = TextureRect.new()
	_emblem.name = "Emblem"
	_emblem.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem_frame.add_child(_emblem)

	return row


## Applies the Victory or Defeat look: emblem, accent border, title and subtitle.
func _configure(victory: bool) -> void:
	var accent: Color = VICTORY_BORDER if victory else DEFEAT_BORDER
	var title_color: Color = VICTORY_TITLE if victory else DEFEAT_TITLE
	var emblem_tex: Texture2D = victory_icon if victory else defeat_icon
	var emblem_tint: Color = VICTORY_EMBLEM_TINT if victory else DEFEAT_EMBLEM_TINT

	_banner_style.border_color = accent
	_emblem_frame.add_theme_stylebox_override("panel", _emblem_frame_style(accent))
	_emblem.texture = emblem_tex if emblem_tex != null else PLACEHOLDER_VICTORY_ICON
	_emblem.self_modulate = emblem_tint

	_title.text = TITLE_TEXT_VICTORY if victory else TITLE_TEXT_DEFEAT
	_title.add_theme_color_override("font_color", title_color)
	_subtitle.text = SUBTITLE_TEXT_VICTORY if victory else SUBTITLE_TEXT_DEFEAT
	_apply_button_style(accent)


## The emblem socket's chrome, rebuilt so its border carries the result's accent.
func _emblem_frame_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = EMBLEM_FRAME_BG
	style.border_width_left = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = accent
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = float(EMBLEM_FRAME_PADDING)
	style.content_margin_top = float(EMBLEM_FRAME_PADDING)
	style.content_margin_right = float(EMBLEM_FRAME_PADDING)
	style.content_margin_bottom = float(EMBLEM_FRAME_PADDING)
	return style


## Flat matte button states: a darker surface and the result's accent border, with
## no glow or gradient anywhere.
func _apply_button_style(accent: Color) -> void:
	_restart_button.add_theme_stylebox_override("normal", _button_style(BUTTON_BG_NORMAL, accent))
	_restart_button.add_theme_stylebox_override("hover", _button_style(BUTTON_BG_HOVER, accent))
	_restart_button.add_theme_stylebox_override("pressed", _button_style(BUTTON_BG_PRESSED, accent))
	_restart_button.add_theme_stylebox_override("disabled", _button_style(BUTTON_BG_NORMAL, accent))
	_restart_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _button_style(bg: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = accent
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## Keeps the settle-in scale centred on the slab.
func _sync_banner_pivot() -> void:
	if _banner != null:
		_banner.pivot_offset = _banner.size * 0.5


func _kill_cutscene() -> void:
	if _cutscene != null and _cutscene.is_valid():
		_cutscene.kill()
	_cutscene = null
#endregion


#region Signal Handlers
func _on_restart_pressed() -> void:
	if not _is_showing:
		return
	_is_showing = false
	restart_requested.emit()
#endregion

