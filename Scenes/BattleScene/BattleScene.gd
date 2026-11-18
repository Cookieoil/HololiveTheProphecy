# BattleScene.gd
class_name BattleScene
extends GameUI

@export var icon_catalog: CardIconCatalog
@export var status_icon_catalog: StatusIconCatalog
@export var tooltip_icon_catalog: TooltipIconCatalog
@export var unit_ui_scene: PackedScene = preload("res://Scenes/BattleUnit/UnitUI.tscn")
@export var turn_dice_progression: Array[int] = []

@onready var hand_bar: HandBar = $HUD/HandBar
@onready var allies_container: HBoxContainer = $EntityOverlay/AlliesRow
@onready var enemies_container: HBoxContainer = $EntityOverlay/EnemiesRow

@onready var battle_overlay: BattleOverlayController = $BattleOverlay

@onready var wave_value_label: Label = $HUD/TopBar/Margin/HBox/LeftGroup/WaveStat/Value
@onready var dice_value_label: Label = $HUD/TopBar/Margin/HBox/LeftGroup/DiceStat/Value
@onready var actions_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/ActionsStat/Value
@onready var merges_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/MergesStat/Value
@onready var resource_label: Label = $HUD/TopBar/Margin/HBox/RightGroup/ResourceLabel
@onready var convert_button: Button = $HUD/TopBar/Margin/HBox/RightGroup/ConvertButton
@onready var end_turn_button: Button = $HUD/TopBar/Margin/HBox/RightGroup/EndTurnButton
@onready var log_label: Label = $HUD/MessageLog

var game_manager: GameManager
var _intent_cache: Dictionary[Unit, Dictionary] = {}

signal action_decided(action_dict: Dictionary)
signal unit_selected_for_target(unit: Unit)

## seconds between each enemy's intent appearing
const INTENT_STAGGER: float = 0.08

func _ready() -> void:
	if status_icon_catalog == null:
		status_icon_catalog = StatusIconCatalog.new()
	if tooltip_icon_catalog == null:
		tooltip_icon_catalog = TooltipIconCatalog.new()

	end_turn_button.pressed.connect(func() -> void: action_decided.emit({"type": "end_turn"}))
	convert_button.pressed.connect(func() -> void: action_decided.emit({"type": "convert"}))
	hand_bar.merge_requested.connect(_on_merge_requested)

	game_manager = GameManager.new()
	add_child(game_manager)

	# wire overlay right after game_manager exists, before setup_game
	# so that show_game_state() -> _sync_overlay_units() has a valid overlay
	battle_overlay.setup(game_manager, icon_catalog, tooltip_icon_catalog)
	battle_overlay.ally_ultimate_requested.connect(_on_ally_ultimate_requested)

	var db: GameDatabase = DataLoader.db()
	var ally_ids: Array = db.config.get("allies", ["striker", "healer", "buff"])
	var ally_data: Array[UnitData] = []
	for id: String in ally_ids:
		if db.units.has(id):
			var ud: UnitData = db.units[id]
			ally_data.append(ud)

	var config: Dictionary = db.config.duplicate()
	if not turn_dice_progression.is_empty():
		config["dice_progression"] = turn_dice_progression

	await game_manager.setup_game(ally_data, db.waves, self, config)


#region GameUI Overrides

func on_card_played(card: Card, state: GameState) -> void:
	hand_bar.remove_card(card)   # animated collapse
	_update_top_bar(state)       # Actions counter updates immediately too

## Two cards in hand were fused into `result`: the hand plays the merge (the two
## cards drift into each other from where they were dropped, fold closed, and the
## merged card opens back out of that fold), then the merge counter updates
## immediately so the top bar never lags the animation.
func on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void:
	hand_bar.play_merge(source_a, source_b, result, state.hand)
	_update_top_bar(state)

## Cards the game selected without asking (auto_top_n / auto_highest) get a
## short highlight so the player can see what was picked for them.
## `hostile` is set when an enemy caused the change; those cards flash red.
func flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void:
	await hand_bar.flash_auto_selected(cards, hostile)

## `lead` is the fraction of the skill animation to wait for: 1.0 for the
## player's own actions, lower for chained enemy turns that overlap their
## animations (see GameManager.ENEMY_SKILL_OVERLAP_LEAD).
func play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void:
	var unit_ui := _get_unit_ui(unit)
	if unit_ui == null:
		push_warning("BattleScene.play_unit_skill(): no UnitUI found for %s" % unit)
		return
	await unit_ui.play_skill_animation(skill_index, rank, lead)

# GameUI ultimate override
func play_unit_ultimate(unit: Unit) -> void:
	var uui := _get_unit_ui(unit)  # existing Unit -> UnitUI lookup
	if uui != null:
		await uui.play_ultimate_animation()

func show_message(msg: String) -> void:
	log_label.text = msg
	var t := create_tween()
	t.tween_property(log_label, "modulate:a", 1.0, 0.1)
	t.tween_interval(1.8)
	t.tween_property(log_label, "modulate:a", 0.0, 0.4)


func show_game_state(state: GameState) -> void:
	hand_bar.game_state = state
	hand_bar.set_hand(state.hand)
	_update_top_bar(state)
	_sync_unit_row(enemies_container, state.enemies, false)
	_sync_unit_row(allies_container, state.allies, true)
	_sync_overlay_units()   # refresh A1/A2/A3 & E1/E2/E3 rails


func show_hand_and_resources(state: GameState) -> void:
	_update_top_bar(state)
	hand_bar.game_state = state
	hand_bar.set_hand(state.hand)


func _update_top_bar(state: GameState) -> void:
	if state == null:
		return
	var wave_num: int = state.current_wave + 1

	wave_value_label.text = str(wave_num)
	dice_value_label.text = str(state.get_dice_size(state.turn_number))
	actions_value_label.text = str(state.actions_left)
	merges_value_label.text = str(state.merges_left)
	resource_label.text = "Deck: %d | Discard: %d" % [state.deck.size(), state.discard.size()]


func show_enemy_intents(intents: Array[EnemyIntent]) -> void:
	_intent_cache.clear()
	for i in intents.size():
		var intent := intents[i]
		_intent_cache[intent.enemy] = {
			"text": "Roll %d: %s" % [intent.effective_value, intent.skill.skill_name],
			"categories": intent.skill.get_active_categories(intent.condition_met),
			"order": i,
		}
	_apply_cached_intents()

	# mirror the same intents onto the overlay E1–E3 previews
	battle_overlay.sync_enemy_intent_previews()


func clear_unit_intent(unit: Unit) -> void:
	_intent_cache.erase(unit)  # so a later row rebuild can't bring it back
	var u_ui := _get_unit_ui(unit)
	if u_ui:
		u_ui.clear_intent(true)


func _apply_cached_intents() -> void:
	for child in enemies_container.get_children():
		var u_ui := child as UnitUI
		if u_ui and not u_ui.is_queued_for_deletion():
			_apply_intent_to(u_ui)


func _apply_intent_to(u_ui: UnitUI) -> void:
	var entry: Dictionary = _intent_cache.get(u_ui.unit, {})
	if entry.is_empty() or u_ui.unit.is_dead:
		u_ui.clear_intent()
	else:
		var intent_text: String = entry["text"]
		var intent_cats: PackedStringArray = entry["categories"]
		var intent_order: int = entry["order"]
		u_ui.show_intent(
			intent_text,
			intent_cats,
			intent_order * INTENT_STAGGER
		)


# NOTE: GameUI calls this `ask_player_action` in the wiring brief;
# in this file it is already named `get_player_action`. Behaviour is unchanged.
func get_player_action(_state: GameState) -> Dictionary:
	end_turn_button.disabled = false
	convert_button.disabled = false

	# enable A1/A2/A3 orbs while awaiting player input
	battle_overlay.set_player_turn_interactive(true)

	var action: Dictionary = await action_decided

	battle_overlay.set_player_turn_interactive(false)
	end_turn_button.disabled = true
	convert_button.disabled = true
	return action


func ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]:
	if units.is_empty():
		return []

	if units.size() <= count:
		return units.duplicate()

	show_message("Click %d target(s) to attack!" % count)
	_highlight_target_candidates(units, true)

	var chosen: Array[Unit] = []
	var available: Array[Unit] = units.duplicate()

	while chosen.size() < count and not available.is_empty():
		var picked: Unit = await unit_selected_for_target
		if available.has(picked):
			chosen.append(picked)
			available.erase(picked)
			var u_ui := _get_unit_ui(picked)
			if u_ui:
				u_ui.set_target_highlight(false)

	_highlight_target_candidates(units, false)
	return chosen


func ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]:
	if cards.is_empty():
		return []
	if cards.size() <= count:
		# Nothing to choose: the game takes every matching card, so flash them
		# instead of a prompt to show the player which cards were selected.
		var auto_picked: Array[Card] = cards.duplicate()
		await flash_auto_selected_cards(auto_picked)
		return auto_picked

	show_message("Click %d card(s) in hand!" % count)
	var chosen: Array[Card] = []
	var available: Array[Card] = cards.duplicate()
	hand_bar.set_pick_candidates(available, true)

	while chosen.size() < count and not available.is_empty():
		var picked: Card = await hand_bar.card_clicked
		if not available.has(picked):
			continue
		chosen.append(picked)
		available.erase(picked)
		# Already-picked cards go dark while the remaining candidates keep glowing
		# until the last requested card has been chosen.
		hand_bar.set_pick_candidates(available, true)
		if chosen.size() < count:
			show_message("Click %d more card(s) in hand!" % (count - chosen.size()))

	hand_bar.set_pick_candidates([], false)
	return chosen


#region Helpers & Interaction Handlers

func _on_merge_requested(card_a: Card, card_b: Card) -> void:
	action_decided.emit({
		"type": "merge",
		"card_a": card_a,
		"card_b": card_b
	})


func _on_card_dropped_on_unit(card: Card, unit: Unit) -> void:
	action_decided.emit({
		"type": "play",
		"card": card,
		"target_ally": unit
	})


func _on_unit_clicked(unit: Unit) -> void:
	unit_selected_for_target.emit(unit)


# overlay A1/A2/A3 orb clicked → submit as a normal action
# This scene has no `_submit_player_action`; the existing resolution signal is
# `action_decided`, so we emit through that (same path as Convert / End Turn).
func _on_ally_ultimate_requested(ally: Unit) -> void:
	action_decided.emit({"type": "ultimate", "caster": ally})


# push current UnitUI children into the overlay rails
func _sync_overlay_units() -> void:
	var ally_uis: Array[UnitUI] = []
	for child in allies_container.get_children():
		if child is UnitUI:
			ally_uis.append(child)
	var enemy_uis: Array[UnitUI] = []
	for child in enemies_container.get_children():
		if child is UnitUI:
			enemy_uis.append(child)
	battle_overlay.rebuild_for_units(ally_uis, enemy_uis)


func _highlight_target_candidates(units: Array[Unit], active: bool) -> void:
	for u in units:
		var u_ui := _get_unit_ui(u)
		if u_ui:
			u_ui.set_target_highlight(active)


func _get_unit_ui(target_unit: Unit) -> UnitUI:
	var containers: Array[HBoxContainer] = [enemies_container, allies_container]
	for container: HBoxContainer in containers:
		for child: Node in container.get_children():
			var u_ui: UnitUI = child as UnitUI
			if u_ui and not u_ui.is_queued_for_deletion() and u_ui.unit == target_unit:
				return u_ui
	return null


func _sync_unit_row(container: HBoxContainer, units: Array[Unit], is_ally: bool) -> void:
	var total: int = units.size()

	# Reuse existing UnitUI nodes if they already match the current units
	if container.get_child_count() == total:
		var same_units: bool = true
		for idx: int in total:
			var data_idx: int = idx if is_ally else (total - 1 - idx)
			var u_ui: UnitUI = container.get_child(idx) as UnitUI
			if u_ui == null or u_ui.unit != units[data_idx]:
				same_units = false
				break
		if same_units:
			return

	for child: Node in container.get_children():
		child.queue_free()

	for idx: int in total:
		var data_idx: int = idx if is_ally else (total - 1 - idx)
		var unit: Unit = units[data_idx]
		var card_ui: UnitUI = unit_ui_scene.instantiate() as UnitUI
		container.add_child(card_ui)
		card_ui.setup(unit, icon_catalog, status_icon_catalog)
		card_ui.play_intro(idx * 0.1)
		card_ui.set_staggered(data_idx == 1)

		if is_ally:
			card_ui.card_dropped_on_unit.connect(_on_card_dropped_on_unit)
		else:
			_apply_intent_to(card_ui)
		card_ui.unit_clicked.connect(_on_unit_clicked)

#endregion
