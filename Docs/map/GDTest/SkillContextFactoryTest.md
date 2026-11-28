<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/SkillContextFactoryTest.gd` — `class_name SkillContextFactoryTest` extends `GdUnitTestSuite`

`359` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks Managers/SkillContextFactory.gd directly: the callables a skill resolves through. The extraction is what makes these cheap to test - no GameManager, no bo…

Sections: Harness · Ally context · Enemy context · The recorder seam
- L21 `class MemorySink extends TelemetrySink` (members are not indexed)
- L39 `class PromptUI extends GameUI` (members are not indexed)

Constants:
- L15 `TEMP_ROOT: String = "user://skill_context_test"`

State:
- L16 `_temp_dir: String = ""`
- L17 `_run_index: int = 0`

Public API:
- L77-78 `before() -> void`
- L81-86 `after() -> void`
- L175-193 `test_a_turn_wide_bonus_lands_on_the_card_value_and_is_spent() -> void` — A merged Buff sets a turn-wide bonus on the state. It belongs to the next card played and is consumed by that card, so a turn cannot collect the same bonus twic…
- L198-213 `test_a_card_prompt_offers_the_filtered_hand_and_returns_the_answer() -> void` — The prompt offers exactly what the filter let through - the alternatives the player chose between - and hands back whatever the UI answered.
- L217-229 `test_an_empty_candidate_list_never_prompts() -> void` — Nothing to choose from is not a prompt: an empty list short-circuits before the UI.
- L234-246 `test_a_target_prompt_offers_both_sides_of_the_board() -> void` — A target prompt searches the whole board: a skill that may name an ally or an enemy sees both sides, not just the caster's own.
- L251-265 `test_a_reveal_reaches_the_ui_and_an_empty_reveal_never_does() -> void` — Revealing auto-picked cards is a flourish, not a prompt; revealing nothing is not even that. A player-caused reveal is friendly, so it is never flashed as hosti…
- L270-280 `test_a_log_line_is_indented_under_the_action_line() -> void` — The log callback is the skill's voice in the battle log, and it is indented under the action line the turn loop already printed.
- L288-310 `test_an_enemy_is_never_prompted_and_flashes_hostile() -> void` — An enemy action is never a prompt: the roll and the merged flag come from the intent, targeting is chosen silently (on the player's side, which is what it attac…
- L315-324 `test_enemy_targeting_is_seeded_and_not_a_fixed_slot_order() -> void` — Silent targeting still has to be reproducible: the same seed picks the same ally, so a run replays exactly. It is a real shuffle too, not slot order in disguise…
- L332-357 `test_a_prompt_reaches_the_recorder_with_the_alternatives_it_was_chosen_over() -> void` — The recorder is passed in for one reason: a prompt has to record the alternatives it was chosen over, or the pick-rate report has no denominator. This drives th…

Private:
- L71-74 `_make_ui`
- L90-98 `_remove_tree`
- L101-107 `_make_unit`
- L111-121 `_make_state`
- L125-132 `_make_recorder`
- L136-137 `_accept_units`
- L141-144 `_only_value`
- L148-160 `_enemy_pick_order`
- L164-168 `_first_decision`

Uses: Card, EnemyIntent, GameState, GameUI, SkillContext, SkillContextFactory, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, Unit, UnitData
Used by: —
Loads: —

