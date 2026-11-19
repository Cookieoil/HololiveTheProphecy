<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/EffectBlock.gd` — `class_name EffectBlock` extends `SkillEffect`

`660` lines · [back to the map](../../CODEBASE_MAP.md)

> The universal data skill effect component Use configureble resource for all effect scripts Execution pipeline: Phase 1: Resolve Targets Phase 2: Check Condition…

Sections: Shared Enums · Exports · Helpers · Phase 1: Resolve Targets · Phase 2: Check Conditions · Phase 3: Resolve Values · Phase 3: Resolve Values · Phase 4: Execute Action · (+1 more)
- L17-26 `enum TargetMode` = NONE
- L29-32 `enum Condition` = NONE
- L35-49 `enum Action` = DEAL_DAMAGE
- L52-61 `enum ValueSource` = CARD_VALUE
- L64-68 `enum CardSelectMode` = PICK_N_CARD
- L71-74 `enum CardModType` = BUFF

Exports:
- L82 `target_mode: TargetMode = TargetMode.NONE`
- L83 `target_count: int = 1`
- L86 `condition: Condition = Condition.NONE`
- L87 `negate_condition: bool = false`
- L90 `action_type: Action = Action.DEAL_DAMAGE`
- L91 `card_select_mode: CardSelectMode = CardSelectMode.PICK_N_CARD`
- L92 `card_mod_type: CardModType = CardModType.BUFF`
- L93 `card_count: int = 1 # For draw_card and auto_top_n`
- L96 `status_id: String`
- L99 `value_source: ValueSource = ValueSource.CARD_VALUE`
- L100 `fixed_amount: int = 0`
- L101 `value_multiplier: int = 1`
- L102 `value_divisor: int = 1`
- L103 `value_offset: int = 0`
- L104 `value_cap: int = -1 # -1 = no cap`
- L107 `store_resolved_value: bool = false`

Public API:
- L208-250 `compute_value_from_inputs(card_val: int, stored_val: int, state: GameState, sample_target: Unit = null) -> int`
- L258-310 `execute(ctx: SkillContext) -> void`
- L597-638 `get_description() -> String`

Private:
- L113-115 `_color_unit`
- L117-119 `_color_value`
- L121-122 `_color_card`
- L125-183 `_resolve_targets`
- L187-203 `_check_condition`
- L252-254 `_resolve_value`
- L311-335 `_deal_damage`
- L337-356 `_gain_shield`
- L358-376 `_reduce_shield`
- L379-398 `_heal`
- L401-422 `_deal_true_damage`
- L425-429 `_add_bonus`
- L432-442 `_apply_modifier`
- L447-450 `_flash_auto_selected`
- L453-483 `_modify_card`
- L486-501 `_apply_card_mod`
- L504-543 `_discard_card`
- L546-554 `_draw_card`
- L557-560 `_set_next_skill_bonus`
- L565-581 `_apply_status`
- L584-593 `_raise_max_hp`
- L641-658 `_describe_value`

Uses: Card, GameState, SkillContext, SkillEffect, Unit
Used by: Core/DataLoader.gd, Skills/SkillContext.gd, Skills/SkillEffect.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

