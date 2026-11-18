# CardUI.gd
class_name CardUI
extends PanelContainer
## Visual representation of one Card in hand.
## Drag source (play / merge) and drop target (merge only).
##
## The card is rendered into an offscreen SubViewport and that texture is
## perspective-warped by a per-instance fake-3D shader (see
## res://Shaders/FakeCard3D.gdshader) while it is dealt in, so drawing reads as
## genuine 3D while the layout slot, hit box and hand ordering stay perfectly
## flat. A card that is resting in hand is never warped.

signal play_requested(card: Card)

const DRAG_PREVIEW_SIZE: Vector2 = Vector2(100, 145)
const DRAG_PREVIEW_SCALE: float = 1.04
const DRAG_SOURCE_ALPHA: float = 0.0 # Hide the source card
const RETURN_TWEEN_TIME: float = 0.18
const RETURN_CANVAS_LAYER: int = 100
const PLACEHOLDER_ICON: Texture2D = preload("res://Scenes/GameUI/GraphicalUI/BattleScene/Assests/icon.svg")

const HOVER_SCALE: float = 1.12
const HOVER_LIFT: float = 18.0
const HOVER_TWEEN_TIME: float = 0.12
const HOVER_Z_INDEX: int = 20

#region Fake-3D rig
const CARD_SIZE: Vector2 = Vector2(100, 145)
const CARD_CORNER_RADIUS: float = 6.0
## Transparent padding around the card body, so a strongly tilted card has room
## to stretch its near corners inside the quad instead of being clipped.
const CARD_PADDING: Vector2 = Vector2(20, 20)
## Padded quad (and matching SubViewport logical size) in logical pixels.
const QUAD_SIZE: Vector2 = Vector2(140, 185)
## Offscreen supersampling used only while the deal is in flight, so the text and
## borders stay crisp under the perspective warp. A resting card renders 1:1.
const RENDER_SUPERSAMPLE: float = 2.0
const FAKE_3D_SHADER: Shader = preload("res://Shaders/FakeCard3D.gdshader")
#endregion

#region Draw animation
## A drawn card is dealt in from beyond the right edge of the hand and flips
## from back to front in mid-air, landing straight in its slot: it never stops
## in the middle of the screen first.
const DRAW_FLIGHT_TIME: float = 0.42
## Fraction of the flight spent face down before the flip begins.
const DRAW_ROTATION_DELAY: float = 0.22
const DRAW_START_YAW: float = 168.0
const DRAW_START_PITCH: float = 20.0
const DRAW_MID_PITCH: float = -7.0
const DRAW_START_BANK: float = 15.0
const DRAW_START_SCALE: float = 0.74
const DRAW_POP_SCALE: float = 0.035
const DRAW_FADE_IN: float = 0.12
const DRAW_ARC_BASE: float = 78.0
const DRAW_ARC_STEP: float = 10.0
## How far along the straight line the Bezier control point is pulled.
const DRAW_ARC_SWING: float = 0.34
const DRAW_Z_BASE: int = 30
## Critically damped settle, so the flip arrives with a small natural overshoot
## instead of a dead stop.
const SETTLE_FREQUENCY: float = 7.0
const SETTLE_DAMPING: float = 6.5
#endregion

@export var icon_catalog: CardIconCatalog

@export_group("Value Change Timing")
## How long the value label waits before it re-renders after a runtime value
## change (e.g. an enemy card debuff), mirroring the unit hit-reaction delay so
## the number lands slightly after the change instead of popping instantly.
@export_range(0.0, 3.0, 0.05) var value_change_delay: float = 0.35

var card: Card
var hand_bar: HandBar

var _hover_tween: Tween
var _draw_tween: Tween
var _is_hovered: bool = false
## True while the cursor sits inside the slot, even if the card is still flying
## in from the deck. The hover is applied the moment it lands.
var _hover_wanted: bool = false
## True while the fake-3D deal animation owns the card transform.
var _is_drawing: bool = false
var _pick_selectable: bool = false
var _flash_active: bool = false
## True when the flash was caused by an enemy, so the glow turns red.
var _flash_hostile: bool = false

var _drag_in_progress: bool = false
var _is_consumed: bool = false
var _return_tween: Tween
var _return_layer: CanvasLayer
var _glow: OutlineGlow
## Pending delayed re-render of the value label after a runtime value change.
var _value_tween: Tween

## Fake-3D rig, built in _ready() so CardUI.tscn stays a plain flat layout.
var _visual_root: Control
var _card_quad: TextureRect
var _card_surface: SubViewport
var _card_material: ShaderMaterial

@onready var hover_visual: PanelContainer = $Bounds/HoverVisual
@onready var icon_row: HBoxContainer = $Bounds/HoverVisual/Margin/VBox/IconRow
@onready var art: TextureRect = $Bounds/HoverVisual/Margin/VBox/Art
@onready var value_label: Label = $Bounds/HoverVisual/Margin/VBox/ValueLabel
@onready var merge_glow: Panel = $Bounds/HoverVisual/MergeGlow
@onready var bounds: Control = $Bounds


func _ready() -> void:
	# The tilted visual must be allowed to draw outside the fixed slot.
	clip_contents = false

	# This root is only the stable layout/input slot: the card itself lives on
	# _visual_root, so tilting it can never disturb the hand layout or hit boxes.
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_style_card_panel()
	_style_merge_glow()
	_build_fake_3d_rig()

	if merge_glow != null:
		merge_glow.self_modulate.a = 0.0
		_glow = OutlineGlow.attach_to(_visual_root, CARD_CORNER_RADIUS, 13.0)

	# None of the visual children should participate in GUI hit-testing.
	# Consequently, the enlarged / tilted drawing cannot obstruct neighbouring
	# cards.
	_set_mouse_filter_recursive(_visual_root)
	_set_mouse_filter_recursive(hover_visual)

	_update_hover_pivot()
	_visual_root.resized.connect(_update_hover_pivot)

	mouse_entered.connect(_on_card_mouse_entered)
	mouse_exited.connect(_on_card_mouse_exited)

	# The hand UI is not rebuilt during the enemy turn, so the value label must
	# react to runtime card changes (buffs / debuffs) on its own.
	if EventBus.has_signal("card_value_changed"):
		EventBus.card_value_changed.connect(_on_card_value_changed)


func _process(_delta: float) -> void:
	# Immediately clear merge highlight if the cursor leaves this card while dragging.
	if not _pick_selectable and merge_glow and merge_glow.visible:
		if not get_viewport().gui_is_dragging() \
				or not get_global_rect().has_point(get_global_mouse_position()):
			merge_glow.visible = false

	_refresh_glow()


## Single source of truth for the card's outer glow.
##   enemy-caused flash (auto-selected cards hit by an enemy skill)     → THREAT_CRIMSON
##   selected   (pick prompt, or auto-selected by the game)            → RUNETERRA_BLUE
##   merge drop (dragging a mergeable card onto this one)              → ARCANE_GOLD
##   neither                                                           → off
func _refresh_glow() -> void:
	if _glow == null or merge_glow == null:
		return
	if _pick_selectable or _flash_active:
		var flash_preset: OutlineGlow.Preset = (
			OutlineGlow.Preset.THREAT_CRIMSON if _flash_hostile
			else OutlineGlow.Preset.RUNETERRA_BLUE
		)
		_glow.set_active(true, flash_preset)
	elif merge_glow.visible:
		_glow.set_active(true, OutlineGlow.Preset.ARCANE_GOLD)
	else:
		_glow.set_active(false)


## Highlights this card while the game is asking the player to choose cards in
## hand. HandBar calls this for every candidate; candidates that have already
## been picked are switched back off so the remaining ones keep glowing.
func set_pick_selectable(active: bool) -> void:
	_pick_selectable = active
	if merge_glow != null:
		merge_glow.visible = active
	# Refresh right away so every candidate lights up on the very frame the
	# prompt appears instead of waiting for the next _process tick.
	_refresh_glow()


## Highlights this card while the game shows which cards it picked on its own
## (auto_top_n / auto_highest). HandBar times the flash and clears it again.
## `hostile` is passed when an enemy caused the change so the card flashes red
## (THREAT_CRIMSON) instead of the friendly blue.
func set_flash_active(active: bool, hostile: bool = false) -> void:
	_flash_active = active
	_flash_hostile = active and hostile
	_refresh_glow()


#region Consumed guard

## Permanently locks this card against further interaction. Called by HandBar
## immediately before the removal tween starts, so nothing (drag start, drop
## target, hover restore, return animation) can revive a dying card.
func mark_consumed() -> void:
	_is_consumed = true
	_hover_wanted = false
	# A dying card must never keep (or gain) a pick highlight while it collapses.
	_pick_selectable = false
	_flash_active = false
	_flash_hostile = false
	if merge_glow != null:
		merge_glow.visible = false
	_refresh_glow()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Drop any deal still in flight: a card that is leaving the hand must not
	# keep flying towards a slot that no longer exists.
	_stop_pose_tweens()
	_is_drawing = false
	_cancel_return_animation(false)
	modulate.a = 0.0


func is_consumed() -> bool:
	return _is_consumed


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if _pick_selectable and mb != null \
			and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var hb := _find_hand_bar()
		if hb != null:
			hb.card_clicked.emit(card)
		accept_event()
		
func _exit_tree() -> void:
	_stop_pose_tweens()

	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()

	_value_tween = null

	_cancel_return_animation()


func _style_card_panel() -> void:
	# Prevent the unscaled root from drawing a second card background.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.18, 0.22, 0.96)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.75, 0.78, 0.85, 1.0)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6

	hover_visual.add_theme_stylebox_override("panel", box)

func _style_merge_glow() -> void:
	if merge_glow == null:
		return

	var glow_box := StyleBoxFlat.new()
	glow_box.bg_color = Color(1.0, 0.85, 0.3, 0.18)
	glow_box.border_width_left = 3
	glow_box.border_width_top = 3
	glow_box.border_width_right = 3
	glow_box.border_width_bottom = 3
	glow_box.border_color = Color(1.0, 0.85, 0.3, 1.0)
	glow_box.corner_radius_top_left = 6
	glow_box.corner_radius_top_right = 6
	glow_box.corner_radius_bottom_left = 6
	glow_box.corner_radius_bottom_right = 6
	merge_glow.add_theme_stylebox_override("panel", glow_box)
#endregion

#region Hover Animation

func _update_hover_pivot() -> void:
	if not is_instance_valid(_visual_root):
		return

	# Scaling around the bottom-center makes the card grow primarily upward
	# instead of appearing to expand equally in every direction. The outline glow
	# is a child of _visual_root, so it follows automatically.
	_visual_root.pivot_offset = Vector2(
		_visual_root.size.x * 0.5,
		_visual_root.size.y
	)
#endregion

#region Fake-3D rig

## Builds the offscreen card surface and its fake-3D quad.
##
##   Bounds
##   +- VisualRoot (100x145, pivot bottom-centre)  <- scale / lift / bank
##      +- CardQuad   (140x185 quad, FakeCard3D material)
##      +- CardSurface (SubViewport, supersampled)
##         +- HoverVisual (100x145 card face)       <- the real card content
##
## The card face renders into the SubViewport, so the shader only ever sees one
## fully composited texture to warp. Everything is created here rather than in
## CardUI.tscn so the scene stays a plain, editor-friendly flat layout and the
## hand layout / hit box can never be disturbed by the 3D warp.
func _build_fake_3d_rig() -> void:
	_visual_root = Control.new()
	_visual_root.name = "VisualRoot"
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_visual_root.position = Vector2.ZERO
	_visual_root.size = CARD_SIZE
	bounds.add_child(_visual_root)

	# The card face is laid out in padded quad space, so the padding around it
	# stays transparent and the quad itself never has to move or resize.
	_card_surface = SubViewport.new()
	_card_surface.name = "CardSurface"
	_card_surface.transparent_bg = true
	_card_surface.gui_disable_input = true
	_card_surface.disable_3d = true
	_card_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_visual_root.add_child(_card_surface)

	bounds.remove_child(hover_visual)
	_card_surface.add_child(hover_visual)
	hover_visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hover_visual.position = CARD_PADDING
	hover_visual.size = CARD_SIZE

	# Resolution and canvas scale are applied only once the surface actually
	# holds a canvas item: until then the rendering server has no canvas to
	# transform and silently rejects the transform. A resting card renders 1:1.
	_set_surface_scale(1.0)

	# Per-card material: a shared one would tilt every card in hand at once.
	_card_material = ShaderMaterial.new()
	_card_material.shader = FAKE_3D_SHADER
	_card_material.set_shader_parameter("quad_size", QUAD_SIZE)
	_card_material.set_shader_parameter("card_size", CARD_SIZE)
	_card_material.set_shader_parameter("corner_radius", CARD_CORNER_RADIUS)
	_card_material.set_shader_parameter("x_rot", 0.0)
	_card_material.set_shader_parameter("y_rot", 0.0)

	# The quad maps the supersampled surface back onto the card's own pixels:
	# the card face sits at CARD_PADDING inside quad space, so a quad positioned
	# at -CARD_PADDING lines the card up exactly with the layout slot.
	_card_quad = TextureRect.new()
	_card_quad.name = "CardQuad"
	_card_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_quad.stretch_mode = TextureRect.STRETCH_SCALE
	_card_quad.texture = _card_surface.get_texture()
	_card_quad.material = _card_material
	_card_quad.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card_quad.position = -CARD_PADDING
	_card_quad.size = QUAD_SIZE
	_visual_root.add_child(_card_quad)
#endregion

#region Hover Animation

func _on_card_mouse_entered() -> void:
	_hover_wanted = true
	if _drag_in_progress or get_viewport().gui_is_dragging():
		return
	# A card that is still flying in lands into its hover, so a deal never looks
	# like it ignores the cursor that is already sitting on the slot.
	if _is_drawing:
		return

	_animate_hover(true)


func _on_card_mouse_exited() -> void:
	_hover_wanted = false
	if _drag_in_progress or _is_drawing:
		return

	_animate_hover(false)


func _animate_hover(active: bool) -> void:
	if _is_drawing or _is_consumed:
		return

	_is_hovered = active

	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()

	z_index = HOVER_Z_INDEX if active else 0

	var target_scale := Vector2.ONE * HOVER_SCALE if active else Vector2.ONE
	var target_y: float = -HOVER_LIFT if active else 0.0

	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_CUBIC)

	# The fake-3D quad and the outline glow are both children of _visual_root, so
	# one tween moves the whole card as a rigid unit. Hovering only scales and
	# lifts the card: it is never warped, so its footprint (and therefore the
	# size and spacing of the hand) stays exactly as laid out.
	_hover_tween.tween_property(
		_visual_root,
		"scale",
		target_scale,
		HOVER_TWEEN_TIME
	)
	_hover_tween.parallel().tween_property(
		_visual_root,
		"position:y",
		target_y,
		HOVER_TWEEN_TIME
	)


func _reset_hover_immediate() -> void:
	_is_hovered = false
	z_index = 0

	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = null

	if is_instance_valid(_visual_root):
		_visual_root.scale = Vector2.ONE
		_visual_root.position = Vector2.ZERO
		_visual_root.rotation = 0.0
	_set_tilt(0.0, 0.0)
#endregion

#region Fake-3D pose

## Pushes a fake-3D orientation into the warp shader. Only the deal animation
## ever moves it away from flat, so a card in hand is never warped.
func _set_tilt(yaw: float, pitch: float) -> void:
	if _card_material != null:
		_card_material.set_shader_parameter("y_rot", yaw)
		_card_material.set_shader_parameter("x_rot", pitch)


## Renders the offscreen card at 1:1 while it rests, and supersampled only while
## the deal needs the extra resolution, so a card sitting in hand is drawn on the
## exact same pixel grid as a plain control.
func _set_surface_scale(supersample: float) -> void:
	if _card_surface == null:
		return
	_card_surface.size = Vector2i(
		int(QUAD_SIZE.x * supersample),
		int(QUAD_SIZE.y * supersample)
	)
	_card_surface.canvas_transform = Transform2D(
		0.0, Vector2.ONE * supersample, 0.0, Vector2.ZERO
	)
#endregion

#region Fake-3D draw animation

## True while the fake-3D deal animation owns the card transform.
func is_drawing() -> bool:
	return _is_drawing


## Deals this card in from the deck: one fast swoop from `start_offset`
## (CardUI-local pixels) straight into the slot, flipping from the card back to
## the printed face while it is still in the air.
## `delay` staggers a multi-card deal and `stagger_index` fans the arcs out.
func play_draw_animation(start_offset: Vector2, delay: float = 0.0, stagger_index: int = 0) -> void:
	if _is_consumed or not is_instance_valid(_visual_root):
		return

	_stop_pose_tweens()
	_is_drawing = true
	_is_hovered = false
	modulate.a = 0.0
	z_index = DRAW_Z_BASE + stagger_index
	# The card is still off screen here, so the resolution switch is invisible.
	_set_surface_scale(RENDER_SUPERSAMPLE)

	var arc: float = -(DRAW_ARC_BASE + DRAW_ARC_STEP * float(stagger_index))
	# Pose the first frame by hand, otherwise the card would flash flat for one
	# frame before the tween takes over.
	_apply_draw_pose(0.0, start_offset, arc)

	_draw_tween = create_tween()
	_draw_tween.set_trans(Tween.TRANS_LINEAR)
	if delay > 0.0:
		_draw_tween.tween_interval(delay)
	_draw_tween.tween_method(
		_apply_draw_pose.bind(start_offset, arc), 0.0, 1.0, DRAW_FLIGHT_TIME
	)
	_draw_tween.tween_callback(_finish_draw)


## Snaps a card that is still settling flat, so a fast player can grab it.
func _finish_draw_immediate() -> void:
	if not _is_drawing:
		return
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()
	_draw_tween = null
	_is_drawing = false
	_apply_flat_pose()
	_refresh_glow()


func _stop_pose_tweens() -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()
	_draw_tween = null
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null


## One frame of the deal-in flight. `t` is raw 0..1 progress.
func _apply_draw_pose(t: float, start_offset: Vector2, arc: float) -> void:
	# Travel is heavily front-loaded, so the card bursts in from the right edge,
	# while the rotation settles on a damped spring with a small overshoot.
	var travel: float = _ease_out_quart(t)
	var settle: float = _settle(
		clampf((t - DRAW_ROTATION_DELAY) / (1.0 - DRAW_ROTATION_DELAY), 0.0, 1.0)
	)

	var control := Vector2(start_offset.x * DRAW_ARC_SWING, arc)
	_visual_root.position = _quadratic_bezier(start_offset, control, Vector2.ZERO, travel)

	var yaw: float = lerpf(DRAW_START_YAW, 0.0, settle)
	var pitch: float = lerpf(DRAW_START_PITCH, 0.0, settle) + DRAW_MID_PITCH * sin(PI * t)
	_set_tilt(yaw, pitch)

	_visual_root.rotation = deg_to_rad(lerpf(DRAW_START_BANK, 0.0, _ease_out_cubic(t)))
	_visual_root.scale = Vector2.ONE * (
		lerpf(DRAW_START_SCALE, 1.0, settle) + DRAW_POP_SCALE * sin(PI * t)
	)
	modulate.a = clampf(t / DRAW_FADE_IN, 0.0, 1.0)


func _finish_draw() -> void:
	_draw_tween = null
	_is_drawing = false
	_apply_flat_pose()
	_refresh_glow()
	if _hover_wanted and not _drag_in_progress and not get_viewport().gui_is_dragging():
		_animate_hover(true)


func _apply_flat_pose() -> void:
	modulate.a = 1.0
	z_index = 0
	# Back to 1:1 now that the warp is gone: the card must line up with its slot
	# exactly, texel for pixel.
	_set_surface_scale(1.0)
	if not is_instance_valid(_visual_root):
		return
	_visual_root.position = Vector2.ZERO
	_visual_root.rotation = 0.0
	_visual_root.scale = Vector2.ONE
	_set_tilt(0.0, 0.0)


## Critically damped spring step: 0 at x = 0, 1 at x = 1, with a small natural
## overshoot on the way instead of a dead stop.
static func _settle(x: float) -> float:
	var decay: float = exp(-SETTLE_DAMPING * x)
	return 1.0 - decay * (
		cos(SETTLE_FREQUENCY * x)
		+ (SETTLE_DAMPING / SETTLE_FREQUENCY) * sin(SETTLE_FREQUENCY * x)
	)


static func _ease_out_cubic(x: float) -> float:
	var inverse: float = 1.0 - x
	return 1.0 - inverse * inverse * inverse


static func _ease_out_quart(x: float) -> float:
	var inverse: float = 1.0 - x
	return 1.0 - inverse * inverse * inverse * inverse


static func _quadratic_bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	var inverse: float = 1.0 - t
	return inverse * inverse * a + 2.0 * inverse * t * control + t * t * b
#endregion

func setup(p_card: Card, p_hand_bar: HandBar = null) -> void:
	card = p_card
	hand_bar = p_hand_bar if p_hand_bar != null else _find_hand_bar()
	_refresh()


func _refresh() -> void:
	if card == null:
		return

	var suffix: String = (
		"DMV" if card.is_double_merged
		else ("MV" if card.is_merged else "V")
	)
	value_label.text = "%d %s" % [card.get_effective_value(), suffix]
	_build_stars_and_indicators()


func _build_stars_and_indicators() -> void:
	for child: Node in icon_row.get_children():
		child.queue_free()

	var star_count: int = 1
	if card.is_double_merged:
		star_count = 3
	elif card.is_merged:
		star_count = 2

	var stars_label := Label.new()
	stars_label.text = "★".repeat(star_count) + "☆".repeat(3 - star_count)
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	stars_label.add_theme_font_size_override("font_size", 12)
	stars_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(stars_label)

	var parity_label := Label.new()
	parity_label.text = "ODD" if card.is_odd() else "EVEN"
	parity_label.add_theme_color_override(
		"font_color",
		Color(0.6, 0.8, 1.0) if card.is_odd() else Color(1.0, 0.6, 0.8)
	)
	parity_label.add_theme_font_size_override("font_size", 11)
	parity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(parity_label)
#endregion

#region Drag source

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null or _is_consumed or _drag_in_progress or _pick_selectable:
		return null

	var hb := _find_hand_bar()
	if hb == null:
		return null

	# A card that is still settling into hand is snapped flat first, so a fast
	# player never has to wait out a deal animation before grabbing a card.
	_finish_draw_immediate()

	# A previous return animation may still be running if the player
	# quickly starts another drag.
	_cancel_return_animation()

	# The drag preview must start from the normal card transform, not from
	# an enlarged/lifted hover transform.
	_reset_hover_immediate()

	_drag_in_progress = true

	# Create the preview before dimming the source card.
	set_drag_preview(_make_drag_preview())

	# Keep the original card in CardsRow so the hand layout never changes.
	# It acts as the slot to which the drag visual can return.
	modulate.a = DRAG_SOURCE_ALPHA

	hb.drag_started.emit(card)
	return CardDrag.new(card, hb)


func _make_drag_preview() -> Control:
	# Godot controls the root preview's position. Therefore, the centered
	# visual must be a child with a negative half-size offset.
	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var visual := _make_visual_copy()
	preview_root.add_child(visual)

	visual.position = -DRAG_PREVIEW_SIZE * 0.5
	visual.pivot_offset = DRAG_PREVIEW_SIZE * 0.5
	visual.scale = Vector2.ONE * DRAG_PREVIEW_SCALE

	return preview_root

# Reuse the real card appearance instead of maintaining a second, simplified
# preview layout that can drift out of sync with CardUI. Only the flat card face
# is copied: the fake-3D quad and its SubViewport stay behind, so a drag preview
# costs nothing extra and is already correct on the first frame of the drag.
func _make_visual_copy() -> PanelContainer:
	var visual := hover_visual.duplicate() as PanelContainer
	visual.name = "DragCardVisual"

	visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	visual.position = Vector2.ZERO
	visual.size = DRAG_PREVIEW_SIZE
	visual.custom_minimum_size = DRAG_PREVIEW_SIZE
	visual.pivot_offset = DRAG_PREVIEW_SIZE * 0.5
	visual.modulate = Color.WHITE
	visual.self_modulate = Color.WHITE
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.z_index = 0

	var copied_merge := visual.get_node_or_null("MergeGlow") as Control
	if copied_merge != null:
		copied_merge.hide()

	_set_mouse_filter_recursive(visual)
	return visual


func _set_mouse_filter_recursive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in control.get_children():
		if child is Control:
			_set_mouse_filter_recursive(child as Control)
#endregion

#region Drag completion and cancellation

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if is_instance_valid(merge_glow):
		merge_glow.hide()

	if not _drag_in_progress:
		return

	_drag_in_progress = false

	if is_drag_successful():
		# Stay hidden. The HandBar will collapse/remove this slot.
		_cancel_return_animation(false)
		# Safety net: if nothing actually used the card, show it again.
		_restore_if_unconsumed.call_deferred()
	else:
		_animate_return_to_hand()

	var hb := _find_hand_bar()
	if hb != null and card != null:
		hb.drag_ended.emit(card)


func _restore_if_unconsumed() -> void:
	if _is_consumed or not is_inside_tree() or is_queued_for_deletion():
		return
	var hb := _find_hand_bar()
	var st: GameState = hb._get_game_state() if hb != null else null
	if st != null and st.hand.has(card):
		modulate.a = 1.0


func _cancel_return_animation(restore_alpha: bool = true) -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = null

	if is_instance_valid(_return_layer):
		_return_layer.queue_free()
	_return_layer = null

	if restore_alpha:
		modulate.a = 1.0


func _animate_return_to_hand() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		modulate.a = 1.0
		return

	var return_position: Vector2 = get_global_rect().position

	# Use a dedicated CanvasLayer so the returning card renders above HUD,
	# hand cards, units, and other CanvasLayers.
	var layer := CanvasLayer.new()
	layer.layer = RETURN_CANVAS_LAYER
	get_tree().root.add_child(layer)

	var ghost := _make_visual_copy()
	layer.add_child(ghost)

	ghost.top_level = true
	ghost.z_index = 1000
	ghost.pivot_offset = DRAG_PREVIEW_SIZE * 0.5
	ghost.global_position = (
		get_global_mouse_position() - DRAG_PREVIEW_SIZE * 0.5
	)
	ghost.scale = Vector2.ONE * DRAG_PREVIEW_SCALE

	_return_layer = layer
	_return_tween = ghost.create_tween()
	_return_tween.set_ease(Tween.EASE_OUT)
	_return_tween.set_trans(Tween.TRANS_CUBIC)

	_return_tween.tween_property(
		ghost,
		"global_position",
		return_position,
		RETURN_TWEEN_TIME
	)
	_return_tween.parallel().tween_property(
		ghost,
		"scale",
		Vector2.ONE,
		RETURN_TWEEN_TIME
	)

	_return_tween.finished.connect(_on_return_finished.bind(layer))


func _on_return_finished(layer: CanvasLayer) -> void:
	# Ignore an obsolete animation if another drag has already started.
	if _return_layer == layer:
		_return_layer = null
		_return_tween = null
		modulate.a = 1.0
		if not get_viewport().gui_is_dragging() \
				and get_global_rect().has_point(get_global_mouse_position()):
			_animate_hover(true)

	if is_instance_valid(layer):
		layer.queue_free()
#endregion

#region Merge drop target

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var drag: CardDrag = null
	if data is CardDrag:
		drag = data
	if drag == null or drag.card == null or drag.card == card:
		merge_glow.visible = false
		return false

	var hb := _find_hand_bar()
	var valid: bool = false

	if hb != null:
		valid = hb.can_merge(drag.card, card)
	elif drag.source != null:
		valid = drag.source.can_merge(drag.card, card)
	else:
		valid = not card.is_double_merged and not drag.card.is_double_merged

	merge_glow.visible = valid
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var drag: CardDrag = null
	if data is CardDrag:
		drag = data
	merge_glow.visible = false

	if drag == null or drag.card == null:
		return

	var hb := _find_hand_bar()
	if hb == null:
		hb = drag.source

	if hb != null:
		hb.merge_requested.emit(drag.card, card)
		# Do not emit drag_ended here. The drag source emits it exactly once
		# from NOTIFICATION_DRAG_END for successful and cancelled drags.


func _find_hand_bar() -> HandBar:
	if hand_bar != null and is_instance_valid(hand_bar):
		return hand_bar

	var curr: Node = get_parent()
	while curr != null:
		if curr is HandBar:
			hand_bar = curr as HandBar
			return hand_bar
		curr = curr.get_parent()

	return null
#endregion

#region EventBus handlers

## Runtime card value change (skill buffs / debuffs, e.g. an enemy reducing the
## value of cards in hand). The label waits `value_change_delay` before it
## re-renders so the number lands with the reaction — the same beat UnitUI uses
## for damage — instead of changing on the exact frame the model was mutated.
func _on_card_value_changed(changed_card: Card, old_value: int, new_value: int) -> void:
	if changed_card == null or changed_card != card or _is_consumed:
		return
	if old_value == new_value or not is_inside_tree():
		return

	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()

	_value_tween = create_tween()
	_value_tween.tween_interval(value_change_delay)
	_value_tween.tween_callback(_refresh)
#endregion
