class_name DebugFlagsTest
extends GdUnitTestSuite
## Locks the debug palette's Flags tab (Scenes/HUD/DebugMenuPopup.gd): it renders one
## toggle per staged flag from the snapshot, it is gated like every other mutating
## tool, and it *asks* for a change with `set_flag` instead of touching the run.
##
## @author TheGreatJellyfish
## @version 11/27/2026

const FLAG_NAME: String = "exp"


func _snapshot() -> Dictionary:
	return {
		"flags": {
			FLAG_NAME: {"enabled": false, "description": "under test"},
		},
	}


func _panel() -> DebugMenuPopup:
	var panel := DebugMenuPopup.new()
	add_child(panel)
	auto_free(panel)
	var targets: Array[Dictionary] = []
	panel.refresh(_snapshot(), targets)
	panel.set_gameplay_enabled(true)
	return panel


func _toggle(panel: DebugMenuPopup) -> CheckButton:
	var found: Array[Node] = panel.find_children("*", "CheckButton", true, false)
	if found.is_empty():
		return null
	return found[0] as CheckButton


func test_the_flags_tab_lists_a_toggle_per_staged_flag() -> void:
	var panel: DebugMenuPopup = _panel()
	assert_bool(panel.show_tab("Flags")).is_true()
	var toggle: CheckButton = _toggle(panel)
	assert_object(toggle).is_not_null()
	if toggle == null:
		return
	assert_bool(toggle.button_pressed).is_false()
	# The tooltip is the flag's own description: what the experiment is trying to find
	# out, which the data gate requires every flag to carry.
	assert_bool(toggle.tooltip_text.contains("under test")).is_true()


func test_an_empty_registry_leaves_the_tab_without_toggles() -> void:
	var panel := DebugMenuPopup.new()
	add_child(panel)
	auto_free(panel)
	var targets: Array[Dictionary] = []
	panel.refresh({}, targets)
	assert_object(_toggle(panel)).is_null()


func test_toggling_a_flag_asks_the_turn_loop_to_apply_it() -> void:
	var panel: DebugMenuPopup = _panel()
	var toggle: CheckButton = _toggle(panel)
	assert_object(toggle).is_not_null()
	if toggle == null:
		return
	var seen: Array = []
	panel.debug_command_requested.connect(
		func(command: String, args: Dictionary) -> void:
			seen.append({"command": command, "args": args})
	)
	toggle.button_pressed = true
	assert_int(seen.size()).is_equal(1)
	if seen.is_empty():
		return
	var event: Dictionary = seen[0]
	assert_str(str(event.get("command", ""))).is_equal(DebugMenuPopup.CMD_SET_FLAG)
	var raw_args: Variant = event.get("args", {})
	assert_bool(raw_args is Dictionary).is_true()
	if raw_args is Dictionary:
		var args: Dictionary = raw_args
		assert_str(str(args.get("name", ""))).is_equal(FLAG_NAME)
		var raw_enabled: Variant = args.get("enabled", 0)
		assert_bool(raw_enabled is int).is_true()
		if raw_enabled is int:
			var enabled: int = raw_enabled
			assert_int(enabled).is_equal(1)
