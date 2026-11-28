class_name DataLoaderTest
extends GdUnitTestSuite
## Locks how DataLoader turns config.json into the runtime config: the defaults it falls
## back to, the values it clamps, and the diagnostics it reports instead of failing.
##
## Written *before* the build was split into per-section helpers, so the split could be
## checked rather than trusted - the rules below are what "unchanged behaviour" means.
##
## The loader keeps its error list in a static, so every helper here resets it first
## (`DataLoader.reload()`); otherwise a previous test's diagnostics would still be in it
## and the next test would pass for the wrong reason.
##
## @author TheGreatJellyfish
## @version 11/28/2026


#region Helpers
## A config.json that produces no diagnostics at all.
func _valid_config() -> Dictionary:
	return {
		"hand_size": 7,
		"actions_per_turn": 3,
		"merges_per_turn": 2,
		"decklist": [[3, 4], [5, 2]],
		"dice_progression": [6, 8, 10],
		"allies": ["striker"],
		"wave_transition_mode": "half_turn",
	}


## `_valid_config()` with `key` replaced (or added).
func _config_with(key: String, value: Variant) -> Dictionary:
	var config: Dictionary = _valid_config()
	config[key] = value
	return config


## `_valid_config()` without `key`, so the fallback path is what is under test.
func _config_without(key: String) -> Dictionary:
	var config: Dictionary = _valid_config()
	config.erase(key)
	return config


## `_valid_config()` without several keys, for a test that overrides them itself.
func _config_without_all(keys: PackedStringArray) -> Dictionary:
	var config: Dictionary = _valid_config()
	for key: String in keys:
		config.erase(key)
	return config


## The three per-turn scalars, so a test can leave them out and set its own.
const TURN_BUDGET_KEYS: PackedStringArray = ["hand_size", "actions_per_turn", "merges_per_turn"]


## The unit registry an ally id resolves against.
func _units() -> Dictionary:
	var data: UnitData = UnitData.new()
	data.unit_id = "striker"
	data.display_name = "Striker"
	var units: Dictionary = {"striker": data}
	return units


## The config `config_json` builds to, with the loader's static error list reset first.
func _build(config_json: Dictionary, units: Dictionary = {}) -> Dictionary:
	DataLoader.reload()
	return DataLoader._build_config(config_json, units)


## Every diagnostic building `config_json` produced, as one string so a failure shows
## what was actually reported.
func _error_text(config_json: Dictionary, units: Dictionary = {}) -> String:
	_build(config_json, units)
	return "\n".join(DataLoader.get_errors())
#endregion


#region A complete config
func test_a_complete_config_builds_every_key_without_a_diagnostic() -> void:
	var config: Dictionary = _build(_valid_config(), _units())

	assert_str(_error_text(_valid_config(), _units())).is_empty()
	assert_int(config["hand_size"]).is_equal(7)
	assert_int(config["actions_per_turn"]).is_equal(3)
	assert_int(config["merges_per_turn"]).is_equal(2)
	assert_array(config["decklist"]).is_equal([[3, 4], [5, 2]])
	assert_array(config["dice_progression"]).is_equal([6, 8, 10])
	assert_array(config["allies"]).is_equal(["striker"])
	assert_str(config["wave_transition_mode"]).is_equal("half_turn")


## The loader keeps unknown keys, so a setting can be added to config.json before the
## code that reads it exists.
func test_an_unknown_key_survives_the_build() -> void:
	var config: Dictionary = _build(_config_with("future_setting", [1, 2]), _units())

	assert_array(config["future_setting"]).is_equal([1, 2])


func test_an_empty_config_reports_it_and_builds_nothing() -> void:
	assert_str(_error_text({})).contains("config.json is empty")
	assert_dict(_build({})).is_empty()
#endregion


#region Defaults and clamps
func test_a_missing_scalar_falls_back_to_the_game_state_default() -> void:
	var json: Dictionary = _config_without_all(TURN_BUDGET_KEYS)
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).is_empty()
	assert_int(config["hand_size"]).is_equal(GameState.MAX_HAND_SIZE)
	assert_int(config["actions_per_turn"]).is_equal(GameState.ACTIONS_PER_TURN)
	assert_int(config["merges_per_turn"]).is_equal(GameState.MERGES_PER_TURN)


## A hand of 0 would deal nothing and 0 actions would end every turn instantly, so both are
## clamped up. A negative turn budget is clamped the same way rather than trusted.
func test_a_nonsense_turn_budget_is_clamped() -> void:
	var json: Dictionary = _config_without_all(TURN_BUDGET_KEYS)
	json["hand_size"] = 0
	json["actions_per_turn"] = -5
	json["merges_per_turn"] = -1
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).is_empty()
	assert_int(config["hand_size"]).is_equal(1)
	assert_int(config["actions_per_turn"]).is_equal(0)
	assert_int(config["merges_per_turn"]).is_equal(0)


func test_a_missing_wave_transition_mode_defaults_to_a_full_turn() -> void:
	var config: Dictionary = _build(_config_without("wave_transition_mode"), _units())

	assert_str(config["wave_transition_mode"]).is_equal("full_turn")


## JSON parses every number as a float, so a whole number arrives as one.
func test_a_float_from_json_becomes_an_int() -> void:
	var config: Dictionary = _build(_config_with("hand_size", 7.0), _units())

	assert_int(config["hand_size"]).is_equal(7)


func test_a_non_numeric_scalar_falls_back_to_its_default() -> void:
	var config: Dictionary = _build(_config_with("hand_size", "seven"), _units())

	assert_int(config["hand_size"]).is_equal(GameState.MAX_HAND_SIZE)
#endregion


#region The decklist
## A decklist entry is a [value, count] pair. Anything else is a typo in the file, and the
## loader reports it rather than dealing a card with no count.
func test_a_decklist_entry_that_is_not_a_pair_is_reported() -> void:
	var json: Dictionary = _config_with("decklist", [3, [5, 2]])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).contains("decklist entry is not a [value, count] pair")
	assert_array(config["decklist"]).is_equal([[5, 2]])


func test_a_decklist_pair_with_one_value_is_reported() -> void:
	var json: Dictionary = _config_with("decklist", [[3]])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).contains("decklist entry needs 2 values")
	assert_array(config["decklist"]).is_empty()


## A count of 0 is a deliberate "no copies", not a mistake, so it is dropped silently -
## while a malformed entry above is reported.
func test_a_decklist_count_of_zero_is_dropped_without_a_diagnostic() -> void:
	var json: Dictionary = _config_with("decklist", [[3, 0], [5, 2]])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).is_empty()
	assert_array(config["decklist"]).is_equal([[5, 2]])


func test_an_empty_decklist_is_reported() -> void:
	var json: Dictionary = _config_with("decklist", [])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).contains("decklist is empty")
	assert_array(config["decklist"]).is_empty()


func test_a_decklist_pair_of_floats_becomes_ints() -> void:
	var config: Dictionary = _build(_config_with("decklist", [[3.0, 4.0]]), _units())

	assert_array(config["decklist"]).is_equal([[3, 4]])
#endregion


#region The dice progression
func test_the_dice_progression_is_coerced_to_ints() -> void:
	var config: Dictionary = _build(_config_with("dice_progression", [6.0, 8.0]), _units())

	assert_array(config["dice_progression"]).is_equal([6, 8])


func test_an_empty_dice_progression_is_reported() -> void:
	var json: Dictionary = _config_with("dice_progression", [])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).contains("dice_progression is empty")
	assert_array(config["dice_progression"]).is_empty()
#endregion


#region The ally list
## An id with no unit behind it would be a slot the player cannot use, so it is reported
## and left out.
func test_an_unknown_ally_is_reported_and_dropped() -> void:
	var json: Dictionary = _config_with("allies", ["striker", "ghost"])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).contains("allies references unknown unit 'ghost'")
	assert_array(config["allies"]).is_equal(["striker"])


## A blank id is padding in the file rather than a broken reference, so it is dropped
## without a diagnostic - unlike an id that names nothing.
func test_a_blank_ally_id_is_dropped_without_a_diagnostic() -> void:
	var json: Dictionary = _config_with("allies", [" ", "striker"])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).is_empty()
	assert_array(config["allies"]).is_equal(["striker"])


func test_an_ally_id_is_trimmed() -> void:
	var config: Dictionary = _build(_config_with("allies", ["  striker  "]), _units())

	assert_array(config["allies"]).is_equal(["striker"])


func test_an_empty_ally_list_is_reported() -> void:
	var json: Dictionary = _config_with("allies", [])
	var config: Dictionary = _build(json, _units())

	assert_str(_error_text(json, _units())).contains("allies list is empty")
	assert_array(config["allies"]).is_empty()
#endregion