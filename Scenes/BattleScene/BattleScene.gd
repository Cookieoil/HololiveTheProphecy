# BattleScene.gd
class_name BattleScene
extends GameUI

@export var icon_catalog: CardIconCatalog
@export var status_icon_catalog: StatusIconCatalog
@export var tooltip_icon_catalog: TooltipIconCatalog
@export var unit_ui_scene: PackedScene = preload("res://Scenes/BattleUnit/UnitUI.tscn")
@export var turn_dice_progression: Array[int] = []
## Tester tools (the Debug button + F1). Turn off for a build that must not show them.
## A release export hides them regardless of this flag — see `_debug_tools_allowed`.
@export var debug_menu_enabled: bool = true
## Emblems for the end-of-battle cutscene. Placeholder art until the hand-drawn
## icons land; the overlay shows them framed above the VICTORY / DEFEAT banner.
@export var victory_icon: Texture2D = preload("res://Scenes/BattleScene/Assets/icon2.png")
@export var defeat_icon: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")
## Pins the run seed for replay tooling: the dealt hand, the rolls and the enemy
## intents become identical on every machine. 0 keeps the normal random seed.
@export var fixed_seed_override: int = 0
## Points the telemetry disclosure at a throwaway file instead of the player's real
## `user://` answer. Set by the UI snapshot runner so a capture never overwrites the
## developer's stored consent. Empty keeps the normal path.
@export var consent_path_override: String = ""

@onready var hand_bar: HandBar = $HUD/HandBar
@onready var allies_container: HBoxContainer = $EntityOverlay/AlliesRow
@onready var enemies_container: HBoxContainer = $EntityOverlay/EnemiesRow

@onready var battle_overlay: BattleOverlayController = $BattleOverlay

@onready var wave_value_label: Label = $HUD/TopBar/Margin/HBox/LeftGroup/WaveStat/Value
@onready var dice_value_label: Label = $HUD/TopBar/Margin/HBox/LeftGroup/DiceStat/Value
@onready var actions_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/ActionsStat/Value
@onready var merges_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/MergesStat/Value
@onready var deck_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/DeckStat/Value
@onready var discard_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/DiscardStat/Value
@onready var convert_button: Button = $HUD/TopBar/Margin/HBox/RightGroup/ConvertButton
@onready var end_turn_button: Button = $HUD/TopBar/Margin/HBox/RightGroup/EndTurnButton
@onready var log_label: Label = $HUD/MessageLog

@onready var debug_layer: CanvasLayer = $DebugLayer
@onready var debug_button: Button = $DebugLayer/DebugButton

var game_manager: GameManager
## Tester overlay, built in code and mounted on `debug_layer`.
var debug_menu: DebugMenuPopup
## End-of-battle cutscene, built in code and mounted on its own top layer.
var result_overlay: BattleResultOverlay
var result_layer: CanvasLayer
## Copies the rendered battle into the back buffer, so the cutscene's backdrop
## shader can grade what is behind it (a CanvasItem screen texture needs a
## BackBufferCopy drawn in front of the reader).
var result_back_buffer: BackBufferCopy
## First-launch telemetry disclosure, built in code and mounted on its own top
## layer so it owns the screen until the player answers.
var consent_popup: TelemetryConsentPopup
var consent_layer: CanvasLayer
## Background uploader for the telemetry outbox (Stage 2). Does nothing until
## `telemetry/endpoint` is configured in project settings.
var telemetry_uploader: TelemetryUploader
## True only while GameManager awaits a player action: the one window in which a
## debug tool may be applied, because the turn loop is sitting on the action queue.
var _awaiting_player_action: bool = false
var _intent_cache: Dictionary[Unit, Dictionary] = {}

signal action_decided(action_dict: Dictionary)
signal unit_selected_for_target(unit: Unit)

## seconds between each enemy's intent appearing
const INTENT_STAGGER: float = 0.08
## The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering
## brightens their icon a little instead, the same cue the ultimate orbs give their
## portrait. Above 1.0 the icon lights up; white is the resting state.
const ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)

func _ready() -> void:
	if status_icon_catalog == null:
		status_icon_catalog = StatusIconCatalog.new()
	if tooltip_icon_catalog == null:
		tooltip_icon_catalog = TooltipIconCatalog.new()

	end_turn_button.pressed.connect(func() -> void: action_decided.emit({"type": "end_turn"}))
	convert_button.pressed.connect(func() -> void: action_decided.emit({"type": "convert"}))
	_setup_icon_button_hover(convert_button)
	_setup_icon_button_hover(end_turn_button)
	hand_bar.merge_requested.connect(_on_merge_requested)
	_setup_debug_menu()
	_setup_result_overlay()
	_setup_consent_gate()
	_setup_telemetry_uploader()

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
	# Replay tooling can pin the deal and the rolls; 0 keeps the random seed.
	if fixed_seed_override != 0:
		config["seed"] = fixed_seed_override

	# Ask for telemetry consent before the run starts, so a first-session "Agree"
	# captures turn 1 and a "Decline" never buffers a single decision.
	await _run_consent_gate()
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

## End of battle: the turn loop is parked, so every player control is locked and
## the Victory / Defeat cutscene takes over the screen. Awaited by GameManager, so
## the loop only finishes once the banner has settled in.
func show_battle_result(victory: bool) -> void:
	end_turn_button.disabled = true
	convert_button.disabled = true
	battle_overlay.set_player_turn_interactive(false)
	if debug_menu != null and debug_menu.is_open():
		debug_menu.close_menu()
		_sync_debug_toggle()
	if result_overlay == null:
		return
	# Clear the stage first: the Moxie rails are combat chrome, so they step off
	# before the cutscene takes the screen.
	await battle_overlay.retreat_for_result()
	await result_overlay.play_cutscene(victory)

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
	_refresh_debug_menu(state)


func show_hand_and_resources(state: GameState) -> void:
	_update_top_bar(state)
	hand_bar.game_state = state
	hand_bar.set_hand(state.hand)
	_refresh_debug_menu(state)


func _update_top_bar(state: GameState) -> void:
	if state == null:
		return
	var wave_num: int = state.current_wave + 1

	wave_value_label.text = str(wave_num)
	dice_value_label.text = str(state.get_dice_size(state.turn_number))
	actions_value_label.text = str(state.actions_left)
	merges_value_label.text = str(state.merges_left)
	deck_value_label.text = str(state.deck.size())
	discard_value_label.text = str(state.discard.size())


## The top-bar action buttons are flat icons, so they light up while the pointer is over
## them instead of drawing a hover chrome - the cue that they are clickable.
func _setup_icon_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: button.self_modulate = ICON_BUTTON_HOVER_TINT)
	button.mouse_exited.connect(func() -> void: button.self_modulate = Color.WHITE)


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
func get_player_action(state: GameState) -> Dictionary:
	end_turn_button.disabled = false
	convert_button.disabled = false

	# enable A1/A2/A3 orbs while awaiting player input
	battle_overlay.set_player_turn_interactive(true)
	# Debug tools unlock here and nowhere else: this is the one moment the turn
	# loop is parked on the action queue and can accept another action.
	_awaiting_player_action = true
	_set_debug_interactive(true)
	_refresh_debug_menu(state)

	var action: Dictionary = await action_decided

	_awaiting_player_action = false
	_set_debug_interactive(false)
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


#region Debug Menu
## Tester overlay (Debug button + F1). Everything it asks for is routed through the
## normal action queue, so a debug tool is handled by exactly the same turn-loop code
## as a real action and can never desynchronise the wave machine, the enemy intents
## or the HUD.
##
## The overlay only ever exists in a debug build: `_debug_tools_allowed()` combines the
## inspector toggle with the build type, so a release export cannot mount the panel or
## emit a "debug" action even if `debug_menu_enabled` was left on.
func _debug_tools_allowed() -> bool:
	return debug_menu_enabled and GameManager.debug_tools_enabled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _debug_tools_allowed():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F1:
		return
	get_viewport().set_input_as_handled()
	_on_debug_button_pressed()


## Builds the tester overlay. The panel is created in code, so the battle scene has
## no extra nodes to keep in sync and the .tscn only carries the toggle button.
func _setup_debug_menu() -> void:
	if not _debug_tools_allowed():
		debug_layer.visible = false
		return

	debug_menu = DebugMenuPopup.new()
	debug_menu.debug_command_requested.connect(_on_debug_command_requested)
	debug_menu.menu_closed.connect(_sync_debug_toggle)
	debug_layer.add_child(debug_menu)

	debug_button.pressed.connect(_on_debug_button_pressed)
	_sync_debug_toggle()


func _on_debug_button_pressed() -> void:
	if debug_menu == null:
		return
	debug_menu.toggle_menu()
	_sync_debug_toggle()
	_refresh_debug_menu()


## The panel can close itself, so the toggle's arrow always matches its state.
func _sync_debug_toggle() -> void:
	if debug_menu == null or debug_button == null:
		return
	debug_button.text = "Debug ▾" if debug_menu.is_open() else "Debug ▴"


func _set_debug_interactive(interactive: bool) -> void:
	if debug_menu != null:
		debug_menu.set_gameplay_enabled(interactive)


## A tool was pressed. It goes onto the action queue as a normal "debug" action,
## which the turn loop then validates and applies (see GameManager).
func _on_debug_command_requested(command: String, args: Dictionary) -> void:
	if debug_menu == null or not _debug_tools_allowed() or not _awaiting_player_action:
		return
	action_decided.emit({"type": "debug", "command": command, "args": args})


func _refresh_debug_menu(state: GameState = null) -> void:
	if debug_menu == null:
		return
	var live_state: GameState = state if state != null else _debug_state()
	if live_state == null:
		return
	debug_menu.refresh(_debug_snapshot(live_state), _build_debug_targets(live_state))


func _debug_state() -> GameState:
	if game_manager == null or not is_instance_valid(game_manager):
		return null
	return game_manager.state


## Read-only numbers for the panel, built here so the panel needs no game access.
func _debug_snapshot(state: GameState) -> Dictionary:
	return {
		"hand": state.hand.size(),
		"max_hand": state.max_hand_size,
		"deck": state.deck.size(),
		"discard": state.discard.size(),
		"actions": state.actions_left,
		"merges": state.merges_left,
		"turn": state.turn_number + 1,
		"wave": state.current_wave + 1,
		"waves": state.wave_definitions.size(),
		"dice_size": state.get_dice_size(state.turn_number),
		"next_bonus": state.next_skill_bonus,
	}


## Target list for the Units tab: both rows plus every individual slot. The payload
## is scope + slot, so the panel never holds a Unit reference that a wave respawn
## could leave stale.
func _build_debug_targets(state: GameState) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	targets.append({"label": "All allies", "scope": DebugMenuPopup.Scope.ALLIES, "slot": -1})
	targets.append({"label": "All enemies", "scope": DebugMenuPopup.Scope.ENEMIES, "slot": -1})
	targets.append({"label": "Every unit", "scope": DebugMenuPopup.Scope.ALL, "slot": -1})
	for i: int in state.allies.size():
		targets.append(_debug_target_entry("A%d" % (i + 1), state.allies[i], i, true))
	for i: int in state.enemies.size():
		targets.append(_debug_target_entry("E%d" % (i + 1), state.enemies[i], i, false))
	return targets
#endregion


#region Battle Result
## Builds the end-of-battle cutscene in code and mounts it on its own CanvasLayer.
## Layer 30 sits above the HUD (2), the Moxie rails (3), the tooltip layer (10) and
## the debug palette (20), so the result banner owns the screen and no leftover
## glow or tooltip can draw over it. Built in code for the same reason as the
## debug menu: the .tscn carries no extra nodes to keep in sync.
func _setup_result_overlay() -> void:
	result_layer = CanvasLayer.new()
	result_layer.name = "ResultLayer"
	result_layer.layer = 30
	add_child(result_layer)

	result_back_buffer = BackBufferCopy.new()
	result_back_buffer.name = "ResultBackBuffer"
	result_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	result_layer.add_child(result_back_buffer)

	result_overlay = BattleResultOverlay.new()
	result_overlay.victory_icon = victory_icon
	result_overlay.defeat_icon = defeat_icon
	result_overlay.restart_requested.connect(_on_restart_requested)
	result_layer.add_child(result_overlay)


## "Play Again": restart from a clean scene. Reloading rebuilds GameManager,
## GameState and the whole board, so nothing from the finished battle (Moxie,
## intents, hand, shields) can leak into the new run.
func _on_restart_requested() -> void:
	_awaiting_player_action = false
	get_tree().reload_current_scene()
#endregion


func _debug_target_entry(code: String, unit: Unit, slot: int, is_ally: bool) -> Dictionary:
	return {
		"label": "%s %s%s" % [code, unit.data.display_name, " (dead)" if unit.is_dead else ""],
		"scope": DebugMenuPopup.Scope.ALLIES if is_ally else DebugMenuPopup.Scope.ENEMIES,
		"slot": slot,
	}
#endregion


#region Telemetry Consent
## Builds the disclosure in code and mounts it on its own top layer (35), above
## the HUD, the tooltip layer and the debug palette, so nothing can draw over it.
func _setup_consent_gate() -> void:
	consent_layer = CanvasLayer.new()
	consent_layer.name = "ConsentLayer"
	consent_layer.layer = 35
	add_child(consent_layer)

	consent_popup = TelemetryConsentPopup.new()
	consent_popup.name = "ConsentPopup"
	# Snapshot runs redirect this to a throwaway file, so a capture never writes
	# over the developer's real user:// answer.
	if not consent_path_override.is_empty():
		consent_popup.consent = TelemetryConsent.load_from(consent_path_override)
	consent_layer.add_child(consent_popup)


## Shows the disclosure only when it still has to be answered and the run is not
## headless (so automated gates never block on a modal). Callers `await` this to
## hold the battle until the player decides.
func _run_consent_gate() -> void:
	if not _should_prompt_consent():
		telemetry_uploader.drain()
		return
	consent_popup.open()
	var agreed: bool = await consent_popup.decided
	# Only after an explicit "Agree" may the outbox be drained.
	if agreed:
		telemetry_uploader.drain()


## Builds the background outbox uploader. It is inert (no request at all) until a
## `telemetry/endpoint` is set, so a local-only build never talks to a network.
func _setup_telemetry_uploader() -> void:
	telemetry_uploader = TelemetryUploader.new()
	telemetry_uploader.name = "TelemetryUploader"
	add_child(telemetry_uploader)
	# A finished battle is the natural moment to push the outbox: the run file has
	# just been sealed and promoted, and the player is looking at the result screen.
	EventBus.game_over.connect(_on_game_over_drain)


## Drains the outbox as soon as a battle ends. `game_over` fires after
## `TelemetryManager.end_run`, so the finished run is already sealed by now.
func _on_game_over_drain(_victory: bool) -> void:
	if telemetry_uploader != null:
		telemetry_uploader.drain()


## The disclosure is shown once per *launch*, not once ever, so a returning player
## still sees what they are allowing and can change their mind. A scene reload -
## "Play Again" - belongs to the same launch and is skipped by the popup's own
## launch flag. Headless runs never block on a modal.
func _should_prompt_consent() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if consent_popup == null:
		return false
	return TelemetryConsentPopup.should_prompt_this_launch()
#endregion
