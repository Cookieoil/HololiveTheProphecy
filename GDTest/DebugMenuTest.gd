class_name DebugMenuTest
extends GdUnitTestSuite
## Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager):
##   - the panel is view-only: it reports readouts, gates its tools while the turn
##     loop is busy and stamps the selected target onto every unit command
##   - the tools run through GameManager, so cards / resources / units change exactly
##     like they do in a real turn
##   - spawned cards are ephemeral: clearing a hand full of debug tokens never pushes
##     an oversized base card into the discard pile
##
## @author TheGreatJellyfish
## @version 11/18/2026


## Test double: the debug tools only ever log and repaint through GameUI.
class RecordingUI extends GameUI:
	var messages: Array[String] = []
	var state_shows: int = 0

	func show_message(msg: String) -> void:
		messages.append(msg)

	func show_game_state(_state: GameState) -> void:
		state_shows += 1

	func show_hand_and_resources(_state: GameState) -> void:
		pass

	func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
		pass

	func clear_unit_intent(_unit: Unit) -> void:
		pass


func _make_skill() -> SkillData:
	return SkillData.new()


func _make_ally_data(max_hp: int = 20) -> UnitData:
	var data: UnitData = UnitData.new()
	data.display_name = "Striker"
	data.max_hp = max_hp
	data.max_moxie = 20
	data.skill_1 = _make_skill()
	data.skill_2 = _make_skill()
	data.ultimate = _make_skill()
	return data


func _make_enemy_data(max_hp: int = 20) -> UnitData:
	var data: UnitData = _make_ally_data(max_hp)
	data.display_name = "Enemy"
	data.is_enemy = true
	return data


func _make_enemy(max_hp: int = 20) -> Unit:
	return Unit.new(_make_enemy_data(max_hp))


## Manager with one ally, two enemies and a recording UI: the minimum the debug
## commands touch.
func _make_manager() -> GameManager:
	var manager: GameManager = GameManager.new()
	add_child(manager)

	manager.state = GameState.new()
	var allies: Array[Unit] = [Unit.new(_make_ally_data())]
	manager.state.allies = allies
	var enemies: Array[Unit] = [_make_enemy(), _make_enemy()]
	manager.state.enemies = enemies

	var recorder: RecordingUI = RecordingUI.new()
	add_child(recorder)
	manager.ui = recorder
	return manager


## Fires one debug command exactly the way the action loop does.
func _run(manager: GameManager, command: String, args: Dictionary = {}) -> void:
	manager._handle_debug_command({"command": command, "args": args})


func _snapshot(hand: int = 3, max_hand: int = 7) -> Dictionary:
	return {
		"hand": hand,
		"max_hand": max_hand,
		"deck": 5,
		"discard": 0,
		"actions": 3,
		"merges": 2,
		"turn": 1,
		"wave": 1,
		"waves": 2,
		"dice_size": 6,
		"next_bonus": 0,
	}


func _targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	targets.append({"label": "All allies", "scope": DebugMenuPopup.Scope.ALLIES, "slot": -1})
	targets.append({"label": "All enemies", "scope": DebugMenuPopup.Scope.ENEMIES, "slot": -1})
	targets.append({"label": "Every unit", "scope": DebugMenuPopup.Scope.ALL, "slot": -1})
	targets.append({"label": "A1 Striker", "scope": DebugMenuPopup.Scope.ALLIES, "slot": 0})
	targets.append({"label": "E1 Enemy", "scope": DebugMenuPopup.Scope.ENEMIES, "slot": 0})
	return targets


## Finds the first Button with this exact label, so a test presses a real tool
## instead of reaching into private state.
func _find_button(root: Node, label: String) -> Button:
	for child: Node in root.get_children():
		var button: Button = child as Button
		if button != null and button.text == label:
			return button
		var found: Button = _find_button(child, label)
		if found != null:
			return found
	return null


## Finds the panel's tab container, so a test can tell which tab a tool lives in.
func _find_tab_container(root: Node) -> TabContainer:
	for child: Node in root.get_children():
		var tabs: TabContainer = child as TabContainer
		if tabs != null:
			return tabs
		var found: TabContainer = _find_tab_container(child)
		if found != null:
			return found
	return null


## Index of a tab by title, or -1. Tests look tabs up by name so that adding one to
## this tester panel does not break them.
func _tab_index(tabs: TabContainer, title: String) -> int:
	for index: int in range(tabs.get_tab_count()):
		if tabs.get_tab_title(index) == title:
			return index
	return -1


#region Panel (view-only) tests

func test_menu_starts_closed_and_toggles() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)

	assert_bool(popup.is_open()).is_false()
	popup.toggle_menu()
	assert_bool(popup.is_open()).is_true()
	popup.toggle_menu()
	assert_bool(popup.is_open()).is_false()


## The panel and the hover tooltip slabs are one flat surface: square on all four edges.
func test_panel_chrome_has_square_corners() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)

	var box: StyleBoxFlat = popup.get_theme_stylebox("panel") as StyleBoxFlat
	assert_bool(box != null).is_true()
	if box == null:
		return
	assert_int(box.corner_radius_top_left).is_equal(0)
	assert_int(box.corner_radius_top_right).is_equal(0)
	assert_int(box.corner_radius_bottom_left).is_equal(0)
	assert_int(box.corner_radius_bottom_right).is_equal(0)


func test_close_button_closes_the_menu_and_reports_it() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	popup.open_menu()

	var closed: Array[int] = []
	popup.menu_closed.connect(func() -> void: closed.append(1))

	var close_button: Button = _find_button(popup, "X")
	assert_object(close_button).is_not_null()
	close_button.pressed.emit()

	assert_bool(popup.is_open()).is_false()
	assert_int(closed.size()).is_equal(1)


func test_gate_locks_every_tool_and_the_close_button_stays_live() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	popup.refresh(_snapshot(), _targets())

	popup.set_gameplay_enabled(false)
	assert_str(popup._status_label.text).is_equal("locked")
	for button: Button in popup._gated_buttons:
		assert_bool(button.disabled).is_true()
	assert_bool(_find_button(popup, "X").disabled).is_false()

	popup.set_gameplay_enabled(true)
	assert_str(popup._status_label.text).is_equal("ready")
	for button: Button in popup._gated_buttons:
		assert_bool(button.disabled).is_false()


func test_refresh_flags_an_over_cap_hand() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)

	popup.refresh(_snapshot(3, 7), _targets())
	assert_bool(popup._hand_label.text.contains("OVER CAP")).is_false()

	popup.refresh(_snapshot(12, 7), _targets())
	assert_bool(popup._hand_label.text.contains("OVER CAP")).is_true()


func test_refresh_lists_targets_and_keeps_the_selection() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)

	popup.refresh(_snapshot(), _targets())
	assert_int(popup._target_selector.item_count).is_equal(5)

	popup._target_selector.select(3)
	# A refresh with the same unit list must not steal the tester's selection.
	popup.refresh(_snapshot(4, 7), _targets())
	assert_int(popup._target_selector.selected).is_equal(3)
	assert_str(popup._target_selector.get_item_text(3)).is_equal("A1 Striker")


func test_unit_tool_carries_the_selected_target() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	popup.refresh(_snapshot(), _targets())
	popup._target_selector.select(4) # E1 Enemy

	var commands: Array[String] = []
	var payloads: Array[Dictionary] = []
	popup.debug_command_requested.connect(
		func(command: String, args: Dictionary) -> void:
			commands.append(command)
			payloads.append(args)
	)

	var kill_button: Button = _find_button(popup, "Kill")
	assert_object(kill_button).is_not_null()
	kill_button.pressed.emit()

	assert_int(commands.size()).is_equal(1)
	assert_str(commands[0]).is_equal(DebugMenuPopup.CMD_KILL)
	var payload: Dictionary = payloads[0]
	assert_int(payload.get("scope", -1)).is_equal(DebugMenuPopup.Scope.ENEMIES)
	assert_int(payload.get("slot", -1)).is_equal(0)


func test_unit_tool_without_a_target_does_nothing() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	var no_targets: Array[Dictionary] = []
	popup.refresh(_snapshot(), no_targets)

	var emitted: Array[int] = []
	popup.debug_command_requested.connect(
		func(_command: String, _args: Dictionary) -> void: emitted.append(1)
	)

	_find_button(popup, "Kill").pressed.emit()
	assert_int(emitted.size()).is_equal(0)


## The result cutscene is otherwise only reachable by actually winning or losing,
## so the panel offers a preview tool for each outcome.
func test_result_preview_tools_emit_their_commands() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	popup.refresh(_snapshot(), _targets())

	var commands: Array[String] = []
	popup.debug_command_requested.connect(
		func(command: String, _args: Dictionary) -> void: commands.append(command)
	)

	var victory_button: Button = _find_button(popup, "Preview victory")
	var defeat_button: Button = _find_button(popup, "Preview defeat")
	assert_object(victory_button).is_not_null()
	assert_object(defeat_button).is_not_null()
	victory_button.pressed.emit()
	defeat_button.pressed.emit()

	assert_int(commands.size()).is_equal(2)
	assert_str(commands[0]).is_equal(DebugMenuPopup.CMD_SHOW_VICTORY)
	assert_str(commands[1]).is_equal(DebugMenuPopup.CMD_SHOW_DEFEAT)


## The result previews have their own Screen tab, so they are not buried under the
## unit tools.
func test_result_previews_live_in_their_own_tab() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	popup.refresh(_snapshot(), _targets())

	var tabs: TabContainer = _find_tab_container(popup)
	assert_object(tabs).is_not_null()
	if tabs == null:
		return
	# Found by name on purpose: the palette is a tester tool and its tab list is
	# expected to grow, which an index-and-count assertion would fight.
	var screen_index: int = _tab_index(tabs, "Screen")
	assert_int(screen_index).is_greater_equal(0)
	if screen_index < 0:
		return

	var screen_page: Node = tabs.get_child(screen_index)
	assert_object(_find_button(screen_page, "Preview victory")).is_not_null()
	assert_object(_find_button(screen_page, "Preview defeat")).is_not_null()
	# And they are gone from the Units tab they used to share.
	var units_index: int = _tab_index(tabs, "Units")
	assert_int(units_index).is_greater_equal(0)
	if units_index >= 0:
		assert_object(_find_button(tabs.get_child(units_index), "Preview victory")).is_null()
#endregion


#region Header drag (the panel can be moved out of the way)

## Sends the press/release the GUI would deliver to the header.
func _press_header(popup: DebugMenuPopup, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	popup._on_header_gui_input(event)


## Sends one motion step over the header.
func _drag_header(popup: DebugMenuPopup, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	popup._on_header_gui_input(event)


func test_dragging_the_header_moves_the_panel() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	var start_left: float = popup.offset_left
	var start_top: float = popup.offset_top

	# Motion without a press is not a drag.
	_drag_header(popup, Vector2(40.0, -30.0))
	assert_float(popup.offset_left).is_equal(start_left)

	_press_header(popup, true)
	_drag_header(popup, Vector2(40.0, -30.0))
	assert_float(popup.offset_left).is_equal(start_left + 40.0)
	assert_float(popup.offset_top).is_equal(start_top - 30.0)

	# Releasing ends the drag.
	_press_header(popup, false)
	_drag_header(popup, Vector2(40.0, -30.0))
	assert_float(popup.offset_left).is_equal(start_left + 40.0)

	# Moving the panel must never resize it.
	assert_float(popup.offset_right - popup.offset_left).is_equal(DebugMenuPopup.PANEL_WIDTH)
	assert_float(popup.offset_bottom - popup.offset_top).is_equal(DebugMenuPopup.PANEL_HEIGHT)


func test_header_drag_ignores_other_mouse_buttons() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	var start_left: float = popup.offset_left

	_press_header(popup, true, MOUSE_BUTTON_RIGHT)
	_drag_header(popup, Vector2(50.0, 0.0))

	assert_float(popup.offset_left).is_equal(start_left)


func test_header_is_a_wired_drag_handle() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)

	assert_int(popup._header.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(popup._header.gui_input.is_connected(popup._on_header_gui_input)).is_true()
	# The menu background must swallow clicks instead of leaking them to the cards.
	assert_int(popup.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_dragging_cannot_push_the_panel_off_screen() -> void:
	var popup: DebugMenuPopup = DebugMenuPopup.new()
	add_child(popup)
	var viewport_size: Vector2 = popup.get_viewport_rect().size
	assert_bool(viewport_size.y >= DebugMenuPopup.PANEL_HEIGHT).is_true()

	_press_header(popup, true)

	# Far up-left: the panel stops at the viewport's top/left edges.
	_drag_header(popup, Vector2(-10000.0, -10000.0))
	assert_float(popup.offset_left).is_equal(0.0)
	assert_bool(popup.global_position.x >= 0.0).is_true()
	assert_bool(popup.global_position.y >= 0.0).is_true()

	# Far down-right: it stops with its own bottom-right corner on the edge.
	_drag_header(popup, Vector2(10000.0, 10000.0))
	assert_float(popup.offset_bottom).is_equal(0.0)
	assert_bool(popup.global_position.x + popup.size.x <= viewport_size.x).is_true()
	assert_bool(popup.global_position.y + popup.size.y <= viewport_size.y).is_true()

	_press_header(popup, false)
#endregion


#region Card tools (overflow, merge tiers, hand operations)

func test_spawning_ignores_the_hand_cap() -> void:
	var manager: GameManager = _make_manager()
	manager.state.max_hand_size = 7

	_run(manager, "spawn_random", {"count": 10})
	assert_int(manager.state.hand.size()).is_equal(10)

	_run(manager, "spawn_random", {"count": 5})
	assert_int(manager.state.hand.size()).is_equal(15)


func test_custom_spawn_builds_each_merge_tier() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "spawn_custom", {"value": 6, "tier": 0})
	_run(manager, "spawn_custom", {"value": 6, "tier": 1})
	_run(manager, "spawn_custom", {"value": 20, "tier": 2})

	assert_int(manager.state.hand.size()).is_equal(3)
	var base: Card = manager.state.hand[0]
	var merged: Card = manager.state.hand[1]
	var double_merged: Card = manager.state.hand[2]

	assert_bool(base.is_merged).is_false()
	assert_bool(base.is_double_merged).is_false()
	assert_bool(merged.is_merged).is_true()
	assert_bool(merged.is_double_merged).is_false()
	assert_bool(double_merged.is_double_merged).is_true()
	assert_int(double_merged.get_effective_value()).is_equal(20)


func test_spawned_merged_card_evaporates_instead_of_poisoning_the_deck() -> void:
	var manager: GameManager = _make_manager()
	_run(manager, "spawn_custom", {"value": 20, "tier": 2})

	_run(manager, "clear_hand")

	assert_int(manager.state.hand.size()).is_equal(0)
	# A 20 DMV token must not decompose into a permanent 20-value base card.
	assert_int(manager.state.discard.size()).is_equal(0)


func test_clearing_the_hand_still_discards_real_deck_cards() -> void:
	var manager: GameManager = _make_manager()
	var hand: Array[Card] = [Card.new(2), Card.new(3)]
	manager.state.hand = hand

	_run(manager, "clear_hand")

	assert_int(manager.state.hand.size()).is_equal(0)
	assert_int(manager.state.discard.size()).is_equal(2)


func test_discard_random_removes_exactly_one_card() -> void:
	var manager: GameManager = _make_manager()
	var hand: Array[Card] = [Card.new(2), Card.new(3), Card.new(5)]
	manager.state.hand = hand

	_run(manager, "discard_random")

	assert_int(manager.state.hand.size()).is_equal(2)
	assert_int(manager.state.discard.size()).is_equal(1)


func test_draw_tools_pull_from_the_deck() -> void:
	var manager: GameManager = _make_manager()
	manager.state.max_hand_size = 7
	var deck: Array[Card] = [Card.new(2), Card.new(3)]
	manager.state.deck = deck

	_run(manager, "draw", {"count": 1})
	assert_int(manager.state.hand.size()).is_equal(1)
	assert_int(manager.state.deck.size()).is_equal(1)

	_run(manager, "draw_to_max")
	assert_int(manager.state.hand.size()).is_equal(2)
	assert_int(manager.state.deck.size()).is_equal(0)


func test_buff_hand_raises_every_card_and_announces_it() -> void:
	var manager: GameManager = _make_manager()
	var hand: Array[Card] = [Card.new(3), Card.new(4)]
	manager.state.hand = hand

	var announced: Array[int] = []
	var handler := func(_card: Card, _old_value: int, new_value: int) -> void:
		announced.append(new_value)
	EventBus.card_value_changed.connect(handler)

	_run(manager, "buff_hand", {"amount": 2})

	EventBus.card_value_changed.disconnect(handler)
	assert_int(manager.state.hand[0].get_effective_value()).is_equal(5)
	assert_int(manager.state.hand[1].get_effective_value()).is_equal(6)
	assert_int(announced.size()).is_equal(2)


func test_hand_tools_on_an_empty_hand_do_not_crash() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "buff_hand", {"amount": 2})
	_run(manager, "discard_random")
	_run(manager, "clear_hand")
	_run(manager, "draw")

	assert_int(manager.state.hand.size()).is_equal(0)
#endregion


#region Resource tools

func test_resource_tools_top_up_actions_and_merges() -> void:
	var manager: GameManager = _make_manager()
	manager.state.actions_left = 0
	manager.state.merges_left = 0

	_run(manager, "grant_actions", {"amount": 5})
	_run(manager, "grant_merges", {"amount": 99})

	assert_int(manager.state.actions_left).is_equal(5)
	assert_int(manager.state.merges_left).is_equal(99)


func test_hand_cap_stepper_clamps_at_both_ends() -> void:
	var manager: GameManager = _make_manager()

	manager.state.max_hand_size = 1
	_run(manager, "step_max_hand", {"delta": -5})
	assert_int(manager.state.max_hand_size).is_equal(1)

	manager.state.max_hand_size = DebugCommandRunner.HAND_CAP_LIMIT - 1
	_run(manager, "step_max_hand", {"delta": 5})
	assert_int(manager.state.max_hand_size).is_equal(DebugCommandRunner.HAND_CAP_LIMIT)


func test_next_skill_bonus_accumulates() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "grant_next_bonus", {"amount": 5})
	_run(manager, "grant_next_bonus", {"amount": 5})

	assert_int(manager.state.next_skill_bonus).is_equal(10)
#endregion


#region Unit tools

func test_fill_moxie_makes_the_ultimate_castable() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = manager.state.allies[0]
	ally.ult_used_this_turn = true

	_run(manager, "fill_moxie", {"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0})

	assert_int(ally.moxie).is_equal(ally.max_moxie)
	assert_bool(ally.can_cast_ultimate).is_true()


func test_zero_moxie_clears_the_gauge_and_the_used_lock() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = manager.state.allies[0]
	ally.gain_moxie(10)

	_run(manager, "drain_moxie", {"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0})

	assert_int(ally.moxie).is_equal(0)
	assert_bool(ally.ult_used_this_turn).is_false()


func test_damage_tools_absorb_through_shield_then_hp() -> void:
	var manager: GameManager = _make_manager()
	var enemy: Unit = manager.state.enemies[0]
	enemy.gain_shield(4)

	_run(manager, "damage", {
		"scope": DebugCommandRunner.SCOPE_ENEMIES, "slot": 0, "amount": 6,
	})

	assert_int(enemy.shield).is_equal(0)
	assert_int(enemy.current_hp).is_equal(enemy.max_hp - 2)


func test_true_damage_bypasses_the_shield() -> void:
	var manager: GameManager = _make_manager()
	var enemy: Unit = manager.state.enemies[0]
	enemy.gain_shield(4)

	_run(manager, "true_damage", {
		"scope": DebugCommandRunner.SCOPE_ENEMIES, "slot": 0, "amount": 6,
	})

	assert_int(enemy.shield).is_equal(4)
	assert_int(enemy.current_hp).is_equal(enemy.max_hp - 6)


func test_heal_full_restores_the_target_only() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = manager.state.allies[0]
	var enemy: Unit = manager.state.enemies[0]
	ally.current_hp = 5
	enemy.current_hp = 5

	_run(manager, "heal_full", {"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0})

	assert_int(ally.current_hp).is_equal(ally.max_hp)
	assert_int(enemy.current_hp).is_equal(5)


func test_shield_tools_add_and_clear() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = manager.state.allies[0]

	_run(manager, "add_shield", {
		"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0, "amount": 10,
	})
	assert_int(ally.shield).is_equal(10)

	_run(manager, "clear_shield", {"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0})
	assert_int(ally.shield).is_equal(0)


func test_kill_defeats_only_the_targeted_slot() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "kill", {"scope": DebugCommandRunner.SCOPE_ENEMIES, "slot": 1})

	assert_bool(manager.state.enemies[1].is_dead).is_true()
	assert_bool(manager.state.enemies[0].is_dead).is_false()
	assert_bool(manager.state.allies[0].is_dead).is_false()


func test_scope_all_hits_both_rows() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "damage", {"scope": DebugCommandRunner.SCOPE_ALL, "slot": -1, "amount": 5})

	assert_int(manager.state.allies[0].current_hp).is_equal(15)
	assert_int(manager.state.enemies[0].current_hp).is_equal(15)
	assert_int(manager.state.enemies[1].current_hp).is_equal(15)


func test_untargeted_command_never_touches_the_enemy_row() -> void:
	var manager: GameManager = _make_manager()

	# A payload with no scope must fall back to the ally row, never the whole board.
	_run(manager, "kill")

	assert_bool(manager.state.allies[0].is_dead).is_true()
	assert_bool(manager.state.all_enemies_dead()).is_false()


func test_status_tools_apply_and_clear() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = manager.state.allies[0]

	_run(manager, "apply_status", {
		"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0,
		"status_id": "regeneration", "amount": 2,
	})
	assert_int(ally.get_status_count("regeneration")).is_equal(2)

	_run(manager, "clear_statuses", {"scope": DebugCommandRunner.SCOPE_ALLIES, "slot": 0})
	assert_bool(ally.has_status("regeneration")).is_false()
#endregion


#region Wave tools

func test_clear_wave_defeats_every_living_enemy() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "clear_wave")

	assert_bool(manager.state.all_enemies_dead()).is_true()
	assert_bool(manager.state.all_allies_dead()).is_false()


func test_respawn_wave_rebuilds_the_enemy_row() -> void:
	var manager: GameManager = _make_manager()
	var wave: Array[UnitData] = [_make_enemy_data()]
	var waves: Array = [wave]
	manager.state.wave_definitions = waves
	manager.state.current_wave = 0
	manager.state.enemies.clear()

	_run(manager, "respawn_wave")

	assert_int(manager.state.enemies.size()).is_equal(1)
	assert_int(manager.state.current_wave).is_equal(0)
	assert_int(manager.current_intents.size()).is_equal(1)


func test_reroll_intents_skips_defeated_enemies() -> void:
	var manager: GameManager = _make_manager()
	manager.state.enemies[0].current_hp = 0

	_run(manager, "reroll_intents")

	assert_int(manager.current_intents.size()).is_equal(1)


func test_dice_step_rerolls_with_the_new_dice() -> void:
	var manager: GameManager = _make_manager()
	_run(manager, "reroll_intents")
	var dice_size: int = manager.state.get_dice_size(manager.state.turn_number)

	_run(manager, "step_dice", {"delta": 1})

	assert_int(manager.state.dice_size_modifier).is_equal(1)
	assert_int(manager.state.get_dice_size(manager.state.turn_number)).is_equal(dice_size + 1)
	assert_int(manager.current_intents.size()).is_equal(2)
	for intent: EnemyIntent in manager.current_intents:
		assert_bool(intent.raw_dice_value >= 1).is_true()
		assert_bool(intent.raw_dice_value <= dice_size + 1).is_true()


func test_unknown_command_is_ignored() -> void:
	var manager: GameManager = _make_manager()

	_run(manager, "not_a_real_tool", {"count": 5})

	assert_int(manager.state.hand.size()).is_equal(0)
	assert_bool(manager.state.all_allies_dead()).is_false()
#endregion


#region Build-type gate

## The engine is in charge by default: the suite must never leave a forced answer
## behind for another test file to inherit.
func before_test() -> void:
	GameManager.debug_build_override = GameManager.DEBUG_BUILD_ENGINE


func after_test() -> void:
	GameManager.debug_build_override = GameManager.DEBUG_BUILD_ENGINE


## The headless run uses the editor binary, so the tools stay available here. If this
## ever fails, the rest of the suite is running against a release binary.
func test_a_debug_build_keeps_the_tools_available() -> void:
	assert_bool(GameManager.debug_tools_enabled()).is_true()


## A release export must never mount the overlay, even though the shipped scene file
## still carries `debug_menu_enabled = true`.
func test_a_release_build_never_mounts_the_overlay() -> void:
	GameManager.debug_build_override = GameManager.DEBUG_BUILD_FORCED_OFF

	var packed: PackedScene = load("res://Scenes/BattleScene/BattleScene.tscn") as PackedScene
	var scene: BattleScene = packed.instantiate() as BattleScene
	add_child(scene)
	auto_free(scene)

	assert_object(scene.debug_menu).is_null()
	assert_bool(scene.debug_layer.visible).is_false()
	# The toggle and F1 share the same gate, so neither can bring the panel back.
	scene._on_debug_button_pressed()
	assert_object(scene.debug_menu).is_null()


## And a debug action that somehow reaches the turn loop is refused there too: the
## manager is the authority, not the UI.
func test_a_release_build_refuses_a_debug_command() -> void:
	GameManager.debug_build_override = GameManager.DEBUG_BUILD_FORCED_OFF
	var manager: GameManager = _make_manager()
	var enemy: Unit = manager.state.enemies[0]

	_run(manager, "kill", {"scope": DebugCommandRunner.SCOPE_ENEMIES, "slot": 0})

	assert_bool(enemy.is_dead).is_false()
	assert_int(enemy.current_hp).is_equal(enemy.max_hp)
#endregion


#region Scene wiring

## The battle scene is the only place the toggle button, the hotkey and the panel
## meet, so this loads the real scene and checks they are actually connected.
func test_battle_scene_mounts_and_toggles_the_debug_menu() -> void:
	var packed: PackedScene = load("res://Scenes/BattleScene/BattleScene.tscn") as PackedScene
	assert_object(packed).is_not_null()

	var scene: BattleScene = packed.instantiate() as BattleScene
	add_child(scene)
	auto_free(scene)

	# _setup_debug_menu() runs before the first await in _ready(), so the panel and
	# its label are already wired by the time add_child() returns.
	assert_object(scene.debug_menu).is_not_null()
	assert_bool(scene.debug_menu.is_open()).is_false()
	assert_str(scene.debug_button.text).is_equal("Debug ▴")

	# The toggle is a small button: it must stay inside the hand bar's left gutter
	# instead of stretching under the cards row (the panel keeps its own width).
	var hand_margin: MarginContainer = scene.hand_bar.get_node("MarginContainer") as MarginContainer
	assert_object(hand_margin).is_not_null()
	var gutter: float = float(hand_margin.get_theme_constant("margin_left"))
	assert_bool(scene.debug_button.size.x > 0.0).is_true()
	assert_bool(scene.debug_button.size.x <= gutter).is_true()

	scene._on_debug_button_pressed()
	assert_bool(scene.debug_menu.is_open()).is_true()
	assert_str(scene.debug_button.text).is_equal("Debug ▾")

	# Closing from inside the panel must put the toggle's label back.
	scene.debug_menu.close_menu()
	assert_str(scene.debug_button.text).is_equal("Debug ▴")


func test_battle_scene_locks_the_tools_until_the_player_turn_starts() -> void:
	var packed: PackedScene = load("res://Scenes/BattleScene/BattleScene.tscn") as PackedScene
	var scene: BattleScene = packed.instantiate() as BattleScene
	add_child(scene)
	auto_free(scene)

	# The animation half of the turn: the loop is not sitting on the action queue,
	# so a tool press must be dropped instead of landing on the next turn.
	scene._awaiting_player_action = false
	var emitted: Array[int] = []
	scene.action_decided.connect(func(_action: Dictionary) -> void: emitted.append(1))
	scene._on_debug_command_requested(DebugMenuPopup.CMD_CLEAR_HAND, {})

	assert_int(emitted.size()).is_equal(0)
	assert_bool(scene.game_manager.state.hand.is_empty()).is_false()


## _ready() runs the loop up to its first player action, so a tool press goes
## straight onto the queue and the turn loop applies it for real.
func test_battle_scene_applies_a_tool_through_the_turn_loop() -> void:
	var packed: PackedScene = load("res://Scenes/BattleScene/BattleScene.tscn") as PackedScene
	var scene: BattleScene = packed.instantiate() as BattleScene
	add_child(scene)
	auto_free(scene)

	assert_bool(scene._awaiting_player_action).is_true()
	assert_str(scene.debug_menu._status_label.text).is_equal("ready")
	var cap: int = scene.game_manager.state.max_hand_size
	assert_int(scene.game_manager.state.hand.size()).is_equal(cap)

	# Spawning past the cap, then clearing: the 5 debug tokens evaporate, so only
	# the real deck cards reach the discard pile.
	scene._on_debug_command_requested(DebugMenuPopup.CMD_SPAWN_RANDOM, {"count": 5})
	assert_int(scene.game_manager.state.hand.size()).is_equal(cap + 5)

	scene._on_debug_command_requested(DebugMenuPopup.CMD_CLEAR_HAND, {})
	assert_bool(scene.game_manager.state.hand.is_empty()).is_true()
	assert_int(scene.game_manager.state.discard.size()).is_equal(cap)
#endregion


