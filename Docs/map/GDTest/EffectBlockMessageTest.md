<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/EffectBlockMessageTest.gd` — `class_name EffectBlockMessageTest` extends `GdUnitTestSuite`

`121` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the colours of the battle-log lines EffectBlock writes. Every number in a message wears the colour of the stat it belongs to, and those colours belong to…

Sections: Helpers · The palette the messages are built from · Damage · Shield and heal

Constants:
- L15 `HP_TAG: String` — The tags the messages must carry, pinned as literals on purpose: moving a battle-log colour is a deliberate act, and this is the check that notices it.
- L16 `SHIELD_TAG: String`
- L17 `ENEMY_TAG: String`
- L18 `CLOSE_TAG: String = "[/color]"`

Public API:
- L60-63 `test_the_pinned_tags_are_the_colour_utils_palette() -> void`
- L68-80 `test_damage_line_colours_every_hp_number_and_the_unit_it_hit() -> void`
- L83-93 `test_absorbed_damage_still_names_the_attempted_number_in_hp_colour() -> void`
- L98-107 `test_shield_gain_colours_the_gained_and_the_total_in_shield_colour() -> void`
- L110-119 `test_heal_line_colours_the_restored_and_the_total_in_hp_colour() -> void`

Private:
- L22-28 `_make_unit`
- L33-39 `_make_block`
- L42-46 `_make_context`
- L50-55 `_run`

Uses: DataLoader, EffectBlock, GameState, SkillContext, Unit, UnitData
Used by: —
Loads: —

