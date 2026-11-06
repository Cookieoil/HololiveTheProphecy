# CardUI.gd
class_name CardUI
extends PanelContainer
## Visual representation of one Card in hand.
## Drag source (play / merge) and drop target (merge only).

signal play_requested(card: Card)

const DRAG_PREVIEW_SIZE: Vector2 = Vector2(100, 145)
const DRAG_PREVIEW_SCALE: float = 1.04
const DRAG_SOURCE_ALPHA: float = 0.0 # Hide the source card
const RETURN_TWEEN_TIME: float = 0.18
const RETURN_CANVAS_LAYER: int = 100
const PLACEHOLDER_ICON: Texture2D = preload("res://Trash/icon.svg")

const HOVER_SCALE: float = 1.12
const HOVER_LIFT: float = 18.0
const HOVER_TWEEN_TIME: float = 0.12
const HOVER_Z_INDEX: int = 20

@export var icon_catalog: IconCatalog

var card: Card
var hand_bar: HandBar

var _hover_tween: Tween
var _is_hovered: bool = false

var _drag_in_progress: bool = false
var _return_tween: Tween
var _return_layer: CanvasLayer

@onready var hover_visual: PanelContainer = $Bounds/HoverVisual
@onready var icon_row: HBoxContainer = $Bounds/HoverVisual/Margin/VBox/IconRow
@onready var art: TextureRect = $Bounds/HoverVisual/Margin/VBox/Art
@onready var value_label: Label = $Bounds/HoverVisual/Margin/VBox/ValueLabel
@onready var merge_glow: Panel = $Bounds/HoverVisual/MergeGlow


func _ready() -> void:
	# The scaled visual must be allowed to draw outside the fixed slot.
	clip_contents = false

	# This root is now only the stable layout/input slot.
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_style_card_panel()
	_style_merge_glow()

	# None of the visual children should participate in GUI hit-testing.
	# Consequently, the enlarged drawing cannot obstruct neighboring cards.
	_set_mouse_filter_recursive(hover_visual)

	_update_hover_pivot()
	hover_visual.resized.connect(_update_hover_pivot)

	mouse_entered.connect(_on_card_mouse_entered)
	mouse_exited.connect(_on_card_mouse_exited)


func _process(_delta: float) -> void:
	# Immediately clear merge highlight if the cursor leaves this card while dragging.
	if merge_glow and merge_glow.visible:
		if not get_viewport().gui_is_dragging() \
				or not get_global_rect().has_point(get_global_mouse_position()):
			merge_glow.visible = false


func _exit_tree() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	
	_hover_tween = null
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

# --- Hover animation ---------------------------------------------------------

func _update_hover_pivot() -> void:
	if not is_instance_valid(hover_visual):
		return

	# Scaling around the bottom-center makes the card grow primarily upward
	# instead of appearing to expand equally in every direction.
	hover_visual.pivot_offset = Vector2(
		hover_visual.size.x * 0.5,
		hover_visual.size.y
	)


func _on_card_mouse_entered() -> void:
	if _drag_in_progress or get_viewport().gui_is_dragging():
		return

	_animate_hover(true)


func _on_card_mouse_exited() -> void:
	if _drag_in_progress:
		return

	_animate_hover(false)


func _animate_hover(active: bool) -> void:
	_is_hovered = active

	# Kill only this card's previous hover tween. Starting a new tween from
	# the current values avoids jumps and additive-position bugs when the
	# player moves quickly between cards.
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()

	# Draw the hovered card above its siblings. This changes drawing order,
	# not the fixed GUI hit areas.
	z_index = HOVER_Z_INDEX if active else 0

	var target_scale := Vector2.ONE * HOVER_SCALE if active else Vector2.ONE
	var target_y: float = -HOVER_LIFT if active else 0.0

	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_CUBIC)

	_hover_tween.tween_property(
		hover_visual,
		"scale",
		target_scale,
		HOVER_TWEEN_TIME
	)
	_hover_tween.parallel().tween_property(
		hover_visual,
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

	if is_instance_valid(hover_visual):
		hover_visual.scale = Vector2.ONE
		hover_visual.position = Vector2.ZERO
		
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


# --- Drag source -------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null or _drag_in_progress:
		return null

	var hb := _find_hand_bar()
	if hb == null:
		return null

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

# Reuse the real card appearance instead of maintaining a second,
# simplified preview layout that can drift out of sync with CardUI.
func _make_visual_copy() -> PanelContainer:
	var visual := duplicate() as PanelContainer
	visual.set_script(null)
	visual.name = "DragCardVisual"

	visual.custom_minimum_size = DRAG_PREVIEW_SIZE
	visual.size = DRAG_PREVIEW_SIZE
	visual.modulate = Color.WHITE
	visual.self_modulate = Color.WHITE
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.z_index = 0

	var copied_hover := visual.get_node_or_null("Bounds/HoverVisual") as Control
	if copied_hover != null:
		copied_hover.position = Vector2.ZERO
		copied_hover.scale = Vector2.ONE
		copied_hover.pivot_offset = Vector2(
			DRAG_PREVIEW_SIZE.x * 0.5,
			DRAG_PREVIEW_SIZE.y
		)

	var copied_glow := visual.get_node_or_null(
		"Bounds/HoverVisual/MergeGlow"
	) as Control
	if copied_glow != null:
		copied_glow.hide()

	_set_mouse_filter_recursive(visual)
	return visual


func _set_mouse_filter_recursive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in control.get_children():
		if child is Control:
			_set_mouse_filter_recursive(child as Control)


# --- Drag completion and cancellation ---------------------------------------

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
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var hb := _find_hand_bar()
	var st: GameState = hb._get_game_state() if hb != null else null
	if st == null or st.hand.has(card):
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

# --- Merge drop target -------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var drag: CardDrag = data as CardDrag
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
	var drag: CardDrag = data as CardDrag
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
