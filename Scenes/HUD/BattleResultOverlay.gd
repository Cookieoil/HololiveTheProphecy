# res://Scenes/HUD/BattleResultOverlay.gd
class_name BattleResultOverlay
extends Control
## End-of-battle cutscene, staged like a big-budget result screen.
##
## The battle scene is the only scene, so the result screen is built in code and
## mounted on its own CanvasLayer (like DebugMenuPopup and SkillTooltipPopup) - no
## .tscn has to be hand-edited for it.
##
## Composition, top to bottom:
##   - a screen-space grade over the live battlefield: colour drained, softly
##     vignetted, with a full-width feathered cinema band across the middle
##     (see res://Scenes/HUD/BattleResultBackdrop.gdshader),
##   - the emblem as a low-contrast etched seal with the title lapped over its
##     lower edge (see res://Scenes/HUD/BattleResultEmblem.gdshader), plus a wider
##     ghost imprint of the same word drifting behind it,
##   - and one frameless action prompt below the band.
##
## No boxes: no slab around the title, no tile around the emblem, no border on the
## button. No neon either - every colour stays in SDR range and nothing glows, so
## the scene's own WorldEnvironment glow cannot flare it.
##
## Both emblems are placeholder art until the hand-drawn icons land, so they are
## exported and can be swapped from the inspector (set `raw_emblem_mode` to draw
## finished art untouched).
##
## @author TheGreatJellyfish
## @version 11/25/2026

#region Signals
## The player pressed "Play Again". The owner decides how to restart the battle
## (BattleScene reloads the battle scene), so this overlay never restarts itself.
signal restart_requested()
#endregion

#region Constants
const BACKDROP_SHADER: Shader = preload("res://Scenes/HUD/BattleResultBackdrop.gdshader")
const EMBLEM_SHADER: Shader = preload("res://Scenes/HUD/BattleResultEmblem.gdshader")

const PLACEHOLDER_VICTORY_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon2.png")
const PLACEHOLDER_DEFEAT_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")

## Emblem size, and how far the title laps over its bottom edge. Negative, so the
## two read as one mark instead of a stacked list.
const EMBLEM_SIZE: float = 112.0
const ICON_TITLE_OVERLAP: int = -30

## Space between the mark and the action prompt below it.
const ROW_SEPARATION: int = 16

const TITLE_FONT_SIZE: int = 56
## Tracking at the start of the reveal and where it locks. Condensing the letters
## into place is what makes the title feel stamped rather than simply faded in.
const TITLE_TRACK_FROM: int = 22
const TITLE_TRACK_TO: int = 14
const GHOST_FONT_TRACK: int = 16

## The ghost imprint: a wider, fainter copy of the same word that appears with the
## title, then drifts outward and thins away behind it. Kept very low contrast and
## short-lived on purpose - a louder or longer one reads as a misprint instead of
## an afterimage.
const GHOST_PEAK_ALPHA: float = 0.12
const GHOST_SCALE: float = 1.04
const GHOST_IN_TIME: float = 0.22
const GHOST_DRIFT_TIME: float = 0.70
const GHOST_FADE_TIME: float = 0.50

## Cutscene pacing. Short on purpose: it plays after the last hit, so it must not
## make a finished battle feel slow. Three beats - the hush, the stamp, the prompt.
const BACKDROP_FADE_TIME: float = 0.24
const BAND_OPEN_TIME: float = 0.42
const RULE_WIPE_TIME: float = 0.52
const BEAT_GAP: float = 0.06
const MARK_IN_TIME: float = 0.34
const CONTENT_SCALE_FROM: float = 0.97
const PROMPT_GAP: float = 0.34
const PROMPT_IN_TIME: float = 0.24

## SDR-only palette. Every channel stays at or below 1.0 so nothing blooms.
const VICTORY_TITLE: Color = Color(0.93, 0.83, 0.56, 1.0)
const DEFEAT_TITLE: Color = Color(0.86, 0.42, 0.40, 1.0)
## The seal's ink: burnished antique gold for a win, a brighter red for a loss.
const VICTORY_SEAL: Color = Color(0.76, 0.64, 0.38, 1.0)
const DEFEAT_SEAL: Color = Color(0.82, 0.34, 0.32, 1.0)
## What the drained battlefield leans towards: warm parchment for a win, a deep
## blood red for a loss.
const VICTORY_GRADE: Color = Color(0.86, 0.80, 0.68, 1.0)
const DEFEAT_GRADE: Color = Color(0.80, 0.18, 0.16, 1.0)

const TITLE_TEXT_VICTORY: String = "VICTORY"
const TITLE_TEXT_DEFEAT: String = "DEFEAT"
#endregion

#region Exports
## Placeholder emblem for a won battle (swapped for hand-drawn art later).
@export var victory_icon: Texture2D = PLACEHOLDER_VICTORY_ICON
## Placeholder emblem for a lost battle (swapped for hand-drawn art later).
@export var defeat_icon: Texture2D = PLACEHOLDER_DEFEAT_ICON
## Draw the emblem as authored instead of etching it into a seal. Turn this on
## once a bespoke crest replaces the placeholder icons.
@export var raw_emblem_mode: bool = false
#endregion

#region Private Variables
var _backdrop: ColorRect
var _backdrop_mat: ShaderMaterial
var _center: CenterContainer
var _column: VBoxContainer
var _mark: VBoxContainer
var _emblem: TextureRect
var _emblem_mat: ShaderMaterial
var _title_stack: MarginContainer
var _title: Label
var _title_ghost: Label
var _title_variation: FontVariation
var _ghost_variation: FontVariation
var _prompt: BattleResultPrompt
var _cutscene: Tween
var _ghost_tween: Tween
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
	_title_stack.resized.connect(_sync_ghost_pivot)
#endregion

#region Public Methods
## Plays the cutscene for a finished battle and keeps the banner on screen until
## the player presses "Play Again". Callers may `await` it.
func play_cutscene(victory: bool) -> void:
	_configure(victory)
	_is_showing = true
	visible = true
	_prompt.set_interactive(false)

	_kill_cutscene()
	_reset_cutscene_pose()
	_sync_screen_size()

	# Beat 1 - the hush: the grade settles over the battlefield and the band
	# unfurls out of the middle of the frame.
	_cutscene = create_tween()
	_cutscene.set_parallel(true)
	_cutscene.tween_property(_backdrop, "modulate:a", 1.0, BACKDROP_FADE_TIME)
	_cutscene.tween_method(_set_band_open, 0.0, 1.0, BAND_OPEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cutscene.tween_method(_set_rule_wipe, 0.0, 1.0, RULE_WIPE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Beat 2 - the stamp: the mark settles and the title's tracking condenses into
	# lock, while the ghost imprint drifts out behind it.
	_cutscene.set_parallel(false)
	_cutscene.tween_interval(BEAT_GAP)
	_cutscene.set_parallel(true)
	_cutscene.tween_property(_column, "modulate:a", 1.0, MARK_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cutscene.tween_property(_column, "scale", Vector2.ONE, MARK_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cutscene.tween_method(
		_set_title_tracking,
		float(TITLE_TRACK_FROM),
		float(TITLE_TRACK_TO),
		MARK_IN_TIME
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Beat 3 - the prompt, once the banner has claimed the moment.
	_cutscene.set_parallel(false)
	_cutscene.tween_interval(PROMPT_GAP)
	_cutscene.tween_property(_prompt, "modulate:a", 1.0, PROMPT_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_start_ghost_tween()

	await _cutscene.finished
	_prompt.set_interactive(true)


## True while the result banner owns the screen.
func is_showing() -> bool:
	return _is_showing
#endregion

#region Private Methods
func _build_ui() -> void:
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = BACKDROP_SHADER
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.material = _backdrop_mat
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	# No slab around the title: the mark and the prompt sit straight on the band.
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", ROW_SEPARATION)
	_center.add_child(_column)

	_column.add_child(_build_mark())

	var prompt_row := CenterContainer.new()
	prompt_row.name = "PromptRow"
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(prompt_row)

	_prompt = BattleResultPrompt.new()
	_prompt.pressed.connect(_on_restart_pressed)
	prompt_row.add_child(_prompt)


## The emblem with the title lapped over its bottom edge, as one mark. The emblem
## gets no tile of its own and the title no slab; the title is added last so it
## draws on top, with the ghost imprint between the two.
func _build_mark() -> Control:
	_mark = VBoxContainer.new()
	_mark.name = "Mark"
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_constant_override("separation", ICON_TITLE_OVERLAP)

	_emblem_mat = ShaderMaterial.new()
	_emblem_mat.shader = EMBLEM_SHADER
	_emblem = TextureRect.new()
	_emblem.name = "Emblem"
	_emblem.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.material = _emblem_mat
	_mark.add_child(_emblem)

	# Both labels fill the same rect, so the ghost sits exactly behind the title.
	_title_stack = MarginContainer.new()
	_title_stack.name = "TitleStack"
	_title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ghost_variation = FontVariation.new()
	_ghost_variation.spacing_glyph = GHOST_FONT_TRACK
	_title_ghost = _build_title_label("TitleGhost", _ghost_variation)
	_title_stack.add_child(_title_ghost)

	_title_variation = FontVariation.new()
	_title_variation.spacing_glyph = TITLE_TRACK_FROM
	_title = _build_title_label("Title", _title_variation)
	_title_stack.add_child(_title)

	_mark.add_child(_title_stack)
	return _mark


## A centred display label. The tracking comes from the FontVariation, which is
## what turns the default font into cinema lettering.
func _build_title_label(label_name: String, variation: FontVariation) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", variation)
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	return label


## Applies the Victory or Defeat look: the scene grade, the seal's ink and the
## title's tone.
func _configure(victory: bool) -> void:
	var grade: Color = VICTORY_GRADE if victory else DEFEAT_GRADE
	var seal: Color = VICTORY_SEAL if victory else DEFEAT_SEAL
	var title_color: Color = VICTORY_TITLE if victory else DEFEAT_TITLE
	var emblem_tex: Texture2D = victory_icon if victory else defeat_icon

	_backdrop_mat.set_shader_parameter("grade_tint", grade)
	_emblem_mat.set_shader_parameter("seal_color", seal)
	_emblem_mat.set_shader_parameter("raw_mode", raw_emblem_mode)
	_emblem.texture = emblem_tex if emblem_tex != null else PLACEHOLDER_VICTORY_ICON

	var word: String = TITLE_TEXT_VICTORY if victory else TITLE_TEXT_DEFEAT
	_title.text = word
	_title_ghost.text = word
	_title.add_theme_color_override("font_color", title_color)
	_title_ghost.add_theme_color_override("font_color", title_color)


## Puts every animated value back to its pre-reveal pose, so a second cutscene in
## the same scene always starts from the same place.
func _reset_cutscene_pose() -> void:
	_backdrop.modulate.a = 0.0
	_set_band_open(0.0)
	_set_rule_wipe(0.0)
	_column.modulate.a = 0.0
	_column.scale = Vector2(CONTENT_SCALE_FROM, CONTENT_SCALE_FROM)
	_set_title_tracking(float(TITLE_TRACK_FROM))
	_title_ghost.modulate.a = 0.0
	_title_ghost.scale = Vector2.ONE
	_prompt.modulate.a = 0.0


## The ghost imprint runs on its own tween: it appears with the mark, drifts
## outward for much longer than the mark takes to settle, then thins away. Kept
## apart from the main tween so the two never fight over the same property.
func _start_ghost_tween() -> void:
	_ghost_tween = create_tween()
	_ghost_tween.set_parallel(true)
	_ghost_tween.tween_property(_title_ghost, "modulate:a", GHOST_PEAK_ALPHA, GHOST_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ghost_tween.tween_property(
		_title_ghost,
		"scale",
		Vector2(GHOST_SCALE, GHOST_SCALE),
		GHOST_DRIFT_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ghost_tween.set_parallel(false)
	_ghost_tween.tween_interval(GHOST_DRIFT_TIME)
	_ghost_tween.tween_property(_title_ghost, "modulate:a", 0.0, GHOST_FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_band_open(value: float) -> void:
	_backdrop_mat.set_shader_parameter("band_open", value)


## The backdrop blur is measured in pixels, so the shader needs the viewport size
## (canvas_item shaders have no SCREEN_PIXEL_SIZE to read it from).
func _sync_screen_size() -> void:
	if _backdrop_mat != null:
		_backdrop_mat.set_shader_parameter("screen_size", get_viewport_rect().size)


func _set_rule_wipe(value: float) -> void:
	_backdrop_mat.set_shader_parameter("rule_wipe", value)


func _set_title_tracking(value: float) -> void:
	_title_variation.spacing_glyph = int(roundf(value))


## Keeps the settle-in scale centred on the mark and the prompt.
func _sync_column_pivot() -> void:
	if _column != null:
		_column.pivot_offset = _column.size * 0.5


## Keeps the ghost imprint's drift centred on the title.
func _sync_ghost_pivot() -> void:
	if _title_ghost != null:
		_title_ghost.pivot_offset = _title_ghost.size * 0.5


func _kill_cutscene() -> void:
	if _cutscene != null and _cutscene.is_valid():
		_cutscene.kill()
	_cutscene = null
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_ghost_tween = null
#endregion


#region Signal Handlers
func _on_restart_pressed() -> void:
	if not _is_showing:
		return
	_is_showing = false
	restart_requested.emit()
#endregion
