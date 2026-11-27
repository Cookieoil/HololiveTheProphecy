class_name FeatureFlagsTest
extends GdUnitTestSuite
## Locks the feature-flag registry (Core/FeatureFlags.gd): deterministic bucketing,
## the precedence order, and the rule that an unknown flag is always off.
##
## @author TheGreatJellyfish
## @version 11/27/2026

const SHIPPED_PATH: String = "res://Data/json/features.json"


## A run carrying one staged flag and one that is staged off.
func _state_with_flags() -> GameState:
	var state: GameState = GameState.new()
	state.set_run_seed(4242)
	state.apply_config({
		"flag_definitions": {
			"exp": {"enabled": true, "rollout_percent": 50, "description": "under test"},
			"off_flag": {"enabled": false, "description": "staged off"},
		},
	})
	return state


func _definitions() -> Dictionary:
	var root: Dictionary = {
		"flags": {
			"staged_full": {
				"enabled": true,
				"description": "On for everyone once enabled.",
			},
			"staged_none": {
				"enabled": true,
				"rollout_percent": 0,
				"description": "Enabled but staged off.",
			},
			"staged_half": {
				"enabled": true,
				"rollout_percent": 50,
				"description": "Half of the runs.",
			},
			"kill_switched": {
				"enabled": false,
				"rollout_percent": 100,
				"description": "Rolled out but switched off.",
			},
		},
	}
	var normalized: Dictionary = FeatureFlags.normalize(root)
	assert_that(normalized.get("errors")).is_equal(PackedStringArray())
	var raw_flags: Variant = normalized.get("flags")
	if raw_flags is Dictionary:
		var definitions: Dictionary = raw_flags
		return definitions
	return {}


func test_the_shipped_features_file_is_valid() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHIPPED_PATH))
	var normalized: Dictionary = FeatureFlags.normalize(parsed)
	assert_that(normalized.get("errors")).is_equal(PackedStringArray())


func test_bucketing_is_deterministic_and_in_range() -> void:
	var first: int = FeatureFlags.bucket_for("424242", "staged_half")
	assert_int(FeatureFlags.bucket_for("424242", "staged_half")).is_equal(first)
	assert_bool(first >= 0 and first < FeatureFlags.BUCKETS).is_true()
	assert_int(first).is_equal(FeatureFlags.bucket_for("424242", "staged_half"))


func test_a_flag_spreads_across_buckets() -> void:
	var on: int = 0
	for seed: int in range(1000):
		if FeatureFlags.bucket_for(str(seed), "staged_half") < 50:
			on += 1
	# A 50% bucket over 1000 runs must land near half; a hash that collapsed to one
	# bucket would show up here instead of only in the production numbers.
	assert_bool(on >= 400 and on <= 600).is_true()


func test_precedence_override_then_kill_switch_then_rollout() -> void:
	var plain: Dictionary = FeatureFlags.evaluate(_definitions(), {}, "1")
	assert_bool(FeatureFlags.is_active(plain, "staged_full")).is_true()
	assert_bool(FeatureFlags.is_active(plain, "staged_none")).is_false()
	assert_bool(FeatureFlags.is_active(plain, "kill_switched")).is_false()

	var forced_off: Dictionary = FeatureFlags.evaluate(_definitions(), {"staged_full": false}, "1")
	assert_bool(FeatureFlags.is_active(forced_off, "staged_full")).is_false()
	var forced_on: Dictionary = FeatureFlags.evaluate(_definitions(), {"kill_switched": true}, "1")
	assert_bool(FeatureFlags.is_active(forced_on, "kill_switched")).is_true()


func test_an_unknown_flag_is_off() -> void:
	var resolved: Dictionary = FeatureFlags.resolve("nope", _definitions(), {}, "1")
	assert_bool(resolved.get("enabled")).is_false()
	assert_str(str(resolved.get("source"))).is_equal(FeatureFlags.SOURCE_UNKNOWN)
	assert_bool(FeatureFlags.is_active(FeatureFlags.evaluate(_definitions(), {}, "1"), "nope")).is_false()


func test_a_half_rollout_is_on_for_roughly_half_the_seeds() -> void:
	var on: int = 0
	for seed: int in range(200):
		if FeatureFlags.is_active(FeatureFlags.evaluate(_definitions(), {}, str(seed)), "staged_half"):
			on += 1
	assert_bool(on > 50 and on < 150).is_true()


func test_a_malformed_registry_reports_every_problem() -> void:
	var normalized: Dictionary = FeatureFlags.normalize({
		"flags": {
			"Bad-Name": {"enabled": true, "description": "x"},
			"no_description": {"enabled": true},
			"bad_percent": {"enabled": true, "rollout_percent": 150, "description": "x"},
			"not_an_object": true,
		},
	})
	var raw_errors: Variant = normalized.get("errors")
	assert_bool(raw_errors is PackedStringArray).is_true()
	if raw_errors is PackedStringArray:
		var messages: PackedStringArray = raw_errors
		assert_int(messages.size()).is_equal(4)


func test_evaluate_reports_flags_in_name_order() -> void:
	var active: Dictionary = FeatureFlags.evaluate(_definitions(), {}, "7")
	assert_bool(FeatureFlags.is_active(active, "staged_full")).is_true()
	var keys: Array = active.keys()
	var sorted: Array = keys.duplicate()
	sorted.sort()
	assert_that(keys).is_equal(sorted)


## The typo trap this guard exists for: `rollout_pct` would otherwise read as
## "rollout_percent unset", and unset means 100% - a 5% canary shipping to everyone.
func test_a_typoed_key_is_rejected_instead_of_defaulting_to_full_rollout() -> void:
	var normalized: Dictionary = FeatureFlags.normalize({
		"flags": {
			"canary": {"enabled": true, "rollout_pct": 5, "description": "5% canary"},
		},
	})
	var raw_errors: Variant = normalized.get("errors")
	assert_bool(raw_errors is PackedStringArray).is_true()
	if raw_errors is PackedStringArray:
		var messages: PackedStringArray = raw_errors
		assert_int(messages.size()).is_equal(1)
		assert_bool(messages[0].contains("rollout_pct")).is_true()
		assert_bool(messages[0].contains("unknown key")).is_true()


## The `rollout_percent` a normalise() call stored for one flag, or -1 when the flag
## is missing. Typed so the test never calls int() on a Variant.
func _stored_percent(normalized: Dictionary, flag_name: String) -> int:
	var raw_flags: Variant = normalized.get("flags")
	if not (raw_flags is Dictionary):
		return -1
	var flags: Dictionary = raw_flags
	var raw_entry: Variant = flags.get(flag_name, {})
	if not (raw_entry is Dictionary):
		return -1
	var entry: Dictionary = raw_entry
	var raw_percent: Variant = entry.get("rollout_percent", -1)
	if raw_percent is int:
		var int_value: int = raw_percent
		return int_value
	if raw_percent is float:
		var float_value: float = raw_percent
		return int(float_value)
	return -1


## A value nobody can read must never become a full rollout: the fallback for a
## broken `rollout_percent` is off, not everyone (it used to fall back to 100%).
func test_an_unreadable_rollout_percent_fails_closed() -> void:
	for bad_value: Variant in ["5%", false, 12.5, null, -10, 150]:
		var normalized: Dictionary = FeatureFlags.normalize({
			"flags": {
				"canary": {"enabled": true, "rollout_percent": bad_value, "description": "x"},
			},
		})
		var raw_errors: Variant = normalized.get("errors")
		assert_bool(raw_errors is PackedStringArray).is_true()
		if raw_errors is PackedStringArray:
			var messages: PackedStringArray = raw_errors
			assert_int(messages.size()).is_equal(1)
		assert_int(_stored_percent(normalized, "canary")).is_equal(0)


func test_a_valid_rollout_percent_is_kept() -> void:
	var normalized: Dictionary = FeatureFlags.normalize({
		"flags": {
			"canary": {"enabled": true, "rollout_percent": 25, "description": "x"},
		},
	})
	assert_int(_stored_percent(normalized, "canary")).is_equal(25)
	assert_that(normalized.get("errors")).is_equal(PackedStringArray())


## The tester tool path: a flag flipped mid-run re-resolves through the same code the
## setup path uses, and an unknown name is refused instead of invented.
func test_a_run_can_flip_a_flag_through_the_debug_tool() -> void:
	var state: GameState = _state_with_flags()

	var report: Dictionary = state.flag_report()
	assert_bool(report.has("exp")).is_true()
	assert_bool(report.has("off_flag")).is_true()
	var raw_entry: Variant = report.get("exp", {})
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		assert_str(str(entry.get("description", ""))).is_equal("under test")

	assert_str(state.debug_set_flag({"name": "off_flag", "enabled": 1})).is_equal("Flag off_flag -> on")
	assert_bool(FeatureFlags.is_active(state.flags, "off_flag")).is_true()
	assert_str(state.debug_set_flag({"name": "exp", "enabled": 0})).is_equal("Flag exp -> off")
	assert_bool(FeatureFlags.is_active(state.flags, "exp")).is_false()
	assert_str(state.debug_set_flag({"name": "nope", "enabled": 1})).is_equal("Unknown flag 'nope'.")


## An override is the highest precedence, so it wins over a rollout of zero.
func test_an_override_beats_the_rollout() -> void:
	var state: GameState = GameState.new()
	state.set_run_seed(11)
	state.apply_config({
		"flag_definitions": {"exp": {"enabled": true, "rollout_percent": 0, "description": "x"}},
	})
	assert_bool(FeatureFlags.is_active(state.flags, "exp")).is_false()
	assert_bool(state.set_flag_override("exp", true)).is_true()
	assert_bool(FeatureFlags.is_active(state.flags, "exp")).is_true()
	assert_bool(state.set_flag_override("missing", true)).is_false()


## A run with no flags still reports an empty registry rather than failing.
func test_a_run_without_flags_reports_nothing() -> void:
	var state: GameState = GameState.new()
	state.set_run_seed(3)
	state.apply_config({})
	assert_int(state.flag_report().size()).is_equal(0)
	assert_int(state.flags.size()).is_equal(0)


func test_an_unknown_top_level_key_is_rejected() -> void:
	var normalized: Dictionary = FeatureFlags.normalize({"flags": {}, "extra": {}})
	var raw_errors: Variant = normalized.get("errors")
	assert_bool(raw_errors is PackedStringArray).is_true()
	if raw_errors is PackedStringArray:
		var messages: PackedStringArray = raw_errors
		assert_int(messages.size()).is_equal(1)
		assert_bool(messages[0].contains("extra")).is_true()


func test_a_non_string_description_is_rejected() -> void:
	var normalized: Dictionary = FeatureFlags.normalize({
		"flags": {"exp": {"enabled": true, "description": 5}},
	})
	var raw_errors: Variant = normalized.get("errors")
	assert_bool(raw_errors is PackedStringArray).is_true()
	if raw_errors is PackedStringArray:
		var messages: PackedStringArray = raw_errors
		assert_int(messages.size()).is_equal(1)
		assert_bool(messages[0].contains("must be a string")).is_true()
