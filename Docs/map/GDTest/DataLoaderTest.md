<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DataLoaderTest.gd` — `class_name DataLoaderTest` extends `GdUnitTestSuite`

`247` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks how DataLoader turns config.json into the runtime config: the defaults it falls back to, the values it clamps, and the diagnostics it reports instead of f…

Sections: Helpers · A complete config · Defaults and clamps · The decklist · The dice progression · The ally list

Constants:
- L54 `TURN_BUDGET_KEYS: PackedStringArray` — The three per-turn scalars, so a test can leave them out and set its own.

Public API:
- L81-91 `test_a_complete_config_builds_every_key_without_a_diagnostic() -> void`
- L96-99 `test_an_unknown_key_survives_the_build() -> void` — The loader keeps unknown keys, so a setting can be added to config.json before the code that reads it exists.
- L102-104 `test_an_empty_config_reports_it_and_builds_nothing() -> void`
- L109-116 `test_a_missing_scalar_falls_back_to_the_game_state_default() -> void`
- L121-131 `test_a_nonsense_turn_budget_is_clamped() -> void` — A hand of 0 would deal nothing and 0 actions would end every turn instantly, so both are clamped up. A negative turn budget is clamped the same way rather than…
- L134-137 `test_a_missing_wave_transition_mode_defaults_to_a_full_turn() -> void`
- L141-144 `test_a_float_from_json_becomes_an_int() -> void` — JSON parses every number as a float, so a whole number arrives as one.
- L147-150 `test_a_non_numeric_scalar_falls_back_to_its_default() -> void`
- L157-162 `test_a_decklist_entry_that_is_not_a_pair_is_reported() -> void` — A decklist entry is a [value, count] pair. Anything else is a typo in the file, and the loader reports it rather than dealing a card with no count.
- L165-170 `test_a_decklist_pair_with_one_value_is_reported() -> void`
- L175-180 `test_a_decklist_count_of_zero_is_dropped_without_a_diagnostic() -> void` — A count of 0 is a deliberate "no copies", not a mistake, so it is dropped silently - while a malformed entry above is reported.
- L183-188 `test_an_empty_decklist_is_reported() -> void`
- L191-194 `test_a_decklist_pair_of_floats_becomes_ints() -> void`
- L199-202 `test_the_dice_progression_is_coerced_to_ints() -> void`
- L205-210 `test_an_empty_dice_progression_is_reported() -> void`
- L217-222 `test_an_unknown_ally_is_reported_and_dropped() -> void` — An id with no unit behind it would be a slot the player cannot use, so it is reported and left out.
- L227-232 `test_a_blank_ally_id_is_dropped_without_a_diagnostic() -> void` — A blank id is padding in the file rather than a broken reference, so it is dropped without a diagnostic - unlike an id that names nothing.
- L235-238 `test_an_ally_id_is_trimmed() -> void`
- L241-246 `test_an_empty_ally_list_is_reported() -> void`

Private:
- L19-28 `_valid_config`
- L32-35 `_config_with`
- L39-42 `_config_without`
- L46-50 `_config_without_all`
- L58-63 `_units`
- L67-69 `_build`
- L74-76 `_error_text`

Uses: DataLoader, GameState, UnitData
Used by: —
Loads: —

