# res://Scenes/HUD/BattleResultOverlay.gd
class_name BattleResultOverlay
extends Control
## End-of-battle cutscene: a flat, deliberately calm Victory / Defeat banner.
##
## The battle scene is the only scene, so the result screen is built in code and
## mounted on its own CanvasLayer (like DebugMenuPopup and SkillTooltipPopup) -
## no .tscn has to be hand-edited for it.
##
## The look is intentionally plain: no OutlineGlow, no HDR/neon bloom (the project
## runs `viewport/hdr_2d=true`, so any channel above 1.0 would glow). Over the
## matte backdrop sit the emblem and the title as one mark - the title lapped
## slightly over the emblem - with a single "Play Again" button below. Neither the
## title nor the emblem is boxed in: there is no slab around the title and no tile
## around the icon, and the button draws no outline.
##
## Both emblems are placeholder art until the hand-drawn icons land, so they are
## exported and can be swapped from the inspector.
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

## Square corners keep the button on the same surface as the debug menu and the
## hover tooltip slabs.
const CORNER_RADIUS: int = 0
const ROW_SEPARATION: int = 12

## Emblem (placeholder icon) size.
const EMBLEM_SIZE: float = 72.0

## How far the title laps over the emblem's bottom edge. Negative, so the two read
## as one mark instead of a stacked list.
const ICON_TITLE_OVERLAP: int = -26

const TITLE_FONT_SIZE: int = 42

const BUTTON_MIN_SIZE: Vector2 = Vector2(220.0, 44.0)
const BUTTON_FONT_SIZE: int = 16

## Cutscene pacing. Short on purpose: it plays after the last hit, so it must not
## make a finished battle feel slow.
const BACKDROP_FADE_TIME: float = 0.25
const CONTENT_IN_TIME: float = 0.32
const BUTTON_IN_TIME: float = 0.18
const CONTENT_SCALE_FROM: float = 0.96

## SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
const BACKDROP_COLOR: Color = Color(0.04, 0.05, 0.07, 0.80)

const VICTORY_TITLE: Color = Color(0.92, 0.80, 0.48, 1.0)
const VICTORY_EMBLEM_TINT: Color = Color(0.96, 0.88, 0.66, 1.0)

const DEFEAT_TITLE: Color = Color(0.86, 0.44, 0.44, 1.0)
const DEFEAT_EMBLEM_TINT: Color = Color(0.80, 0.62, 0.62, 1.0)

const TITLE_TEXT_VICTORY: String = "VICTORY"
const TITLE_TEXT_DEFEAT: String = "DEFEAT"

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
var _column: VBoxContainer
var _mark: VBoxContainer
var _emblem: TextureRect
var _title: Label
var _button_row: CenterContainer
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
	_column.resized.connect(_sync_column_pivot)
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
	_column.modulate.a = 0.0
	_column.scale = Vector2(CONTENT_SCALE_FROM, CONTENT_SCALE_FROM)
	_restart_button.modulate.a = 0.0

	_cutscene.tween_property(_backdrop, "modulate:a", 1.0, BACKDROP_FADE_TIME)
	_cutscene.tween_property(_column, "modulate:a", 1.0, CONTENT_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cutscene.tween_property(_column, "scale", Vector2.ONE, CONTENT_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_cutscene.set_parallel(false)
	_cutscene.tween_interval(CONTENT_IN_TIME * 0.5)
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

	# No slab around the title: the mark and the button sit straight on the
	# backdrop, so nothing boxes the title in.
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", ROW_SEPARATION)
	_center.add_child(_column)

	_column.add_child(_build_mark())

	_button_row = CenterContainer.new()
	_button_row.name = "ButtonRow"
	_button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_button_row)

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
	_button_row.add_child(_restart_button)


## The emblem with the title lapped over its bottom edge, as one mark. The emblem
## gets no tile of its own and the title no slab, and the title is added last so it
## draws on top of the emblem.
func _build_mark() -> Control:
	_mark = VBoxContainer.new()
	_mark.name = "Mark"
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_constant_override("separation", ICON_TITLE_OVERLAP)

	_emblem = TextureRect.new()
	_emblem.name = "Emblem"
	_emblem.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_child(_emblem)

	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_constant_override("outline_size", 0)
	_mark.add_child(_title)

	return _mark


## Applies the Victory or Defeat look: the emblem and the title.
func _configure(victory: bool) -> void:
	var title_color: Color = VICTORY_TITLE if victory else DEFEAT_TITLE
	var emblem_tex: Texture2D = victory_icon if victory else defeat_icon
	var emblem_tint: Color = VICTORY_EMBLEM_TINT if victory else DEFEAT_EMBLEM_TINT

	_emblem.texture = emblem_tex if emblem_tex != null else PLACEHOLDER_VICTORY_ICON
	_emblem.self_modulate = emblem_tint

	_title.text = TITLE_TEXT_VICTORY if victory else TITLE_TEXT_DEFEAT
	_title.add_theme_color_override("font_color", title_color)
	_apply_button_style()


## Flat matte button states: a darker surface, with no outline, glow or gradient.
func _apply_button_style() -> void:
	_restart_button.add_theme_stylebox_override("normal", _button_style(BUTTON_BG_NORMAL))
	_restart_button.add_theme_stylebox_override("hover", _button_style(BUTTON_BG_HOVER))
	_restart_button.add_theme_stylebox_override("pressed", _button_style(BUTTON_BG_PRESSED))
	_restart_button.add_theme_stylebox_override("disabled", _button_style(BUTTON_BG_NORMAL))
	_restart_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## Keeps the settle-in scale centred on the mark and the button.
func _sync_column_pivot() -> void:
	if _column != null:
		_column.pivot_offset = _column.size * 0.5


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
