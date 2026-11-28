class_name GameDataValidatorTest
extends GdUnitTestSuite
## Locks every rule the game-data gate enforces (Tools/validate_gameData.gd).
##
## The validator had no test of its own, so the only thing standing behind it was the
## happy path: CI ran it against the current data and it printed PASSED. Nothing proved
## it still *rejects* bad data, which is the entire point of a gate.
##
## These tests drive `GameDataValidator.validate()`, the in-memory seam, so each rule is
## exercised against a hand-built bundle with no files, no scene tree and no exit code. The
## anchor is `test_the_valid_bundle_is_clean`: if that ever fails, every "X is an error"
## assertion below it is meaningless, so it is asserted first and asserted hard.
##
## @author TheGreatJellyfish
## @version 11/28/2026


#region Fixtures
## One effect that trips nothing: a single-target damage effect on a card value.
func _effect(effect_id: int, extra: Dictionary = {}) -> Dictionary:
	var effect: Dictionary = {
		"effect_id": effect_id,
		"order": 1,
		"trigger": "base",
		"action": "deal_damage",
		"status_id": "",
		"target_mode": "pick_n_enemy",
		"target_count": 1,
		"value_source": "card_value",
		"value_multiplier": 1,
		"value_divisor": 1,
		"value_offset": 0,
		"value_cap": -1,
		"fixed_amount": 0,
		"condition": "none",
		"negate_condition": false,
		"card_select_mode": "pick_n_card",
		"card_mod_type": "buff",
		"card_count": 1,
		"store_resolved_value": false,
	}
	effect.merge(extra, true)
	return effect


## A skill that trips nothing. `merged_description` is present but empty on purpose:
## its absence is a warning, so leaving it out would pollute every other assertion.
func _skill(effects: Array, extra: Dictionary = {}) -> Dictionary:
	var skill: Dictionary = {
		"display_name": "Skill",
		"base_categories": ["damage"],
		"description": "Deals damage.",
		"merged_categories": [],
		"merged_description": "",
		"merged_mode": "and_merged_first",
		"condition_threshold": 0,
		"effects": effects,
	}
	skill.merge(extra, true)
	return skill


func _unit(is_enemy: bool, skill_id: String, extra: Dictionary = {}) -> Dictionary:
	var unit: Dictionary = {
		"display_name": "Unit",
		"is_enemy": is_enemy,
		"max_hp": 20,
		"max_moxie": 20,
		"skill_1": skill_id,
		"skill_2": skill_id,
		"ultimate": "",
	}
	unit.merge(extra, true)
	return unit


## The smallest bundle that trips nothing at all - no errors and no warnings. Every
## test below is this bundle with exactly one thing broken.
func _valid_bundle() -> Dictionary:
	return {
		"skills": {
			"striker_1": _skill([_effect(1)]),
			"normal_enemy_1": _skill([_effect(2)]),
		},
		"allies": {"striker": _unit(false, "striker_1")},
		"enemies": {"normal_enemy": _unit(true, "normal_enemy_1")},
		"waves": {"waves": [{"wave_index": 0, "enemies": [{"unit_id": "normal_enemy"}]}]},
		"config": {
			"hand_size": 7,
			"actions_per_turn": 3,
			"merges_per_turn": 2,
			"decklist": [[2, 4], [3, 4]],
			"dice_progression": [6, 8, 10, 12],
			"allies": ["striker"],
			"wave_transition_mode": "full_turn",
		},
	}
#endregion


#region Helpers
## Runs the rules over one bundle with a fresh engine, so nothing leaks between tests.
func _report(bundle: Dictionary) -> Dictionary:
	var validator: GameDataValidator = GameDataValidator.new()
	auto_free(validator)
	return validator.validate(bundle)


func _errors(bundle: Dictionary) -> PackedStringArray:
	return _lines(_report(bundle), "errors")


func _warnings(bundle: Dictionary) -> PackedStringArray:
	return _lines(_report(bundle), "warnings")


func _lines(report: Dictionary, key: String) -> PackedStringArray:
	var raw: Variant = report.get(key, PackedStringArray())
	if raw is PackedStringArray:
		var listed: PackedStringArray = raw
		return listed
	return PackedStringArray()


func _has(entries: PackedStringArray, needle: String) -> bool:
	for entry: String in entries:
		if entry.contains(needle):
			return true
	return false


func _with_skill(patch: Dictionary) -> Dictionary:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	var skill: Dictionary = skills["striker_1"]
	skill.merge(patch, true)
	return bundle


func _with_ally(patch: Dictionary) -> Dictionary:
	var bundle: Dictionary = _valid_bundle()
	var allies: Dictionary = bundle["allies"]
	var ally: Dictionary = allies["striker"]
	ally.merge(patch, true)
	return bundle


func _with_config(patch: Dictionary) -> Dictionary:
	var bundle: Dictionary = _valid_bundle()
	var config: Dictionary = bundle["config"]
	config.merge(patch, true)
	return bundle


func _with_wave(patch: Dictionary) -> Dictionary:
	var bundle: Dictionary = _valid_bundle()
	var waves: Dictionary = bundle["waves"]
	var listed: Array = waves["waves"]
	var wave: Dictionary = listed[0]
	wave.merge(patch, true)
	return bundle


## The valid bundle with the striker's first effect patched.
func _with_effect(patch: Dictionary) -> Dictionary:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	var skill: Dictionary = skills["striker_1"]
	var effects: Array = skill["effects"]
	var effect: Dictionary = effects[0]
	effect.merge(patch, true)
	return bundle


## The valid bundle with one more effect appended to the striker's skill.
func _with_extra_effect(effect: Dictionary) -> Dictionary:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	var skill: Dictionary = skills["striker_1"]
	var effects: Array = skill["effects"]
	effects.append(effect)
	return bundle
#endregion


#region The anchor
## If this fails, every "X is an error" assertion below it is meaningless: a bundle
## that is already dirty would satisfy them for the wrong reason.
func test_the_valid_bundle_is_clean() -> void:
	var report: Dictionary = _report(_valid_bundle())

	assert_int(_lines(report, "errors").size()).is_equal(0)
	assert_int(_lines(report, "warnings").size()).is_equal(0)


## And the engine is idempotent: a second run over a dirty bundle must not accumulate
## the first run's diagnostics.
func test_a_second_run_starts_from_a_clean_slate() -> void:
	var validator: GameDataValidator = GameDataValidator.new()
	auto_free(validator)

	var broken: Dictionary = _with_ally({"max_hp": 0})
	var first: int = _lines(validator.validate(broken), "errors").size()
	assert_int(first).is_greater(0)
	# The same broken bundle again reports the same thing, not twice as much.
	assert_int(_lines(validator.validate(broken), "errors").size()).is_equal(first)
	assert_int(_lines(validator.validate(_valid_bundle()), "errors").size()).is_equal(0)
#endregion


#region Scalars and types
func test_a_boolean_where_a_number_belongs_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"max_hp": true})

	assert_bool(_has(_errors(bundle), "must be a number, not a boolean")).is_true()


func test_a_fractional_number_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"max_hp": 3.5})

	assert_bool(_has(_errors(bundle), "must be a whole number")).is_true()


## A quoted number is almost always an authoring slip, but the value is usable, so it
## warns rather than blocks.
func test_a_numeric_string_is_a_warning_not_an_error() -> void:
	var bundle: Dictionary = _with_ally({"max_hp": "12"})

	assert_bool(_has(_warnings(bundle), "write it as a JSON number")).is_true()
	assert_int(_errors(bundle).size()).is_equal(0)


func test_an_unknown_key_is_a_warning() -> void:
	var bundle: Dictionary = _with_ally({"max_health": 5})

	assert_bool(_has(_warnings(bundle), "unknown key 'max_health'")).is_true()


func test_a_non_object_skill_entry_is_an_error() -> void:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	skills["striker_1"] = 5

	assert_bool(_has(_errors(bundle), "must be an object")).is_true()


func test_a_non_string_display_name_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"display_name": 5})

	assert_bool(_has(_errors(bundle), "'display_name' must be a string")).is_true()
#endregion


#region Effect structure
## DataLoader falls back to a default for a missing key, so an absent `action` would
## silently become `deal_damage` instead of failing.
func test_a_missing_required_effect_key_is_an_error() -> void:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	var skill: Dictionary = skills["striker_1"]
	var effects: Array = skill["effects"]
	var effect: Dictionary = effects[0]
	effect.erase("action")

	assert_bool(_has(_errors(bundle), "missing required 'action'")).is_true()


func test_an_unknown_enum_value_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"action": "deal_damag"})

	assert_bool(_has(_errors(bundle), "unknown 'action' value 'deal_damag'")).is_true()


func test_an_invalid_trigger_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"trigger": "merge"})

	assert_bool(_has(_errors(bundle), "'trigger' must be 'base' or 'merged'")).is_true()


func test_a_duplicate_effect_id_inside_a_skill_is_an_error() -> void:
	var bundle: Dictionary = _with_extra_effect(_effect(1, {"order": 2}))

	assert_bool(_has(_errors(bundle), "duplicate effect_id 1")).is_true()


## Across skills it is only a warning: the ids are global bookkeeping, not a rule the
## runtime enforces.
func test_a_duplicate_effect_id_across_skills_is_a_warning() -> void:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	skills["normal_enemy_1"] = _skill([_effect(1)])

	assert_bool(_has(_warnings(bundle), "is also used by")).is_true()
	assert_int(_errors(bundle).size()).is_equal(0)


func test_a_duplicate_order_in_the_same_trigger_is_a_warning() -> void:
	var bundle: Dictionary = _with_extra_effect(_effect(3, {"order": 1}))

	assert_bool(_has(_warnings(bundle), "duplicate 'order' 1")).is_true()


func test_a_negative_order_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"order": -1})

	assert_bool(_has(_errors(bundle), "'order' must be >= 0")).is_true()
#endregion


#region Effect numbers
func test_a_divisor_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"value_divisor": 0})

	assert_bool(_has(_errors(bundle), "'value_divisor' must be >= 1")).is_true()


func test_a_negative_multiplier_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"value_multiplier": -1})

	assert_bool(_has(_errors(bundle), "'value_multiplier' must be >= 0")).is_true()


func test_a_value_cap_below_minus_one_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"value_cap": -5})

	assert_bool(_has(_errors(bundle), "'value_cap' must be -1 (off) or >= 0")).is_true()


func test_a_zero_value_cap_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"value_cap": 0})

	assert_bool(_has(_warnings(bundle), "always 0")).is_true()


func test_a_negative_target_count_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"target_count": -1})

	assert_bool(_has(_errors(bundle), "'target_count' must be >= 0")).is_true()


func test_an_oversized_target_count_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"target_count": 11})

	assert_bool(_has(_warnings(bundle), "looks too high")).is_true()
#endregion


#region Targeting, cards and statuses
func test_a_targeted_action_without_a_target_mode_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"target_mode": "none"})

	assert_bool(_has(_errors(bundle), "needs a target but target_mode is 'none'")).is_true()


func test_a_pick_n_mode_without_a_count_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"target_count": 0})

	assert_bool(_has(_errors(bundle), "needs target_count >= 1")).is_true()


func test_a_count_the_target_mode_ignores_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"target_mode": "all_enemies"})

	assert_bool(_has(_warnings(bundle), "ignores it")).is_true()


func test_a_card_action_without_a_card_count_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({
		"action": "draw_card", "target_mode": "none", "target_count": 0, "card_count": 0,
	})

	assert_bool(_has(_errors(bundle), "needs card_count >= 1")).is_true()


func test_a_card_action_ignoring_unit_targets_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"action": "draw_card", "card_count": 1})

	assert_bool(_has(_warnings(bundle), "ignores unit targets")).is_true()


func test_apply_status_with_an_unknown_status_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"action": "apply_status", "status_id": "gloom_2"})

	assert_bool(_has(_errors(bundle), "unknown status_id 'gloom_2'")).is_true()


func test_apply_status_with_an_empty_status_is_an_error() -> void:
	var bundle: Dictionary = _with_effect({"action": "apply_status", "status_id": ""})

	assert_bool(_has(_errors(bundle), "needs a non-empty 'status_id'")).is_true()


func test_a_status_id_outside_apply_status_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"status_id": "gloom"})

	assert_bool(_has(_warnings(bundle), "only used by apply_status")).is_true()


func test_negating_a_none_condition_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"negate_condition": true})

	assert_bool(_has(_warnings(bundle), "'negate_condition' is true but 'condition' is 'none'")).is_true()


func test_a_fixed_value_action_with_no_amount_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"value_source": "fixed", "fixed_amount": 0})

	assert_bool(_has(_warnings(bundle), "resolves to nothing")).is_true()


func test_a_negative_fixed_amount_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"value_source": "fixed", "fixed_amount": -2})

	assert_bool(_has(_warnings(bundle), "negative fixed_amount")).is_true()
#endregion


#region Cross-effect and cross-file rules
## `cached` reads a target a previous effect cached; without a producer it reads nothing.
func test_cached_targeting_without_a_producer_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"target_mode": "cached", "target_count": 0})

	assert_bool(_has(_warnings(bundle), "'cached' targeting is used")).is_true()


func test_stored_value_without_a_producer_is_a_warning() -> void:
	var bundle: Dictionary = _with_effect({"value_source": "stored_value"})

	assert_bool(_has(_warnings(bundle), "'stored_value' is used")).is_true()


func test_an_unreferenced_skill_is_a_warning() -> void:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	skills["spare_1"] = _skill([_effect(9)])

	assert_bool(_has(_warnings(bundle), "not referenced by any unit")).is_true()


## An enemy skill with merged effects and no threshold can never reach them: EnemyIntent
## marks the merge condition from the roll.
func test_an_enemy_skill_with_merged_effects_and_no_threshold_is_a_warning() -> void:
	var bundle: Dictionary = _valid_bundle()
	var skills: Dictionary = bundle["skills"]
	skills["normal_enemy_1"] = _skill([_effect(2), _effect(3, {"trigger": "merged"})])

	assert_bool(_has(_warnings(bundle), "condition_threshold 0")).is_true()


func test_an_ally_skill_with_a_threshold_is_a_warning() -> void:
	var bundle: Dictionary = _with_skill({"condition_threshold": 5})

	assert_bool(_has(_warnings(bundle), "ignore the threshold")).is_true()


func test_merged_mode_or_without_merged_effects_is_a_warning() -> void:
	var bundle: Dictionary = _with_skill({"merged_mode": "or"})

	assert_bool(_has(_warnings(bundle), "no merged effects")).is_true()


func test_a_merged_effect_without_a_description_is_a_warning() -> void:
	var bundle: Dictionary = _with_extra_effect(_effect(4, {"trigger": "merged"}))

	assert_bool(_has(_warnings(bundle), "'merged_description' is empty")).is_true()


func test_an_unknown_card_category_is_a_warning() -> void:
	var bundle: Dictionary = _with_skill({"base_categories": ["dammage"]})

	assert_bool(_has(_warnings(bundle), "unknown card category 'dammage'")).is_true()
#endregion


#region Units
func test_max_hp_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"max_hp": 0})

	assert_bool(_has(_errors(bundle), "'max_hp' must be >= 1")).is_true()


func test_max_moxie_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"max_moxie": 0})

	assert_bool(_has(_errors(bundle), "'max_moxie' must be >= 1")).is_true()


## The file the unit lives in decides `is_enemy`, so a contradicting field is a bug.
func test_an_is_enemy_mismatch_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"is_enemy": true})

	assert_bool(_has(_errors(bundle), "'is_enemy' is true but the unit lives in allies.json")).is_true()


func test_a_missing_is_enemy_is_a_warning() -> void:
	var bundle: Dictionary = _valid_bundle()
	var allies: Dictionary = bundle["allies"]
	var ally: Dictionary = allies["striker"]
	ally.erase("is_enemy")

	assert_bool(_has(_warnings(bundle), "missing 'is_enemy'")).is_true()


func test_a_unit_referencing_an_unknown_skill_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"skill_1": "nope"})

	assert_bool(_has(_errors(bundle), "references unknown skill 'nope'")).is_true()


func test_a_unit_with_no_usable_skill_is_an_error() -> void:
	var bundle: Dictionary = _with_ally({"skill_1": "", "skill_2": ""})

	assert_bool(_has(_errors(bundle), "defines no usable skill")).is_true()


## The two files share one `units` registry in GameDatabase, so the same id in both
## silently drops one of them.
func test_a_unit_id_in_both_files_is_an_error() -> void:
	var bundle: Dictionary = _valid_bundle()
	var enemies: Dictionary = bundle["enemies"]
	enemies["striker"] = _unit(true, "normal_enemy_1")

	assert_bool(_has(_errors(bundle), "is defined in both allies.json and enemies.json")).is_true()


func test_a_non_snake_case_unit_id_is_a_warning() -> void:
	var bundle: Dictionary = _valid_bundle()
	var allies: Dictionary = bundle["allies"]
	allies["Striker"] = allies["striker"]

	assert_bool(_has(_warnings(bundle), "not lower snake_case")).is_true()
#endregion


#region Waves
func test_an_empty_wave_is_an_error() -> void:
	var bundle: Dictionary = _with_wave({"enemies": []})

	assert_bool(_has(_errors(bundle), "'enemies' is empty")).is_true()


func test_a_wave_without_an_enemies_key_is_an_error() -> void:
	var bundle: Dictionary = _valid_bundle()
	var waves: Dictionary = bundle["waves"]
	var listed: Array = waves["waves"]
	var wave: Dictionary = listed[0]
	wave.erase("enemies")

	assert_bool(_has(_errors(bundle), "missing required 'enemies'")).is_true()


func test_a_wave_spawning_an_ally_is_an_error() -> void:
	var bundle: Dictionary = _with_wave({"enemies": [{"unit_id": "striker"}]})

	assert_bool(_has(_errors(bundle), "is an ally; waves may only spawn enemies")).is_true()


func test_a_wave_spawning_an_unknown_unit_is_an_error() -> void:
	var bundle: Dictionary = _with_wave({"enemies": [{"unit_id": "ghost"}]})

	assert_bool(_has(_errors(bundle), "references unknown unit 'ghost'")).is_true()


func test_a_wave_hp_override_below_one_is_an_error() -> void:
	var bundle: Dictionary = _valid_bundle()
	var waves: Dictionary = bundle["waves"]
	var listed: Array = waves["waves"]
	var wave: Dictionary = listed[0]
	var enemies: Array = wave["enemies"]
	var enemy: Dictionary = enemies[0]
	enemy["max_hp_override"] = 0

	assert_bool(_has(_errors(bundle), "'max_hp_override' must be >= 1")).is_true()


## DataLoader uses array order, so a mismatched index means the author's intent and the
## game's behaviour disagree.
func test_a_wave_index_mismatch_is_a_warning() -> void:
	var bundle: Dictionary = _with_wave({"wave_index": 3})

	assert_bool(_has(_warnings(bundle), "but it sits at position 0")).is_true()
#endregion


#region Config
func test_hand_size_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"hand_size": 0})

	assert_bool(_has(_errors(bundle), "'hand_size' must be >= 1")).is_true()


func test_an_empty_decklist_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"decklist": []})

	assert_bool(_has(_errors(bundle), "must hold at least one [value, count] pair")).is_true()


func test_a_decklist_pair_with_the_wrong_arity_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"decklist": [[2, 3, 4]]})

	assert_bool(_has(_errors(bundle), "needs exactly 2 numbers")).is_true()


func test_a_decklist_value_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"decklist": [[0, 3]]})

	assert_bool(_has(_errors(bundle), "card value must be >= 1")).is_true()


func test_a_decklist_count_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"decklist": [[2, 0]]})

	assert_bool(_has(_errors(bundle), "card count must be >= 1")).is_true()


func test_a_deck_smaller_than_a_starting_hand_is_a_warning() -> void:
	var bundle: Dictionary = _with_config({"decklist": [[2, 2]]})

	assert_bool(_has(_warnings(bundle), "fewer than one starting hand")).is_true()


func test_an_empty_dice_progression_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"dice_progression": []})

	assert_bool(_has(_errors(bundle), "must hold at least one dice size")).is_true()


func test_a_dice_size_below_one_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"dice_progression": [6, 0]})

	assert_bool(_has(_errors(bundle), "dice size must be >= 1")).is_true()


func test_a_dice_progression_that_shrinks_is_a_warning() -> void:
	var bundle: Dictionary = _with_config({"dice_progression": [6, 4]})

	assert_bool(_has(_warnings(bundle), "smaller than the previous entry")).is_true()


func test_a_duplicate_starting_ally_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"allies": ["striker", "striker"]})

	assert_bool(_has(_errors(bundle), "duplicate ally 'striker'")).is_true()


func test_an_enemy_as_a_starting_ally_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"allies": ["normal_enemy"]})

	assert_bool(_has(_errors(bundle), "is an enemy and cannot be a starting ally")).is_true()


func test_an_unknown_starting_ally_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"allies": ["ghost"]})

	assert_bool(_has(_errors(bundle), "references unknown unit 'ghost'")).is_true()


func test_an_unknown_wave_transition_mode_is_an_error() -> void:
	var bundle: Dictionary = _with_config({"wave_transition_mode": "sometimes"})

	assert_bool(_has(_errors(bundle), "unknown wave_transition_mode 'sometimes'")).is_true()
#endregion


#region Reporter (annotations and the job summary)
## Two skills, each with one effect, so the locator has a second occurrence to skip.
func _skills_text() -> String:
	return """{
	"striker_1": {
		"effects": [
			{
				"effect_id": 1
			}
		]
	},
	"striker_2": {
		"effects": [
			{
				"effect_id": 2
			}
		]
	}
}"""


func _units_text() -> String:
	return """{
	"striker": {
		"max_hp": 14
	},
	"healer": {
		"max_hp": 16
	}
}"""


func _waves_text() -> String:
	return """{
	"waves": [
		{
			"wave_index": 0,
			"enemies": [
				{ "unit_id": "normal_enemy" }
			]
		}
	]
}"""


func _config_text() -> String:
	return """{
	"hand_size": 7,
	"allies": ["striker"],
	"decklist": [[2, 7]]
}"""


func test_the_diagnostic_file_maps_a_message_to_its_repo_path() -> void:
	var paths: Dictionary = GameDataValidatorRunner.DIAGNOSTIC_PATHS

	assert_str(ValidationReporter.diagnostic_file("skills.json 'striker_1': boom", paths)).is_equal("Data/json/skills.json")
	assert_str(ValidationReporter.diagnostic_file("config.json: boom", paths)).is_equal("Data/json/config.json")
	assert_str(ValidationReporter.diagnostic_file("[workbook] boom", paths)).is_equal("Data/xlsx/game_data.xlsx")


## A loader failure names no file, so it must not be attributed to one.
func test_a_diagnostic_that_names_no_file_has_no_path() -> void:
	var paths: Dictionary = GameDataValidatorRunner.DIAGNOSTIC_PATHS

	assert_str(ValidationReporter.diagnostic_file("[loader] units registry is empty", paths)).is_equal("")
	assert_int(ValidationReporter.diagnostic_line("[loader] units registry is empty", {}, paths)).is_equal(0)


func test_the_diagnostic_line_locates_a_skill_and_its_effect() -> void:
	var raw: Dictionary = {"res://Data/json/skills.json": _skills_text()}
	var paths: Dictionary = GameDataValidatorRunner.DIAGNOSTIC_PATHS

	# The skill's own line when the message names no effect...
	assert_int(ValidationReporter.diagnostic_line("skills.json 'striker_2': boom", raw, paths)).is_equal(9)
	# ...and the effect block's line when it does.
	assert_int(ValidationReporter.diagnostic_line("skills.json 'striker_1' effect[0]: boom", raw, paths)).is_equal(5)
	# A skill that is not in the text locates nothing, rather than the wrong line.
	assert_int(ValidationReporter.diagnostic_line("skills.json 'ghost_1': boom", raw, paths)).is_equal(0)


func test_the_diagnostic_line_locates_a_unit_and_a_wave() -> void:
	var raw: Dictionary = {
		"res://Data/json/allies.json": _units_text(),
		"res://Data/json/waves.json": _waves_text(),
	}
	var paths: Dictionary = GameDataValidatorRunner.DIAGNOSTIC_PATHS

	assert_int(ValidationReporter.diagnostic_line("allies.json 'healer': boom", raw, paths)).is_equal(5)
	assert_int(ValidationReporter.diagnostic_line("waves.json wave[0] enemy[0]: boom", raw, paths)).is_equal(6)
	# With no index to go on, the `waves` key is the best that can be said.
	assert_int(ValidationReporter.diagnostic_line("waves.json: boom", raw, paths)).is_equal(2)


func test_the_diagnostic_line_locates_a_config_key() -> void:
	var raw: Dictionary = {"res://Data/json/config.json": _config_text()}
	var paths: Dictionary = GameDataValidatorRunner.DIAGNOSTIC_PATHS

	assert_int(ValidationReporter.diagnostic_line("config.json: 'hand_size' must be >= 1", raw, paths)).is_equal(2)
	# The key is found by name even when the message does not quote it.
	assert_int(ValidationReporter.diagnostic_line("config.json decklist[0]: boom", raw, paths)).is_equal(4)


func test_the_step_summary_reports_the_result_and_the_counts() -> void:
	var counts: Dictionary = {"skills": 15, "allies": 3, "enemies": 2, "waves": 2}
	var warnings: PackedStringArray = PackedStringArray(["a typo"])

	var passed: String = ValidationReporter.step_summary(0, PackedStringArray(), warnings, counts)
	assert_bool(passed.contains("**PASSED** (1 warning(s))")).is_true()
	assert_bool(passed.contains("| 15 | 3 | 2 | 2 |")).is_true()
	assert_bool(passed.contains("### Warnings")).is_true()

	var failed: String = ValidationReporter.step_summary(1, PackedStringArray(["boom"]), PackedStringArray(), counts)
	assert_bool(failed.contains("**FAILED** (1 error(s), 0 warning(s))")).is_true()
	assert_bool(failed.contains("### Errors")).is_true()
	assert_bool(failed.contains("- `boom`")).is_true()
#endregion
