<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/EffectBlock.gd` — `class_name EffectBlock` extends `SkillEffect`

`668` lines · [back to the map](../../CODEBASE_MAP.md)

> The universal data skill effect component Use configureble resource for all effect scripts Execution pipeline: Phase 1: Resolve Targets Phase 2: Check Condition…

Sections: Shared Enums · Exports · Helpers · Phase 1: Resolve Targets · Phase 2: Check Conditions · Phase 3: Resolve Values · Phase 4: Execute Action · Auto-Generated Description
- L17-26 `enum TargetMode` = NONE
- L29-32 `enum Condition` = NONE
- L35-49 `enum Action` = DEAL_DAMAGE
- L52-62 `enum ValueSource` = CARD_VALUE
- L65-69 `enum CardSelectMode` = PICK_N_CARD
- L72-75 `enum CardModType` = BUFF

Exports:
- L83 `target_mode: TargetMode = TargetMode.NONE`
- L84 `target_count: int = 1`
- L87 `condition: Condition = Condition.NONE`
- L88 `negate_condition: bool = false`
- L91 `action_type: Action = Action.DEAL_DAMAGE`
- L92 `card_select_mode: CardSelectMode = CardSelectMode.PICK_N_CARD`
- L93 `card_mod_type: CardModType = CardModType.BUFF`
- L94 `card_count: int = 1 # For draw_card and auto_top_n`
- L97 `status_id: String`
- L100 `value_source: ValueSource = ValueSource.CARD_VALUE`
- L101 `fixed_amount: int = 0`
- L102 `value_multiplier: int = 1`
- L103 `value_divisor: int = 1`
- L104 `value_offset: int = 0`
- L105 `value_cap: int = -1 # -1 = no cap`
- L108 `store_resolved_value: bool = false`

Public API:
- L205-251 `compute_value_from_inputs(card_val: int, stored_val: int, state: GameState, sample_target: Unit = null, caster: Unit = null) -> int`
- L259-316 `execute(ctx: SkillContext) -> void`
- L605-646 `get_description() -> String`

Private:
- L115-116 `_color_unit`
- L119-181 `_resolve_targets`
- L185-201 `_check_condition`
- L253-255 `_resolve_value`
- L317-341 `_deal_damage`
- L343-362 `_gain_shield`
- L364-382 `_reduce_shield`
- L385-404 `_heal`
- L407-428 `_deal_true_damage`
- L431-437 `_add_bonus`
- L440-450 `_apply_modifier`
- L455-458 `_flash_auto_selected`
- L461-491 `_modify_card`
- L494-509 `_apply_card_mod`
- L512-551 `_discard_card`
- L554-562 `_draw_card`
- L565-568 `_set_next_skill_bonus`
- L573-589 `_apply_status`
- L592-601 `_raise_max_hp`
- L649-666 `_describe_value`

Uses: Card, GameState, SkillContext, SkillEffect, Unit
Used by: Core/DataLoader.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/EffectBlockMessageTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/TelemetryTest.gd, Skills/SkillPreviewFormatter.gd
Loads: —

