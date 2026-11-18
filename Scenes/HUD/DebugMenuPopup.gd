# res://Scenes/HUD/DebugMenuPopup.gd
class_name DebugMenuPopup
extends PanelContainer
## Tester-only tool palette for the battle scene.
##
## Every button here is a *request*: it emits `debug_command_requested` upward and
## the turn loop performs the mutation, then pushes a read-only snapshot back down
## through `refresh()`. Nothing in this file touches GameState, Unit or HandBar, so
## a debug tool can never desynchronise the turn loop or the enemy intents.
##
## The whole layout is built in code (like SkillTooltipPopup) so no .tscn has to be
## hand-edited for a panel only testers use.
##
## @author TheGreatJellyfish
## @version 11/18/2026

#region Signals
## A tester pressed a tool. `command` is one of the CMD_* ids below and `args` is
## that tool's payload, documented next to its CMD_* constant.
signal debug_command_requested(command: String, args: Dictionary)
## The panel closed itself (its own close button), so the owner can re-label the
## button that toggles it.
signal menu_closed()
#endregion

#region Enums
## Which row a unit tool applies to.
enum Scope { ALLIES, ENEMIES, ALL }
## Merge tier the custom card spawner produces.
enum CardTier { BASE, MERGED, DOUBLE_MERGED }
#endregion

#region Constants
# --- Command ids. GameManager._handle_debug_command() is the matching half of this
# --- contract; the two lists have to stay in sync.
const CMD_SPAWN_RANDOM: String = "spawn_random"           # { count: int }
const CMD_SPAWN_CUSTOM: String = "spawn_custom"           # { value: int, tier: int }
const CMD_DRAW: String = "draw"                           # { count: int }
const CMD_DRAW_TO_MAX: String = "draw_to_max"             # {}
const CMD_BUFF_HAND: String = "buff_hand"                 # { amount: int }
const CMD_DISCARD_RANDOM: String = "discard_random"       # {}
const CMD_CLEAR_HAND: String = "clear_hand"               # {}
const CMD_GRANT_ACTIONS: String = "grant_actions"         # { amount: int }
const CMD_GRANT_MERGES: String = "grant_merges"           # { amount: int }
const CMD_STEP_MAX_HAND: String = "step_max_hand"         # { delta: int }
const CMD_GRANT_NEXT_BONUS: String = "grant_next_bonus"   # { amount: int }
const CMD_STEP_DICE: String = "step_dice"                 # { delta: int }
const CMD_FILL_MOXIE: String = "fill_moxie"               # { scope: int, slot: int }
const CMD_DRAIN_MOXIE: String = "drain_moxie"             # { scope: int, slot: int }
const CMD_HEAL_FULL: String = "heal_full"                 # { scope: int, slot: int }
const CMD_DAMAGE: String = "damage"                       # { scope, slot, amount: int }
const CMD_TRUE_DAMAGE: String = "true_damage"             # { scope, slot, amount: int }
const CMD_ADD_SHIELD: String = "add_shield"               # { scope, slot, amount: int }
const CMD_CLEAR_SHIELD: String = "clear_shield"           # { scope: int, slot: int }
const CMD_KILL: String = "kill"                           # { scope: int, slot: int }
const CMD_APPLY_STATUS: String = "apply_status"           # { scope, slot, status_id, amount }
const CMD_CLEAR_STATUSES: String = "clear_statuses"       # { scope: int, slot: int }
const CMD_REROLL_INTENTS: String = "reroll_intents"       # {}
const CMD_RESPAWN_WAVE: String = "respawn_wave"           # {}
const CMD_CLEAR_WAVE: String = "clear_wave"               # {}

## Amounts the quick action buttons apply.
const DAMAGE_STEP: int = 5
const SHIELD_STEP: int = 10
const REGEN_STEP: int = 2
const GLOOM_STEP: int = 3

## Where the panel sits: bottom-left, directly above the button that opens it.
const PANEL_WIDTH: float = 336.0
const PANEL_HEIGHT: float = 404.0
const SEAT_LEFT: float = 18.0
const SEAT_BOTTOM: float = 50.0
const PADDING: int = 10
const ROW_SEPARATION: int = 5
const BUTTON_MIN_SIZE: Vector2 = Vector2(0.0, 26.0)

## Palette lifted from SkillTooltipPopup so the tools read as part of the HUD.
const PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)
const PANEL_BORDER: Color = Color(0.45, 0.78, 0.95, 0.5)
const TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)
const SECTION_COLOR: Color = Color(0.62, 0.72, 0.85)
const READOUT_COLOR: Color = Color(0.80, 0.85, 0.93)
const OVERFLOW_COLOR: Color = Color(1.0, 0.55, 0.45)
const READY_COLOR: Color = Color(0.55, 1.0, 0.68)
const LOCKED_COLOR: Color = Color(1.0, 0.72, 0.35)
#endregion

#region Private Variables
var _status_label: Label
var _hand_label: Label
var _deck_label: Label
var _turn_label: Label
var _hand_cap_label: Label
var _target_selector: OptionButton
var _tier_selector: OptionButton
var _value_spin: SpinBox
var _close_button: Button
## Buttons that mutate battle state. They stay disabled while the turn loop is not
## waiting for a player action, because that is the only moment it can accept one.
var _gated_buttons: Array[Button] = []
## Payload (scope/slot) of each entry in `_target_selector`, in the same order.
var _target_entries: Array[Dictionary] = []
## Labels currently in `_target_selector`, so an unchanged unit list is not rebuilt.
var _target_labels: PackedStringArray = PackedStringArray()
#endregion


#region Lifecycle Methods
func _init() -> void:
	name = "DebugMenuPopup"
	visible = false
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_seat_above_bottom_left()
	_build_layout()
	_apply_chrome()
	# Nothing may mutate the battle before the first player turn starts.
	set_gameplay_enabled(false)
#endregion

#region Public Methods
## Pushes live readouts and the unit list down from the scene. Called whenever the
## state changes (every action, every turn), never by this panel itself.
## @param snapshot - read-only numbers: hand/max_hand/deck/discard/actions/merges/
##                   turn/wave/waves/dice_size/next_bonus
## @param targets  - [{ "label": String, "scope": Scope, "slot": int }, ...]
func refresh(snapshot: Dictionary, targets: Array[Dictionary]) -> void:
	var hand: int = _snap_int(snapshot, "hand", 0)
	var max_hand: int = maxi(1, _snap_int(snapshot, "max_hand", 1))
	var over_cap: bool = hand > max_hand

	_hand_label.text = "Hand %d / %d%s" % [hand, max_hand, "   OVER CAP" if over_cap else ""]
	_hand_label.add_theme_color_override("font_color", OVERFLOW_COLOR if over_cap else READOUT_COLOR)
	_deck_label.text = "Deck %d   Discard %d" % [
		_snap_int(snapshot, "deck", 0),
		_snap_int(snapshot, "discard", 0),
	]
	_turn_label.text = "Turn %d   Wave %d/%d   d%d\nActions %d   Merges %d   Bonus %d" % [
		_snap_int(snapshot, "turn", 0),
		_snap_int(snapshot, "wave", 0),
		_snap_int(snapshot, "waves", 0),
		_snap_int(snapshot, "dice_size", 0),
		_snap_int(snapshot, "actions", 0),
		_snap_int(snapshot, "merges", 0),
		_snap_int(snapshot, "next_bonus", 0),
	]
	_hand_cap_label.text = str(max_hand)
	_rebuild_targets(targets)


## Enables or greys out every state-mutating tool. The scene locks the panel while
## the game is animating and unlocks it as soon as it waits for a player action.
func set_gameplay_enabled(enabled: bool) -> void:
	_status_label.text = "ready" if enabled else "locked"
	_status_label.add_theme_color_override("font_color", READY_COLOR if enabled else LOCKED_COLOR)
	_status_label.tooltip_text = "Debug tools are live." if enabled \
		else "Debug tools unlock while the game waits for your next action."
	for button: Button in _gated_buttons:
		button.disabled = not enabled
	_target_selector.disabled = not enabled
	_tier_selector.disabled = not enabled
	_value_spin.editable = enabled


func is_open() -> bool:
	return visible


func open_menu() -> void:
	visible = true


func close_menu() -> void:
	visible = false
	menu_closed.emit()


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()
#endregion


#region Private Methods
## Bottom-left, sitting directly on top of the button that opens it.
func _seat_above_bottom_left() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = SEAT_LEFT
	offset_right = SEAT_LEFT + PANEL_WIDTH
	offset_top = -(SEAT_BOTTOM + PANEL_HEIGHT)
	offset_bottom = -SEAT_BOTTOM


## Dark slab with an accent border, matched to SkillTooltipPopup.
func _apply_chrome() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = float(PADDING)
	box.content_margin_right = float(PADDING)
	box.content_margin_top = float(PADDING)
	box.content_margin_bottom = float(PADDING)
	add_theme_stylebox_override("panel", box)


func _build_layout() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)

	var title := _make_label("DEBUG - tester tools", 13, TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_status_label = _make_label("locked", 11, LOCKED_COLOR)
	header.add_child(_status_label)

	# Never gated: the menu must always be closable.
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.tooltip_text = "Close the debug menu (F1)"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(28.0, 22.0)
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)

	_build_cards_tab(tabs)
	_build_resources_tab(tabs)
	_build_units_tab(tabs)


## Overflow stress: spawning ignores `max_hand_size` on purpose, so a tester can see
## how the hand row lays out 10, 15 or 20+ cards.
func _build_cards_tab(tabs: TabContainer) -> void:
	var page := _make_tab(tabs, "Cards")

	_hand_label = _make_label("Hand 0 / 0", 12, READOUT_COLOR)
	page.add_child(_hand_label)
	_deck_label = _make_label("Deck 0   Discard 0", 11, SECTION_COLOR)
	page.add_child(_deck_label)

	page.add_child(_make_section("Stress spawn (ignores the hand cap)"))
	var spawn_row := _make_row()
	page.add_child(spawn_row)
	spawn_row.add_child(_make_button("+1 card", CMD_SPAWN_RANDOM, {"count": 1}))
	spawn_row.add_child(_make_button("+5 cards", CMD_SPAWN_RANDOM, {"count": 5}))
	spawn_row.add_child(_make_button("+10 cards", CMD_SPAWN_RANDOM, {"count": 10}))

	page.add_child(_make_section("Custom card"))
	var custom_row := _make_row()
	page.add_child(custom_row)
	_value_spin = SpinBox.new()
	_value_spin.min_value = 1.0
	_value_spin.max_value = 99.0
	_value_spin.step = 1.0
	_value_spin.value = 3.0
	_value_spin.tooltip_text = "Card value"
	_value_spin.custom_minimum_size = Vector2(70.0, 0.0)
	custom_row.add_child(_value_spin)
	_tier_selector = OptionButton.new()
	_tier_selector.add_item("V (flat)")
	_tier_selector.add_item("MV (merged)")
	_tier_selector.add_item("DMV (double)")
	_tier_selector.selected = int(CardTier.BASE)
	_tier_selector.tooltip_text = "Merge tier of the spawned card"
	_tier_selector.custom_minimum_size = Vector2(104.0, 0.0)
	_tier_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(_tier_selector)
	custom_row.add_child(_make_gated_button("Spawn", _on_spawn_custom_pressed))

	page.add_child(_make_section("Hand"))
	var draw_row := _make_row()
	page.add_child(draw_row)
	draw_row.add_child(_make_button("Draw 1", CMD_DRAW, {"count": 1}))
	draw_row.add_child(_make_button("Draw to cap", CMD_DRAW_TO_MAX))
	draw_row.add_child(_make_button("Buff +2", CMD_BUFF_HAND, {"amount": 2}))

	var hand_row := _make_row()
	page.add_child(hand_row)
	hand_row.add_child(_make_button("Discard random", CMD_DISCARD_RANDOM))
	hand_row.add_child(_make_button("Clear hand", CMD_CLEAR_HAND))


func _build_resources_tab(tabs: TabContainer) -> void:
	var page := _make_tab(tabs, "Resources")

	_turn_label = _make_label("", 11, READOUT_COLOR)
	page.add_child(_turn_label)

	page.add_child(_make_section("Actions"))
	var actions_row := _make_row()
	page.add_child(actions_row)
	actions_row.add_child(_make_button("+1", CMD_GRANT_ACTIONS, {"amount": 1}))
	actions_row.add_child(_make_button("+5", CMD_GRANT_ACTIONS, {"amount": 5}))
	actions_row.add_child(_make_button("+99", CMD_GRANT_ACTIONS, {"amount": 99}))

	page.add_child(_make_section("Merges"))
	var merges_row := _make_row()
	page.add_child(merges_row)
	merges_row.add_child(_make_button("+1", CMD_GRANT_MERGES, {"amount": 1}))
	merges_row.add_child(_make_button("+5", CMD_GRANT_MERGES, {"amount": 5}))
	merges_row.add_child(_make_button("+99", CMD_GRANT_MERGES, {"amount": 99}))

	page.add_child(_make_section("Hand cap"))
	var cap_row := _make_row()
	page.add_child(cap_row)
	cap_row.add_child(_make_button("-1", CMD_STEP_MAX_HAND, {"delta": -1}))
	_hand_cap_label = _make_label("7", 12, READOUT_COLOR)
	_hand_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand_cap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row.add_child(_hand_cap_label)
	cap_row.add_child(_make_button("+1", CMD_STEP_MAX_HAND, {"delta": 1}))

	page.add_child(_make_section("Modifiers"))
	var mod_row := _make_row()
	page.add_child(mod_row)
	mod_row.add_child(_make_button("Next skill +5", CMD_GRANT_NEXT_BONUS, {"amount": 5}))
	mod_row.add_child(_make_button("Dice -1", CMD_STEP_DICE, {"delta": -1}))
	mod_row.add_child(_make_button("Dice +1", CMD_STEP_DICE, {"delta": 1}))


func _build_units_tab(tabs: TabContainer) -> void:
	var page := _make_tab(tabs, "Units")

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 6)
	page.add_child(target_row)
	target_row.add_child(_make_label("Target", 11, SECTION_COLOR))
	_target_selector = OptionButton.new()
	_target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_selector.tooltip_text = "Which units the tools below apply to"
	target_row.add_child(_target_selector)

	page.add_child(_make_section("Moxie / Ultimate"))
	var moxie_row := _make_row()
	page.add_child(moxie_row)
	moxie_row.add_child(_make_unit_button("Fill", CMD_FILL_MOXIE))
	moxie_row.add_child(_make_unit_button("Zero", CMD_DRAIN_MOXIE))

	page.add_child(_make_section("Health"))
	var hp_row := _make_row()
	page.add_child(hp_row)
	hp_row.add_child(_make_unit_button("Full heal", CMD_HEAL_FULL))
	hp_row.add_child(_make_unit_button("Damage %d" % DAMAGE_STEP, CMD_DAMAGE, {"amount": DAMAGE_STEP}))
	hp_row.add_child(_make_unit_button("True %d" % DAMAGE_STEP, CMD_TRUE_DAMAGE, {"amount": DAMAGE_STEP}))

	page.add_child(_make_section("Shield / Status"))
	var shield_row := _make_row()
	page.add_child(shield_row)
	shield_row.add_child(_make_unit_button("Shield +%d" % SHIELD_STEP, CMD_ADD_SHIELD, {
		"amount": SHIELD_STEP,
	}))
	shield_row.add_child(_make_unit_button("Regen +%d" % REGEN_STEP, CMD_APPLY_STATUS, {
		"status_id": "regeneration",
		"amount": REGEN_STEP,
	}))
	shield_row.add_child(_make_unit_button("Gloom +%d" % GLOOM_STEP, CMD_APPLY_STATUS, {
		"status_id": "gloom",
		"amount": GLOOM_STEP,
	}))

	var clear_row := _make_row()
	page.add_child(clear_row)
	clear_row.add_child(_make_unit_button("Clear shield", CMD_CLEAR_SHIELD))
	clear_row.add_child(_make_unit_button("Clear statuses", CMD_CLEAR_STATUSES))
	clear_row.add_child(_make_unit_button("Kill", CMD_KILL))

	page.add_child(_make_section("Battle"))
	var battle_row := _make_row()
	page.add_child(battle_row)
	battle_row.add_child(_make_button("Reroll intents", CMD_REROLL_INTENTS))
	battle_row.add_child(_make_button("Respawn wave", CMD_RESPAWN_WAVE))
	battle_row.add_child(_make_button("Clear wave", CMD_CLEAR_WAVE))


func _make_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", ROW_SEPARATION)
	tabs.add_child(page)
	return page


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_section(text: String) -> Label:
	return _make_label(text, 11, SECTION_COLOR)


func _make_row() -> GridContainer:
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	return row


## A button that mutates battle state, so `set_gameplay_enabled` gates it.
func _make_gated_button(label: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_press)
	_gated_buttons.append(button)
	return button


## Fires `command` with a fixed payload.
func _make_button(label: String, command: String, args: Dictionary = {}) -> Button:
	return _make_gated_button(label, _on_action_pressed.bind(command, args))


## Fires `command` with the payload plus the selected target's scope/slot.
func _make_unit_button(label: String, command: String, args: Dictionary = {}) -> Button:
	return _make_gated_button(label, _on_unit_action_pressed.bind(command, args))


## Scope/slot payload of the selected target, or {} when nothing is selected.
func _current_target_args() -> Dictionary:
	var index: int = _target_selector.selected
	if index < 0 or index >= _target_entries.size():
		return {}
	return _target_entries[index].duplicate()


## Rebuilds the target list only when the labels actually changed, so a refresh
## never steals the tester's selection or flickers an open dropdown.
func _rebuild_targets(targets: Array[Dictionary]) -> void:
	_target_entries = targets.duplicate()
	var labels := PackedStringArray()
	for entry: Dictionary in targets:
		labels.append(str(entry.get("label", "?")))
	if labels == _target_labels:
		return

	var previous: int = _target_selector.selected
	_target_labels = labels
	_target_selector.clear()
	for label: String in labels:
		_target_selector.add_item(label)
	if _target_selector.item_count > 0:
		_target_selector.select(clampi(previous, 0, _target_selector.item_count - 1))


## Reads an int out of the read-only snapshot the scene hands down. Values arrive
## as Variants, so they are coerced instead of cast.
func _snap_int(snapshot: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = snapshot.get(key, fallback)
	if raw is int:
		var int_value: int = raw
		return int_value
	if raw is float:
		var float_value: float = raw
		return int(float_value)
	if raw is bool:
		var bool_value: bool = raw
		return 1 if bool_value else 0
	if raw is String:
		var text: String = raw
		if text.is_valid_int():
			return text.to_int()
	return fallback
#endregion


#region Signal Handlers
func _on_close_pressed() -> void:
	close_menu()


func _on_action_pressed(command: String, args: Dictionary) -> void:
	debug_command_requested.emit(command, args.duplicate())


## Stamps the selected target onto the payload. Without a selection the tool does
## nothing, so a malformed payload can never fall back to "every unit".
func _on_unit_action_pressed(command: String, args: Dictionary) -> void:
	var payload: Dictionary = _current_target_args()
	if payload.is_empty():
		return
	for key: Variant in args.keys():
		payload[key] = args[key]
	debug_command_requested.emit(command, payload)


func _on_spawn_custom_pressed() -> void:
	debug_command_requested.emit(CMD_SPAWN_CUSTOM, {
		"value": int(_value_spin.value),
		"tier": _tier_selector.selected,
	})
#endregion


