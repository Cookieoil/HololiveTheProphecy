<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/SkillContext.gd` — `class_name SkillContext` extends `RefCounted`

`48` lines · [back to the map](../../CODEBASE_MAP.md)

> Runtime context passed to every EffectBlock.execute(). Three inter-block communication channels: card_value     – mutable skill value (bonus damage adds here) t…

State:
- L13 `caster: Unit`
- L14 `targets: Array[Unit] = []`
- L16 `card: Card ## Null for enemy skills (they use dices)`
- L17 `is_merged: bool = false`
- L18 `game_state: GameState`
- L20 `card_value: int = 0`
- L21 `stored_value: int = 0`
- L24 `pick_n_target: Callable = Callable()`
- L26 `pick_n_card: Callable = Callable()`
- L29 `flash_cards: Callable = Callable()`
- L31 `log_message: Callable = Callable()`

Public API:
- L45-47 `log(msg: String) -> void`

Private:
- L33-42 `_init`

Uses: Card, GameState, Unit
Used by: GDTest/AllyKitTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/EffectBlockMessageTest.gd, GDTest/EnemySkillBalanceTest.gd, Managers/GameManager.gd, Skills/EffectBlock.gd, Skills/SkillEffect.gd
Loads: —

