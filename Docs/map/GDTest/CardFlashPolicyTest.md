<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/CardFlashPolicyTest.gd` — `class_name CardFlashPolicyTest` extends `GdUnitTestSuite`

`109` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks in *who caused it* when the game reveals hand cards it picked on its own: - an enemy acting on the player's hand flashes hostile (crimson) - the player's…
- L15 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L58-69 `test_enemy_auto_pick_flashes_hostile() -> void`
- L72-80 `test_enemy_auto_pick_with_empty_hand_does_not_flash() -> void`
- L83-94 `test_enemy_effect_flash_is_hostile() -> void`
- L97-108 `test_player_effect_flash_is_friendly() -> void`

Private:
- L27-41 `_make_manager`
- L44-45 `_recorder`
- L48-51 `_make_enemy`
- L54-55 `_accept_all`

Uses: Card, EnemyIntent, GameManager, GameState, GameUI, SkillContext, Unit, UnitData
Used by: —
Loads: —

