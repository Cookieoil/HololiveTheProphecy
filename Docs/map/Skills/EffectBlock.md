<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/EffectBlock.gd` — `class_name EffectBlock` extends `SkillEffect`

`675` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L212-258 `compute_value_from_inputs(card_val: int, stored_val: int, state: GameState, sample_target: Unit = null, caster: Unit = null) -> int`
- L266-323 `execute(ctx: SkillContext) -> void`
- L612-653 `get_description() -> String`

Private:
- L114-116 `_color_unit`
- L118-120 `_color_value`
- L122-123 `_color_card`
- L126-188 `_resolve_targets`
- L192-208 `_check_condition`
- L260-262 `_resolve_value`
- L324-348 `_deal_damage`
- L350-369 `_gain_shield`
- L371-389 `_reduce_shield`
- L392-411 `_heal`
- L414-435 `_deal_true_damage`
- L438-444 `_add_bonus`
- L447-457 `_apply_modifier`
- L462-465 `_flash_auto_selected`
- L468-498 `_modify_card`
- L501-516 `_apply_card_mod`
- L519-558 `_discard_card`
- L561-569 `_draw_card`
- L572-575 `_set_next_skill_bonus`
- L580-596 `_apply_status`
- L599-608 `_raise_max_hp`
- L656-673 `_describe_value`

Uses: Card, GameState, SkillContext, SkillEffect, Unit
Used by: Core/DataLoader.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/EnemySkillBalanceTest.gd, Skills/SkillPreviewFormatter.gd
Loads: —

