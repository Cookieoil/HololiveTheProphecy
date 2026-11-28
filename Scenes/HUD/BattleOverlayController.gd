# res://Scenes/HUD/BattleOverlayController.gd
class_name BattleOverlayController
extends Node
## Builds E1–E3 on the left, A1–A3 on the right, manages the tooltip layer,
## and safely bridges UnitUI hover & wave transitions without freed-instance errors.

signal ally_ultimate_requested(ally: Unit)

## How long the rails take to step off stage when the battle ends.
const RAIL_RETREAT_TIME: float = 0.22

var icon_catalog: CardIconCatalog
var tooltip_icon_catalog: TooltipIconCatalog
var game_manager: Node # GameManager
## The scene whose `EntityOverlay/AlliesRow` and `EnemiesRow` this controller binds to.
## Left unset it defaults to the scene root that owns this node; a test can inject a
## stand-in. The rows are resolved from it, never by walking up the tree.
var scene_root: Node

var _rail_layer: CanvasLayer
var _enemy_rail: VBoxContainer
var _ally_rail: VBoxContainer

var _tooltip_layer: CanvasLayer
var _tooltip: SkillTooltipPopup

var _orbs_by_unit: Dictionary[Unit, MoxieOrbUI] = {} # Unit -> MoxieOrbUI
var _units_to_ui: Dictionary[Unit, UnitUI] = {}      # Unit -> UnitUI
var _current_ally_units: Array[Unit] = []
var _current_enemy_units: Array[Unit] = []

var _allies_row: Control
var _enemies_row: Control
var _player_input_enabled: bool = false
var _auto_sync_queued: bool = false


func _ready() -> void:
	if tooltip_icon_catalog == null:
		tooltip_icon_catalog = TooltipIconCatalog.new()
	_build_rails()
	_build_tooltip()
	# Typed signal connections (EventBus is the autoload), matching the rest of
	# the codebase. No string-based connect() and no has_signal() guards needed.
	EventBus.ultimate_cast.connect(_on_ultimate_cast)
	EventBus.wave_started.connect(_on_wave_or_turn_changed)
	EventBus.turn_started.connect(_on_wave_or_turn_changed)
	EventBus.game_over.connect(_on_game_over)
	call_deferred("_auto_bind_scene_rows")


func setup(
	p_game_manager: Node,
	p_icon_catalog: CardIconCatalog,
	p_tooltip_icon_catalog: TooltipIconCatalog = null
) -> void:
	game_manager = p_game_manager
	icon_catalog = p_icon_catalog
	if p_tooltip_icon_catalog != null:
		tooltip_icon_catalog = p_tooltip_icon_catalog
	elif tooltip_icon_catalog == null:
		tooltip_icon_catalog = TooltipIconCatalog.new()
	if _tooltip != null:
		_tooltip.icon_catalog = icon_catalog
	_auto_bind_scene_rows()


## Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
func rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void:
	var live_allies: Array[UnitUI] = _live_uis(ally_uis)
	var live_enemies: Array[UnitUI] = _live_uis(enemy_uis)

	# Re-bind the live nodes first, so the rails below can read each unit's portrait.
	_units_to_ui.clear()
	_rebind_uis(live_enemies)
	_rebind_uis(live_allies)

	_sync_rail(_enemy_rail, live_enemies, "E", true)
	_sync_rail(_ally_rail, live_allies, "A", false)

	sync_enemy_intent_previews()


## The UnitUI nodes that are still usable. A freed node, one already on its way out, or
## one that was never bound to a unit is not evidence of who is on the board.
func _live_uis(candidates: Array[UnitUI]) -> Array[UnitUI]:
	var live: Array[UnitUI] = []
	for uui: UnitUI in candidates:
		if _is_live_unit_ui(uui):
			live.append(uui)
	return live


## Records which UnitUI draws each unit, and refreshes the portrait the matching orb is
## already showing so a re-bind never waits for the next rebuild to look right.
func _rebind_uis(uis: Array[UnitUI]) -> void:
	for uui: UnitUI in uis:
		_bind_unit_ui(uui)
		var orb: MoxieOrbUI = _get_valid_orb(uui.unit)
		if orb != null:
			orb.set_portrait(_extract_unit_portrait(uui, uui.unit))


func _units_of(uis: Array[UnitUI]) -> Array[Unit]:
	var units: Array[Unit] = []
	for uui: UnitUI in uis:
		units.append(uui.unit)
	return units


## Rebuilds one rail's orbs only when the unit list actually changed or an orb was freed.
## BattleScene re-enters this after every action, and rebuilding orbs on each of those
## would restart their animations in the middle of a turn.
func _sync_rail(rail: VBoxContainer, uis: Array[UnitUI], badge_prefix: String, is_enemy: bool) -> void:
	var units: Array[Unit] = _units_of(uis)
	var previous: Array[Unit] = _current_enemy_units if is_enemy else _current_ally_units
	if _same_units_and_valid_orbs(previous, units):
		if not is_enemy:
			set_player_turn_interactive(_player_input_enabled)
		return
	for unit: Unit in previous:
		_orbs_by_unit.erase(unit)
	_clear_container(rail)
	if is_enemy:
		_current_enemy_units = units
	else:
		_current_ally_units = units
	for index: int in range(uis.size()):
		var uui: UnitUI = uis[index]
		var orb: MoxieOrbUI = _spawn_orb(rail, uui.unit, "%s%d" % [badge_prefix, index + 1], uui)
		if not is_enemy:
			orb.set_interactable(_player_input_enabled)
		_orbs_by_unit[uui.unit] = orb


## Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
func set_player_turn_interactive(enabled: bool) -> void:
	_player_input_enabled = enabled
	for u: Unit in _orbs_by_unit.keys().duplicate():
		if u == null or not u.is_ally:
			continue
		var orb := _get_valid_orb(u)
		if orb != null:
			orb.set_interactable(enabled)


## Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
func sync_enemy_intent_previews() -> void:
	for u: Unit in _orbs_by_unit.keys().duplicate():
		if u == null or u.is_ally:
			continue

		var intent := _find_intent_for_enemy(u)
		var orb := _get_valid_orb(u)
		if orb != null:
			orb.set_preview_gain(intent.effective_value if intent != null and not u.is_dead else 0)

		var uui := _get_valid_unit_ui(u)
		if uui != null and uui.has_method("set_intent_ult_warning"):
			uui.set_intent_ult_warning(intent != null and intent.will_trigger_ultimate())


func clear_enemy_intent_previews() -> void:
	for u: Unit in _orbs_by_unit.keys().duplicate():
		if u == null or u.is_ally:
			continue

		var orb := _get_valid_orb(u)
		if orb != null:
			orb.set_preview_gain(0)

		var uui := _get_valid_unit_ui(u)
		if uui != null and uui.has_method("set_intent_ult_warning"):
			uui.set_intent_ult_warning(false)


## The battle is over: the rails are combat chrome, so they step off stage and
## leave the battlefield - and the result cutscene - alone on screen. Awaited by
## the caller, so the stage is clear before the cutscene starts.
func retreat_for_result() -> void:
	if _enemy_rail == null and _ally_rail == null:
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for rail: VBoxContainer in [_enemy_rail, _ally_rail]:
		if rail != null:
			tween.tween_property(rail, "modulate:a", 0.0, RAIL_RETREAT_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


## Exposes the shared skill callout so tooling (the UI snapshot runner) can render a
## populated tooltip without synthesising mouse hover.
func get_skill_tooltip() -> SkillTooltipPopup:
	return _tooltip


## Shows the ally Ultimate callout for the unit at `index`, anchored on its orb, and
## returns true once it was shown. Tooling/test seam: the real path is a hover.
func show_ally_ultimate_callout(index: int) -> bool:
	if index < 0 or index >= _current_ally_units.size():
		return false
	var unit: Unit = _current_ally_units[index]
	var orb: MoxieOrbUI = _get_valid_orb(unit)
	if orb == null:
		return false
	_on_orb_hover_started(orb, unit)
	return true


#region Safe Instance Lookup & Auto Row Sync

func _is_live_unit_ui(raw: Variant) -> bool:
	if raw == null or not is_instance_valid(raw):
		return false
	if not (raw is UnitUI):
		return false
	var uui: UnitUI = raw
	if uui.is_queued_for_deletion():
		return false
	return uui.unit != null


func _get_valid_orb(u: Unit) -> MoxieOrbUI:
	if u == null or not _orbs_by_unit.has(u):
		return null
	var orb: MoxieOrbUI = _orbs_by_unit[u]
	if orb == null or not is_instance_valid(orb) or orb.is_queued_for_deletion():
		_orbs_by_unit.erase(u)
		return null
	return orb


func _get_valid_unit_ui(u: Unit) -> UnitUI:
	if u == null:
		return null
	if _units_to_ui.has(u):
		var cached_uui: UnitUI = _units_to_ui[u]
		if _is_live_unit_ui(cached_uui) and cached_uui.unit == u:
			return cached_uui
		_units_to_ui.erase(u)

	# Fallback: if BattleScene just replaced UnitUIs this frame, find & bind the live one immediately
	var row: Control = _allies_row if u.is_ally else _enemies_row
	if row != null and is_instance_valid(row):
		for child: Node in row.get_children():
			var found: UnitUI = child as UnitUI
			if found != null and _is_live_unit_ui(found) and found.unit == u:
				_bind_unit_ui(found)
				return found
	return null


func _same_units_and_valid_orbs(old_list: Array[Unit], new_list: Array[Unit]) -> bool:
	if old_list.size() != new_list.size() or old_list.is_empty():
		return false
	for i in range(old_list.size()):
		if old_list[i] != new_list[i]:
			return false
		if _get_valid_orb(new_list[i]) == null:
			return false
	return true


func _auto_bind_scene_rows() -> void:
	# The rows live in the scene this controller was placed in, so they are resolved
	# from that scene's root - `owner` by default, or the `scene_root` a test injects.
	# The controller never walks up looking for the scene it is already part of.
	var root: Node = scene_root if scene_root != null else owner
	if root == null:
		return
	if _allies_row == null:
		_allies_row = root.get_node_or_null("EntityOverlay/AlliesRow") as Control
		if _allies_row != null:
			_allies_row.child_entered_tree.connect(_on_row_children_changed)
			_allies_row.child_exiting_tree.connect(_on_row_children_changed)
	if _enemies_row == null:
		_enemies_row = root.get_node_or_null("EntityOverlay/EnemiesRow") as Control
		if _enemies_row != null:
			_enemies_row.child_entered_tree.connect(_on_row_children_changed)
			_enemies_row.child_exiting_tree.connect(_on_row_children_changed)
	_queue_auto_sync()


func _on_row_children_changed(_node: Node) -> void:
	_queue_auto_sync()


func _on_wave_or_turn_changed(_idx: int) -> void:
	_queue_auto_sync()


func _queue_auto_sync() -> void:
	if _auto_sync_queued:
		return
	_auto_sync_queued = true
	call_deferred("_run_auto_sync")


func _run_auto_sync() -> void:
	_auto_sync_queued = false
	if _allies_row == null or _enemies_row == null:
		return
	var ally_uis: Array[UnitUI] = []
	for c in _allies_row.get_children():
		if _is_live_unit_ui(c):
			ally_uis.append(c as UnitUI)
	var enemy_uis: Array[UnitUI] = []
	for c in _enemies_row.get_children():
		if _is_live_unit_ui(c):
			enemy_uis.append(c as UnitUI)
	if not ally_uis.is_empty() or not enemy_uis.is_empty():
		rebuild_for_units(ally_uis, enemy_uis)


func _clear_container(box: Container) -> void:
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

#endregion


#region Internal Builders & Signal Handlers

# Derive rail width from the orb's own size so scaling MoxieOrbUI
func _build_rails() -> void:
	_rail_layer = CanvasLayer.new()
	_rail_layer.name = "MoxieRailsLayer"
	_rail_layer.layer = 3
	add_child(_rail_layer)

	var rail_w: float = MoxieOrbUI.MEDALLION_SIZE.x + 16.0
	var side_gap: float = 14.0

	_enemy_rail = VBoxContainer.new()
	_enemy_rail.name = "EnemyMoxieRail"
	_enemy_rail.anchor_top = 0.5
	_enemy_rail.anchor_bottom = 0.5
	_enemy_rail.offset_left = side_gap
	_enemy_rail.offset_right = side_gap + rail_w
	_enemy_rail.offset_top = -205.0
	_enemy_rail.offset_bottom = 135.0
	_enemy_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_rail.add_theme_constant_override("separation", 8)
	_enemy_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_layer.add_child(_enemy_rail)

	_ally_rail = VBoxContainer.new()
	_ally_rail.name = "AllyMoxieRail"
	_ally_rail.anchor_left = 1.0
	_ally_rail.anchor_right = 1.0
	_ally_rail.anchor_top = 0.5
	_ally_rail.anchor_bottom = 0.5
	_ally_rail.offset_left = -(side_gap + rail_w)
	_ally_rail.offset_right = -side_gap
	_ally_rail.offset_top = -205.0
	_ally_rail.offset_bottom = 135.0
	_ally_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	_ally_rail.add_theme_constant_override("separation", 8)
	_ally_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_layer.add_child(_ally_rail)


func _build_tooltip() -> void:
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = 10
	add_child(_tooltip_layer)

	_tooltip = SkillTooltipPopup.new()
	_tooltip.icon_catalog = icon_catalog
	_tooltip_layer.add_child(_tooltip)


func _spawn_orb(parent: BoxContainer, unit: Unit, code: String, uui: UnitUI = null) -> MoxieOrbUI:
	var orb := MoxieOrbUI.new()
	parent.add_child(orb)
	orb.bind_unit(unit, code, _extract_unit_portrait(uui, unit))
	orb.orb_activated.connect(_on_orb_activated)
	orb.orb_hover_started.connect(_on_orb_hover_started)
	orb.orb_hover_ended.connect(_on_orb_hover_ended)
	return orb


func _extract_unit_portrait(uui: UnitUI, unit: Unit) -> Texture2D:
	# 1. Check UnitData first (e.g. @export var portrait: Texture2D)
	if unit != null and unit.data != null:
		for prop: String in ["portrait", "avatar", "icon", "unit_portrait", "texture"]:
			var val: Variant = unit.data.get(prop)
			if val is Texture2D:
				var tex: Texture2D = val
				return tex

	# 2. Fallback: extract frame 0 / portrait texture directly from UnitUI
	if uui == null or not is_instance_valid(uui):
		return null
	for prop: String in ["portrait", "portrait_texture"]:
		var val: Variant = uui.get(prop)
		if val is Texture2D:
			var tex: Texture2D = val
			return tex

	return _find_character_texture_in_node(uui)


func _find_character_texture_in_node(root: Node) -> Texture2D:
	for child: Node in root.get_children():
		if _is_chrome_node(child):
			continue
		var own: Texture2D = _texture_of(child)
		if own != null:
			return own
		var nested: Texture2D = _find_character_texture_in_node(child)
		if nested != null:
			return nested
	return null


## Chrome whose textures are icons and bars rather than the unit's face. It is skipped by
## name because the row draws intent, shield and status art with textures that would
## otherwise be mistaken for a portrait.
func _is_chrome_node(node: Node) -> bool:
	var node_name: String = node.name.to_lower()
	return (
		node_name.contains("intent") or node_name.contains("shield")
		or node_name.contains("status") or node_name.contains("icon")
	)


## The texture this node itself draws, if it is the kind a row uses for a portrait.
func _texture_of(node: Node) -> Texture2D:
	if node is AnimatedSprite2D:
		return _animation_frame(node as AnimatedSprite2D)
	if node is Sprite2D:
		return _sprite_texture(node as Sprite2D)
	if node is TextureRect:
		return _rect_texture(node as TextureRect)
	return null


## Frame 0 of the clip the sprite is playing, falling back to whichever clip the sheet
## actually has: a unit whose named animation is missing still shows a face.
func _animation_frame(sprite: AnimatedSprite2D) -> Texture2D:
	if sprite.sprite_frames == null:
		return null
	var animation: StringName = sprite.animation
	if not sprite.sprite_frames.has_animation(animation):
		var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if names.is_empty():
			return null
		animation = names[0]
	if not sprite.sprite_frames.has_animation(animation):
		return null
	if sprite.sprite_frames.get_frame_count(animation) <= 0:
		return null
	return sprite.sprite_frames.get_frame_texture(animation, 0)


## A sprite sheet is handed over as a one-frame atlas so the orb shows a face rather than
## the whole strip; a plain sprite is handed over untouched.
func _sprite_texture(sprite: Sprite2D) -> Texture2D:
	if sprite.texture == null:
		return null
	if not (sprite.hframes > 1 or sprite.vframes > 1 or sprite.region_enabled):
		return sprite.texture
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sprite.texture
	if sprite.region_enabled:
		atlas.region = sprite.region_rect
	else:
		var frame_width: float = sprite.texture.get_width() / float(maxi(1, sprite.hframes))
		var frame_height: float = sprite.texture.get_height() / float(maxi(1, sprite.vframes))
		atlas.region = Rect2(0.0, 0.0, frame_width, frame_height)
	return atlas


## A TextureRect only counts when it is portrait-sized: the row also draws 16px category
## icons this way.
func _rect_texture(rect: TextureRect) -> Texture2D:
	if rect.texture == null or rect.size.x < 32.0 or rect.size.y < 32.0:
		return null
	return rect.texture


func _bind_unit_ui(uui: UnitUI) -> void:
	if not _is_live_unit_ui(uui):
		return
	_units_to_ui[uui.unit] = uui
	if uui.has_signal("card_hover_started") and not uui.card_hover_started.is_connected(_on_unit_card_hover_started):
		uui.card_hover_started.connect(_on_unit_card_hover_started)
	if uui.has_signal("card_hover_ended") and not uui.card_hover_ended.is_connected(_on_unit_card_hover_ended):
		uui.card_hover_ended.connect(_on_unit_card_hover_ended)
	if uui.has_signal("intent_hover_started") and not uui.intent_hover_started.is_connected(_on_unit_intent_hover_started):
		uui.intent_hover_started.connect(_on_unit_intent_hover_started)
	if uui.has_signal("intent_hover_ended") and not uui.intent_hover_ended.is_connected(_on_unit_intent_hover_ended):
		uui.intent_hover_ended.connect(_on_unit_intent_hover_ended)


func _get_state() -> GameState:
	if game_manager != null and is_instance_valid(game_manager):
		var raw_state: Variant = game_manager.get("state")
		if raw_state is GameState:
			var gs: GameState = raw_state
			return gs
	return null


func _find_intent_for_enemy(enemy: Unit) -> EnemyIntent:
	if game_manager == null or not is_instance_valid(game_manager):
		return null
	var intents: Variant = game_manager.get("current_intents")
	if intents is Array:
		var intent_arr: Array = intents
		for it: Variant in intent_arr:
			if it is EnemyIntent:
				var ei: EnemyIntent = it
				if ei.enemy == enemy:
					return ei
	return null


func _on_unit_card_hover_started(unit: Unit, card: Card, anchor_rect: Rect2) -> void:
	var data := SkillPreviewFormatter.build_card_on_ally_data(
		unit, card, _get_state(), tooltip_icon_catalog
	)
	_tooltip.show_callout(data, anchor_rect)

	var orb := _get_valid_orb(unit)
	if orb != null and card != null:
		orb.set_preview_gain(card.get_effective_value())


func _on_unit_card_hover_ended(unit: Unit) -> void:
	_tooltip.hide_callout()
	var orb := _get_valid_orb(unit)
	if orb != null:
		orb.set_preview_gain(0)


func _on_unit_intent_hover_started(unit: Unit, anchor_rect: Rect2) -> void:
	var intent := _find_intent_for_enemy(unit)
	if intent == null:
		return
	var data := SkillPreviewFormatter.build_enemy_intent_data(
		intent, _get_state(), tooltip_icon_catalog
	)
	_tooltip.show_callout(data, anchor_rect)


func _on_unit_intent_hover_ended(_unit: Unit) -> void:
	_tooltip.hide_callout()


func _on_orb_hover_started(orb: MoxieOrbUI, unit: Unit) -> void:
	if get_viewport().gui_is_dragging():
		return
	var intent := _find_intent_for_enemy(unit) if not unit.is_ally else null
	var data := SkillPreviewFormatter.build_orb_ultimate_data(
		unit, orb.badge_code, _get_state(), intent, tooltip_icon_catalog
	)
	_tooltip.show_callout(data, orb.get_global_rect())

	var uui := _get_valid_unit_ui(unit)
	if uui != null and not unit.is_dead and uui.has_method("set_orb_linked_highlight"):
		uui.set_orb_linked_highlight(true)


func _on_orb_hover_ended(_orb: MoxieOrbUI, unit: Unit) -> void:
	_tooltip.hide_callout()
	var uui := _get_valid_unit_ui(unit)
	if uui != null and uui.has_method("set_orb_linked_highlight"):
		uui.set_orb_linked_highlight(false)


func _on_orb_activated(unit: Unit) -> void:
	_tooltip.hide_callout()
	if _player_input_enabled and unit != null and unit.can_cast_ultimate:
		ally_ultimate_requested.emit(unit)


func _on_ultimate_cast(caster: Unit, _skill_name: String) -> void:
	var orb := _get_valid_orb(caster)
	if orb != null:
		orb.play_cast_burst()


## The battle is over: nothing on the rails is actionable anymore, so the open
## tooltip is dismissed, every orb stops accepting clicks and every pending
## preview segment (enemy rolls included) is released.
func _on_game_over(_victory: bool) -> void:
	if _tooltip != null:
		_tooltip.hide_callout()
	set_player_turn_interactive(false)
	for u: Unit in _orbs_by_unit.keys().duplicate():
		var orb := _get_valid_orb(u)
		if orb != null:
			orb.set_preview_gain(0)
		var uui := _get_valid_unit_ui(u)
		if uui != null and uui.has_method("set_orb_linked_highlight"):
			uui.set_orb_linked_highlight(false)

#endregion
