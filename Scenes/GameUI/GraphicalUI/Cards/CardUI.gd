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

#region Kintsugi forge animation
## Two cards strike edge to edge above the target slot and fuse into one along a
## molten seam, the way broken lacquerware is rejoined with kintsugi. The whole
## forge is deliberately short: a player merges several times a turn, so it must
## never make them wait.
const KINTSUGI_SHADER: Shader = preload("res://Shaders/KintsugiWeld.gdshader")

## Node names the two source plates are mounted under, so they stay
## distinguishable from each other and from the card's own visual rig.
const FORGE_PLATE_A: String = "ForgePlateA"
const FORGE_PLATE_B: String = "ForgePlateB"

## Flint-and-steel: both plates cock away from each other.
const MERGE_RECOIL_TIME: float = 0.10
## ...then slam back together edge to edge.
const MERGE_COLLIDE_TIME: float = 0.12
## A double merge (a free-play card) holds the compression for one beat longer,
## so the extra value it is worth can be felt as well as read.
const MERGE_HITSTOP: float = 0.035
## The molten seam ignites, brands the new value and cools away.
const MERGE_BURN_TIME: float = 0.22

## How far the anvil sits above the resting slot.
const MERGE_LIFT: float = 22.0
## How far each plate cocks out from the anvil before it strikes.
const MERGE_STAGE_GAP: float = 30.0
## 2D bank of the plates' inner edges, which lift towards each other.
const MERGE_INNER_TILT: float = 7.0
## How far each plate stays off the anvil centre once the two are pressed
## together. At that offset the pair still covers the whole card body, so the
## forged card underneath them is never exposed while they melt away.
const MERGE_PRESS_GAP: float = 14.0
## How far the two plates are pressed down as they meet. The forged card sits at
## exactly this size underneath them, so the strike hands straight over to the
## card and the card is what springs back out of the press.
const MERGE_PRESS_SCALE: float = 0.88
## Fraction of the lift the anvil still holds when the plates strike.
const MERGE_IMPACT_LIFT: float = 0.4
## Share of the burn over which the two pressed plates melt into the card they
## were pressed into. The card face is on screen from the strike onwards - the
## plates are simply drawn over it and dissolve - so nothing ever blinks out.
const MERGE_DISSOLVE_FRACTION: float = 0.45
## Press-and-release overshoot: the welded card rebounds out of the press.
const MERGE_POP_SCALE: float = 0.14
const MERGE_BRAND_SCALE: float = 1.32
const MERGE_BRAND_DELAY: float = 0.10
const MERGE_BRAND_TIME: float = 0.16
const MERGE_Z_INDEX: int = 45
#endregion

#region Card rank styling
## A resting card's frame reads its forge rank, so a merged card looks forged
## and a double-merged (free-play) card is unmistakable at a glance.
const BASE_BG_COLOR: Color = Color(0.16, 0.18, 0.22, 0.96)
const BASE_BORDER_COLOR: Color = Color(0.75, 0.78, 0.85, 1.0)
const MERGE_BG_COLOR: Color = Color(0.19, 0.17, 0.14, 0.96)
const MERGE_BORDER_COLOR: Color = Color(0.96, 0.78, 0.34, 1.0)
const DOUBLE_MERGE_BG_COLOR: Color = Color(0.13, 0.19, 0.23, 0.96)
const DOUBLE_MERGE_BORDER_COLOR: Color = Color(0.48, 0.90, 1.0, 1.0)
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
var _slide_tween: Tween
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

## Stylebox the card frame is drawn with, kept so its rank colours can be
## repainted whenever the card's merge state changes.
var _panel_box: StyleBoxFlat

## Kintsugi forge state. The forge owns the card transform while it plays, the
## same way `_is_drawing` owns it during a deal.
var _is_merging: bool = false
var _merge_tween: Tween
var _weld_tween: Tween
var _brand_tween: Tween
## Flat copies of the two source cards, mounted in the slot for the strike.
var _forge_ghost_a: Control
var _forge_ghost_b: Control
## Molten seam overlay drawn over the card face while the weld burns.
var _weld_overlay: ColorRect
var _weld_material: ShaderMaterial
## Where each source plate started, in this card's own local pixels.
var _merge_from_a: Vector2 = Vector2.ZERO
var _merge_from_b: Vector2 = Vector2.ZERO
## Which side of the anvil plate A came from (+1 right, -1 left).
var _merge_recoil_dir: float = 1.0

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
	# Drop any deal or forge still in flight: a card that is leaving the hand
	# must not keep flying towards a slot that no longer exists, and it must not
	# be left invisible by a forge that was cancelled mid-burn.
	_stop_pose_tweens()
	_stop_slide()
	_is_drawing = false
	_finish_merge_immediate()
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
	_stop_slide()

	if _merge_tween != null and _merge_tween.is_valid():
		_merge_tween.kill()
	_merge_tween = null

	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()

	_value_tween = null

	_cancel_return_animation()


func _style_card_panel() -> void:
	# Prevent the unscaled root from drawing a second card background.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_panel_box = StyleBoxFlat.new()
	_panel_box.bg_color = BASE_BG_COLOR
	_panel_box.border_width_left = 2
	_panel_box.border_width_top = 2
	_panel_box.border_width_right = 2
	_panel_box.border_width_bottom = 2
	_panel_box.border_color = BASE_BORDER_COLOR
	_panel_box.corner_radius_top_left = 6
	_panel_box.corner_radius_top_right = 6
	_panel_box.corner_radius_bottom_left = 6
	_panel_box.corner_radius_bottom_right = 6

	hover_visual.add_theme_stylebox_override("panel", _panel_box)


## Repaints the card frame for its forge rank: an unmerged card keeps the plain
## steel frame, a merged card is gilded like the kintsugi seam that made it, and
## a double-merged card (which costs no action to play) gets the prophecy cyan
## rim so a free-play card can be spotted in hand at a glance.
## Safe to call before `setup()`, while `card` is still null.
func _apply_rank_style() -> void:
	if _panel_box == null:
		return
	if card != null and card.is_double_merged:
		_panel_box.bg_color = DOUBLE_MERGE_BG_COLOR
		_panel_box.border_color = DOUBLE_MERGE_BORDER_COLOR
	elif card != null and card.is_merged:
		_panel_box.bg_color = MERGE_BG_COLOR
		_panel_box.border_color = MERGE_BORDER_COLOR
	else:
		_panel_box.bg_color = BASE_BG_COLOR
		_panel_box.border_color = BASE_BORDER_COLOR

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

#region Row layout

## Glides this card's layout slot to `target` (row-local), so the hand closes up
## or opens smoothly when another card leaves or arrives instead of snapping.
func slide_to(target: Vector2, duration: float) -> void:
	if _is_consumed or not is_inside_tree():
		return

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	var from: Vector2 = position
	_slide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_method(
		func(weight: float) -> void:
			position = from.lerp(target, weight),
		0.0,
		1.0,
		duration
	)


func _stop_slide() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null
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

#region Kintsugi forge animation

## True while the kintsugi forge owns the card transform.
func is_merging() -> bool:
	return _is_merging


## A flat, detached copy of this card's face, for use as a forge ghost. The
## caller owns the returned node until it is mounted by `play_merge_animation`.
## Only the flat face is copied: the fake-3D quad stays behind, so mounting a
## ghost costs nothing extra and is already correct on the first frame.
func make_ghost() -> Control:
	return _make_visual_copy()


## Forges this card out of the two cards that were merged into it. Two flat
## copies of the source plates fly up from where they sat in hand, cock apart
## like flint and steel, and are struck together over this card's own slot. This
## card is switched on underneath them at that instant and they melt into it
## over a molten seam (see res://Shaders/KintsugiWeld.gdshader) while the new
## value is branded onto the face.
##
## The ghosts are plain card faces mounted inside the fixed layout slot, so the
## hand spacing and every hit box stay exactly where they were.
##
## @param ghost_a - flat copy of the dragged plate (consumed by this call)
## @param ghost_b - flat copy of the drop-target plate (consumed by this call)
## @param start_offset_a - where plate A sat, in this card's local pixels
## @param start_offset_b - where plate B sat, in this card's local pixels
## @param double_merged - a double merge holds the strike one beat longer
func play_merge_animation(
	ghost_a: Control,
	ghost_b: Control,
	start_offset_a: Vector2,
	start_offset_b: Vector2,
	double_merged: bool
) -> void:
	if _is_consumed or not is_instance_valid(_visual_root):
		_discard_ghost(ghost_a)
		_discard_ghost(ghost_b)
		return

	_finish_draw_immediate()
	_stop_pose_tweens()

	_is_merging = true
	_is_hovered = false
	_hover_wanted = false
	# The card is switched on under the plates at the strike, so it is hidden for
	# the flight and then revealed by the plates themselves melting away.
	modulate.a = 0.0
	z_index = MERGE_Z_INDEX
	_set_surface_scale(RENDER_SUPERSAMPLE)
	_visual_root.position = Vector2.ZERO
	_visual_root.rotation = 0.0
	_visual_root.scale = Vector2.ONE
	_set_tilt(0.0, 0.0)

	_forge_ghost_a = ghost_a
	_forge_ghost_b = ghost_b
	_mount_forge_ghost(ghost_a, start_offset_a, FORGE_PLATE_A)
	_mount_forge_ghost(ghost_b, start_offset_b, FORGE_PLATE_B)

	_merge_from_a = start_offset_a
	_merge_from_b = start_offset_b
	# Which way plate A has to pull back to open the strike.
	_merge_recoil_dir = 1.0 if start_offset_a.x > start_offset_b.x else -1.0

	_build_weld_overlay(double_merged)
	_pose_recoil(0.0)

	_merge_tween = create_tween()
	_merge_tween.set_trans(Tween.TRANS_LINEAR)
	_merge_tween.tween_method(_pose_recoil, 0.0, 1.0, MERGE_RECOIL_TIME)
	if double_merged:
		# A free-play card is worth a beat of held tension at the moment of impact.
		_merge_tween.tween_interval(MERGE_HITSTOP)
	_merge_tween.tween_method(_pose_collide, 0.0, 1.0, MERGE_COLLIDE_TIME)
	_merge_tween.tween_callback(_on_merge_impact)
	# The burn runs as one method across two segments so the spent plates can be
	# freed the moment they have finished melting into the card.
	_merge_tween.tween_method(_pose_burn, 0.0, MERGE_DISSOLVE_FRACTION,
		MERGE_BURN_TIME * MERGE_DISSOLVE_FRACTION)
	_merge_tween.tween_callback(_clear_forge_ghosts)
	_merge_tween.tween_method(_pose_burn, MERGE_DISSOLVE_FRACTION, 1.0,
		MERGE_BURN_TIME * (1.0 - MERGE_DISSOLVE_FRACTION))
	_merge_tween.tween_callback(_finish_merge)


## Snaps a card whose weld is still burning flat, so a fast player can grab the
## freshly merged card (or chain a second merge) without waiting it out.
func _finish_merge_immediate() -> void:
	if not _is_merging:
		return
	if _merge_tween != null and _merge_tween.is_valid():
		_merge_tween.kill()
	_merge_tween = null
	_end_forge_state()


func _finish_merge() -> void:
	_merge_tween = null
	_end_forge_state()
	# A card that was hovered while it burned lands straight into its hover.
	if _hover_wanted and not _drag_in_progress and not get_viewport().gui_is_dragging():
		_animate_hover(true)


## Frees a ghost that was handed to `play_merge_animation` but never mounted, or
## one that is being torn down. Teardown is immediate rather than deferred: a
## card whose weld was interrupted (grabbed mid-burn) must not keep a plate
## drawn over it for one more frame.
func _discard_ghost(ghost: Control) -> void:
	if is_instance_valid(ghost):
		ghost.free()


## Parks a source plate inside the fixed slot so the strike can play there. The
## ghost is a plain flat face, so the cock and the slam are a 2D bank rather than
## the fake-3D warp, which belongs to the card that is being forged.
## The plate is renamed, so the two of them stay distinguishable as siblings.
func _mount_forge_ghost(ghost: Control, offset: Vector2, plate_name: String) -> void:
	if ghost == null:
		return
	ghost.name = plate_name
	ghost.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ghost.size = CARD_SIZE
	ghost.custom_minimum_size = CARD_SIZE
	# Same bottom-centre pivot as the card's own visual root, so a plate and the
	# forged card stay perfectly registered at any press scale.
	ghost.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	ghost.position = offset
	ghost.scale = Vector2.ONE
	ghost.rotation = 0.0
	ghost.z_index = 0
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bounds.add_child(ghost)


## Flint and steel: both plates fly up onto the anvil and cock away from each
## other, their inner edges lifting, so the strike that follows has somewhere to
## come from. `dir` says which side plate A came from.
func _pose_recoil(u: float) -> void:
	var eased: float = _ease_out_cubic(u)
	var dir: float = _merge_recoil_dir
	var cock: float = dir * MERGE_INNER_TILT

	_pose_forge_ghost(_forge_ghost_a,
		_merge_from_a,
		Vector2(dir * MERGE_STAGE_GAP, -MERGE_LIFT),
		0.0, cock, eased)
	_pose_forge_ghost(_forge_ghost_b,
		_merge_from_b,
		Vector2(-dir * MERGE_STAGE_GAP, -MERGE_LIFT),
		0.0, -cock, eased)


## The strike: both plates slam inward, straighten out, and press down onto the
## anvil. They come to rest *over the forged card's own footprint*, pressed to
## `MERGE_PRESS_SCALE`, which is exactly where the card is switched on underneath
## them - so the strike hands straight over to the card with nothing blinking.
func _pose_collide(u: float) -> void:
	var eased: float = _ease_in_quart(u)
	var dir: float = _merge_recoil_dir
	var cock: float = dir * MERGE_INNER_TILT
	var anvil_y: float = -MERGE_LIFT * MERGE_IMPACT_LIFT
	var pressed: float = lerpf(1.0, MERGE_PRESS_SCALE, eased)

	_pose_forge_ghost(_forge_ghost_a,
		Vector2(dir * MERGE_STAGE_GAP, -MERGE_LIFT),
		Vector2(dir * MERGE_PRESS_GAP, anvil_y),
		cock, 0.0, eased)
	_pose_forge_ghost(_forge_ghost_b,
		Vector2(-dir * MERGE_STAGE_GAP, -MERGE_LIFT),
		Vector2(-dir * MERGE_PRESS_GAP, anvil_y),
		-cock, 0.0, eased)
	_set_forge_plates_scale(pressed)


## One frame of a forge ghost, gliding from one pose to the next.
func _pose_forge_ghost(
	ghost: Control,
	from_position: Vector2,
	to_position: Vector2,
	from_rotation: float,
	to_rotation: float,
	u: float
) -> void:
	if not is_instance_valid(ghost):
		return
	ghost.position = from_position.lerp(to_position, u)
	ghost.rotation = lerpf(from_rotation, to_rotation, u)


## Squeezes both plates together. The forged card starts the burn at exactly this
## size, which is what makes the hand-off from plates to card invisible.
func _set_forge_plates_scale(value: float) -> void:
	var plate_scale := Vector2.ONE * value
	if is_instance_valid(_forge_ghost_a):
		_forge_ghost_a.scale = plate_scale
	if is_instance_valid(_forge_ghost_b):
		_forge_ghost_b.scale = plate_scale


## Rides both spent plates and the weld on the forged card's own transform, so
## the whole merge moves as a single object while the plates melt away.
## `plate_alpha` fades them out; the card underneath is already opaque by then.
func _pose_forge_stack(position: Vector2, p_scale: float, plate_alpha: float) -> void:
	var dir: float = _merge_recoil_dir
	_pose_forge_plate(_forge_ghost_a, position + Vector2(dir * MERGE_PRESS_GAP, 0.0),
		p_scale, plate_alpha)
	_pose_forge_plate(_forge_ghost_b, position + Vector2(-dir * MERGE_PRESS_GAP, 0.0),
		p_scale, plate_alpha)

	# The molten seam belongs on top of the plates: it is what is welding them.
	if is_instance_valid(_weld_overlay):
		_weld_overlay.position = -CARD_PADDING + position
		_weld_overlay.scale = Vector2.ONE * p_scale


func _pose_forge_plate(plate: Control, position: Vector2, p_scale: float, alpha: float) -> void:
	if not is_instance_valid(plate):
		return
	plate.position = position
	plate.rotation = 0.0
	plate.scale = Vector2.ONE * p_scale
	plate.modulate.a = alpha


## The two pressed plates melt into the card they were pressed into, while that
## card springs back out of the press and lands on the anvil. The plates and the
## weld ride the card's exact transform, so the strike never breaks: the only
## thing that changes is the faces dissolving.
func _pose_burn(u: float) -> void:
	# A damped spring, so the card presses past flat and rebounds a little instead
	# of stopping dead the way a linear ease would.
	var settle: float = _settle(u)

	# Press, then release: the card starts the burn at exactly the size the two
	# plates ended the strike at, so the hand-off from plates to card is seamless.
	var released: float = clampf(settle, 0.0, 1.0)
	var stack_scale: float = MERGE_PRESS_SCALE \
		+ (1.0 - MERGE_PRESS_SCALE) * settle \
		+ MERGE_POP_SCALE * released * (1.0 - released) * 4.0
	var stack_position := Vector2(
		0.0,
		-MERGE_LIFT * MERGE_IMPACT_LIFT * (1.0 - settle)
	)

	if is_instance_valid(_visual_root):
		_visual_root.position = stack_position
		_visual_root.scale = Vector2.ONE * stack_scale
	# The card is never warped in 3D while the plates are over it, so no tilted
	# corner can ever poke out from behind them.
	_set_tilt(0.0, 0.0)

	# The two cards are still what they always were until the weld consumes them.
	var dissolve: float = 1.0 - clampf(u / MERGE_DISSOLVE_FRACTION, 0.0, 1.0)
	_pose_forge_stack(stack_position, stack_scale, dissolve)


## The strike has landed: the forged card is already sitting underneath the two
## pressed plates, so it is simply switched on at the exact pose they ended the
## strike in. Nothing blinks out and nothing pops - the plates then melt into it
## over the burn, leaving the card they were pressed into.
func _on_merge_impact() -> void:
	var stack_position := Vector2(0.0, -MERGE_LIFT * MERGE_IMPACT_LIFT)

	# Same place, same size as the pressed plates, so switching the card on is
	# invisible: from here on the dying plates are all that is left of the two
	# source cards.
	if is_instance_valid(_visual_root):
		_visual_root.position = stack_position
		_visual_root.scale = Vector2.ONE * MERGE_PRESS_SCALE
	_set_tilt(0.0, 0.0)
	modulate.a = 1.0
	_set_surface_scale(RENDER_SUPERSAMPLE)
	_pose_forge_stack(stack_position, MERGE_PRESS_SCALE, 1.0)

	# The forge itself lights the card up gold for the length of the burn.
	if _glow != null:
		_glow.set_active(true, OutlineGlow.Preset.ARCANE_GOLD)

	_start_weld_burn()
	_start_brand_pop()


## Draws the molten seam over the two pressed plates (and the forged card under
## them). It is mounted in `bounds`, last, so it welds across the plates rather
## than being hidden behind them.
func _build_weld_overlay(double_merged: bool) -> void:
	_clear_weld_overlay()
	if not is_instance_valid(_visual_root):
		return

	_weld_material = ShaderMaterial.new()
	_weld_material.shader = KINTSUGI_SHADER
	_weld_material.set_shader_parameter("quad_size", QUAD_SIZE)
	_weld_material.set_shader_parameter("card_size", CARD_SIZE)
	_weld_material.set_shader_parameter("corner_radius", CARD_CORNER_RADIUS)
	_weld_material.set_shader_parameter("is_double_merge", double_merged)
	# A fresh fracture pattern per forge, so no two welds look alike.
	_weld_material.set_shader_parameter("seam_seed", randf() * 37.0)
	_weld_material.set_shader_parameter("progress", 0.0)

	_weld_overlay = ColorRect.new()
	_weld_overlay.name = "KintsugiWeld"
	_weld_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weld_overlay.color = Color.WHITE
	_weld_overlay.material = _weld_material
	_weld_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_weld_overlay.position = -CARD_PADDING
	_weld_overlay.size = QUAD_SIZE
	# Pivot on the card's bottom-centre, matching the card and the plates, so the
	# seam stays welded to them at any press scale.
	_weld_overlay.pivot_offset = Vector2(
		QUAD_SIZE.x * 0.5, CARD_PADDING.y + CARD_SIZE.y
	)
	bounds.add_child(_weld_overlay)


func _start_weld_burn() -> void:
	if _weld_material == null:
		return
	_weld_tween = create_tween()
	_weld_tween.set_trans(Tween.TRANS_LINEAR)
	_weld_tween.tween_method(_set_weld_progress, 0.0, 1.0, MERGE_BURN_TIME)


func _set_weld_progress(value: float) -> void:
	if _weld_material != null:
		_weld_material.set_shader_parameter("progress", value)


## Brands the new value and star rank onto the face with a stamp, so the number
## the merge produced lands after the seam does instead of appearing silently.
func _start_brand_pop() -> void:
	var targets: Array[Control] = []
	if is_instance_valid(value_label):
		targets.append(value_label)
	if is_instance_valid(icon_row):
		targets.append(icon_row)
	if targets.is_empty():
		return

	for target: Control in targets:
		target.pivot_offset = target.size * 0.5
		target.scale = Vector2.ONE * MERGE_BRAND_SCALE

	_brand_tween = create_tween()
	_brand_tween.set_parallel(true)
	_brand_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	for target: Control in targets:
		_brand_tween.tween_property(
			target, "scale", Vector2.ONE, MERGE_BRAND_TIME
		).set_delay(MERGE_BRAND_DELAY)


## Tears down every temporary forge object and leaves the card resting flat, so
## nothing of the forge survives on a card that is simply sitting in hand.
func _end_forge_state() -> void:
	_is_merging = false
	_clear_forge_ghosts()
	_clear_weld_overlay()

	if _weld_tween != null and _weld_tween.is_valid():
		_weld_tween.kill()
	_weld_tween = null
	if _brand_tween != null and _brand_tween.is_valid():
		_brand_tween.kill()
	_brand_tween = null

	_apply_flat_pose()
	_refresh_glow()


func _clear_forge_ghosts() -> void:
	_discard_ghost(_forge_ghost_a)
	_discard_ghost(_forge_ghost_b)
	_forge_ghost_a = null
	_forge_ghost_b = null


func _clear_weld_overlay() -> void:
	if is_instance_valid(_weld_overlay):
		_weld_overlay.free()
	_weld_overlay = null
	_weld_material = null


## Tween-friendly accelerating slam, so the plates arrive with weight.
static func _ease_in_quart(x: float) -> float:
	return x * x * x * x
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
	_apply_rank_style()


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
	# The same goes for a card whose weld is still burning: a merged card can be
	# played (or merged again) the instant it exists.
	_finish_draw_immediate()
	_finish_merge_immediate()

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
