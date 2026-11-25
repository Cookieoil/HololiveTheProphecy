class_name AllyKitTest
extends GdUnitTestSuite
## Tests for the MOBA-style pure-skill rework of all ally kits.
## Covers: shield-slam, hand-scaling, value-positive buff, self-shield cleave,
## and the corrected SkillPreviewFormatter token substitution.
##
## @author TheGreatJellyfish
## @version 11/25/2026

#region Helpers
func _make_enemy_skill() -> SkillData:
	return SkillData.new()

func _make_ally_data(skill1: SkillData = null, skill2: SkillData = null, ult: SkillData = null) -> UnitData:
	var data: UnitData = UnitData.new()
	data.display_name = "Test Ally"
	data.max_hp = 20
	data.max_moxie = 20
	data.skill_1 = skill1
	data.skill_2 = skill2
	data.ultimate = ult
	return data

func _make_ally(skill1: SkillData = null, skill2: SkillData = null, ult: SkillData = null, shield: int = 0) -> Unit:
	var unit: Unit = Unit.new(_make_ally_data(skill1, skill2, ult))
	unit.shield = shield
	return unit

func _make_effect_block(
	action: String,
	value_source: String = "card_value",
	multiplier: int = 1,
	divisor: int = 1,
	offset: int = 0,
	cap: int = -1,
	fixed: int = 0,
	card_count: int = 1
) -> EffectBlock:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = DataLoader.ACTION_MAP[action]
	block.value_source = DataLoader.VALUE_SOURCE_MAP[value_source]
	block.value_multiplier = multiplier
	block.value_divisor = divisor
	block.value_offset = offset
	block.value_cap = cap
	block.fixed_amount = fixed
	block.card_count = card_count
	block.target_mode = EffectBlock.TargetMode.NONE
	block.condition = EffectBlock.Condition.NONE
	block.card_select_mode = EffectBlock.CardSelectMode.PICK_N_CARD
	block.card_mod_type = EffectBlock.CardModType.BUFF
	block.store_resolved_value = false
	return block

func _make_context(caster: Unit, card_value: int = 5, state: GameState = null) -> SkillContext:
	if state == null:
		state = GameState.new()
		state.hand = [Card.new(2), Card.new(7), Card.new(3)]
	var ctx: SkillContext = SkillContext.new(caster, null, state)
	ctx.card_value = card_value
	return ctx
#endregion

#region EffectBlock: CASTER_SHIELD value source
func test_caster_shield_computes_shield_value() -> void:
	var block: EffectBlock = _make_effect_block("add_bonus", "caster_shield")
	var ally: Unit = _make_ally(null, null, null, 6)
	var ctx: SkillContext = _make_context(ally, 5)
	
	var value: int = block.compute_value_from_inputs(ctx.card_value, ctx.stored_value, ctx.game_state, null, ctx.caster)
	assert_int(value).is_equal(6)  # caster.shield

func test_caster_shield_zero_shield_returns_zero() -> void:
	var block: EffectBlock = _make_effect_block("add_bonus", "caster_shield")
	var ally: Unit = _make_ally(null, null, null, 0)
	var ctx: SkillContext = _make_context(ally, 5)
	
	var value: int = block.compute_value_from_inputs(ctx.card_value, ctx.stored_value, ctx.game_state, null, ctx.caster)
	assert_int(value).is_equal(0)

func test_caster_shield_with_null_caster_returns_zero() -> void:
	var block: EffectBlock = _make_effect_block("add_bonus", "caster_shield")
	var ctx: SkillContext = _make_context(_make_ally(null, null, null, 4), 5)
	
	var value: int = block.compute_value_from_inputs(ctx.card_value, ctx.stored_value, ctx.game_state, null, null)
	assert_int(value).is_equal(0)
#endregion

#region EffectBlock: _add_bonus skips zero values
func test_add_bonus_skips_zero_value_log_spam() -> void:
	var block: EffectBlock = _make_effect_block("add_bonus", "fixed", 1, 1, 0, -1, 0)
	var ally: Unit = _make_ally(null, null, null, 0)
	var ctx: SkillContext = _make_context(ally, 5)
	var logged: Array[String] = []
	ctx.log_message = func(msg: String) -> void:
		logged.append(msg)
	
	await block.execute(ctx)
	assert_bool(logged.is_empty()).is_true()  # No "+0 bonus value" log spam
#endregion

#region GameState: get_highest_card_in_hand with exclude
func test_highest_card_excludes_dragged_card() -> void:
	var state: GameState = GameState.new()
	var high_card: Card = Card.new(10)
	var mid_card: Card = Card.new(5)
	var low_card: Card = Card.new(2)
	state.hand = [mid_card, high_card, low_card]
	
	assert_int(state.get_highest_card_in_hand().get_effective_value()).is_equal(10)
	assert_int(state.get_highest_card_in_hand(high_card).get_effective_value()).is_equal(5)
	var foreign_card: Card = Card.new(99)
	assert_int(state.get_highest_card_in_hand(foreign_card).get_effective_value()).is_equal(10)
#endregion

#region SkillPreviewFormatter: token substitution
func test_formatter_replaces_shield_token_with_clean_number() -> void:
	var catalog: TooltipIconCatalog = TooltipIconCatalog.new()
	var state: GameState = GameState.new()
	state.hand = [Card.new(3)]
	var ally: Unit = _make_ally(null, null, null, 4)
	var description: String = "Deal [Value + Shield] damage to an enemy."
	var blocks: Array[SkillEffect] = []
	
	var result: String = SkillPreviewFormatter._substitute_tokens(description, 5, state, blocks, ally, catalog, 0)
	assert_str(result).not_contains("[Value + Shield]")
	assert_str(result).contains("[color=#FFD966]9[/color]")  # 5 + 4 shield
	assert_str(result).contains("(+4 from Shield)")

func test_formatter_shield_token_teaches_the_rule_at_zero_shield() -> void:
	var catalog: TooltipIconCatalog = TooltipIconCatalog.new()
	var state: GameState = GameState.new()
	state.hand = [Card.new(3)]
	var ally: Unit = _make_ally(null, null, null, 0)
	var description: String = "Deal [Value + Shield] damage to an enemy."
	
	var result: String = SkillPreviewFormatter._substitute_tokens(description, 5, state, [], ally, catalog, 0)
	assert_str(result).contains("(+1 per Shield)")

func test_formatter_replaces_highest_card_token_with_clean_number() -> void:
	var catalog: TooltipIconCatalog = TooltipIconCatalog.new()
	var state: GameState = GameState.new()
	state.hand = [Card.new(3), Card.new(7), Card.new(2)]
	var ally: Unit = _make_ally(null, null, null, 0)
	var description: String = "Deal [Value + Highest Card in Hand / 2] damage to an enemy."
	
	var result: String = SkillPreviewFormatter._substitute_tokens(description, 4, state, [], ally, catalog, 0)
	assert_str(result).not_contains("[Value + Highest Card in Hand / 2]")
	assert_str(result).contains("[color=#FFD966]7[/color]")  # 4 + (7/2=3)
	assert_str(result).contains("(+3 from highest card)")

func test_formatter_highest_card_token_excludes_dragged_card() -> void:
	var catalog: TooltipIconCatalog = TooltipIconCatalog.new()
	var state: GameState = GameState.new()
	var dragged: Card = Card.new(10)
	state.hand = [Card.new(3), dragged, Card.new(7)]
	var ally: Unit = _make_ally(null, null, null, 0)
	var description: String = "Deal [Value + Highest Card in Hand / 2] damage to an enemy."
	
	var result: String = SkillPreviewFormatter._substitute_tokens(description, 4, state, [], ally, catalog, 0, dragged)
	assert_str(result).contains("(+3 from highest card)")   # highest non-dragged card is 7
	assert_str(result).not_contains("(+5 from highest card)")  # never counts the dragged 10

func test_formatter_replaces_div_add_token_with_clean_number() -> void:
	var catalog: TooltipIconCatalog = TooltipIconCatalog.new()
	var state: GameState = GameState.new()
	state.hand = [Card.new(5)]
	var description: String = "Give a card in hand +[Value / 2 + 1] Value."
	
	var result: String = SkillPreviewFormatter._substitute_tokens(description, 6, state, [], null, catalog, 0)
	assert_str(result).not_contains("[Value / 2 + 1]")
	assert_str(result).contains("[color=#FFD966]4[/color]")  # (6/2=3) + 1 = 4
	assert_str(result).not_contains("(")  # no algebra clutter

func test_formatter_replaces_multiply_token_with_clean_number() -> void:
	var catalog: TooltipIconCatalog = TooltipIconCatalog.new()
	var state: GameState = GameState.new()
	state.hand = [Card.new(3)]
	var description: String = "Break [Value * 2] Shield on that enemy."
	
	var result: String = SkillPreviewFormatter._substitute_tokens(description, 5, state, [], null, catalog, 0)
	assert_str(result).not_contains("[Value * 2]")
	assert_str(result).contains("[color=#FFD966]10[/color]")  # 5 * 2 = 10
	assert_str(result).not_contains("(")
#endregion

#region SkillPreviewFormatter: build_card_on_ally_data with new kits
func test_build_healer_1_shows_shield_slam_preview() -> void:
	var skill: SkillData = SkillData.new()
	skill.skill_name = "healer_1"
	skill.description = "Deal [Value + Shield] damage to an enemy."
	skill.merged_description = "Merged: Reduce its next roll by [Value / 2] (max 5)."
	skill.base_categories = ["damage"]
	skill.merged_categories = ["damage", "debuff"]
	skill.merged_mode = SkillData.MergedMode.AND_MERGED_FIRST
	skill.base_effects = [
		_make_effect_block("add_bonus", "caster_shield"),
		_make_effect_block("deal_damage", "card_value"),
	]
	skill.merged_effects = [
		_make_effect_block("apply_modifier", "card_value", 1, 2, 0, 5),
	]
	
	var state: GameState = GameState.new()
	state.hand = [Card.new(2), Card.new(5)]
	var ally: Unit = _make_ally(skill, null, null, 3)
	var card: Card = Card.new(5)
	
	var data: Dictionary = SkillPreviewFormatter.build_card_on_ally_data(ally, card, state, null)
	assert_str(data.get("body", "")).contains("(+3 from Shield)")  # 5 + 3 shield
	assert_str(data.get("body", "")).contains("Reduce its next roll")

func test_build_buff_2_shows_value_positive_preview() -> void:
	var skill: SkillData = SkillData.new()
	skill.skill_name = "buff_2"
	skill.description = "Give a card in hand +[Value / 2 + 1] Value. Your next skill this turn gains +2 Value."
	skill.merged_description = "Merged (Instead): Give 2 cards in hand +[Value / 2 + 2] Value. Your next skill this turn gains +[Value / 2 + 2] Value."
	skill.base_categories = ["buff"]
	skill.merged_categories = ["buff"]
	skill.merged_mode = SkillData.MergedMode.OR
	skill.base_effects = [
		_make_effect_block("modify_card", "card_value", 1, 2, 1),
		_make_effect_block("set_next_skill_bonus", "fixed", 1, 1, 0, -1, 2),
	]
	skill.merged_effects = [
		_make_effect_block("modify_card", "card_value", 1, 2, 2, -1, 0, 2),
		_make_effect_block("set_next_skill_bonus", "card_value", 1, 2, 2),
	]
	
	var state: GameState = GameState.new()
	state.hand = [Card.new(2), Card.new(4)]
	var ally: Unit = _make_ally(null, skill, null, 0)
	var card: Card = Card.new(4)
	
	var data: Dictionary = SkillPreviewFormatter.build_card_on_ally_data(ally, card, state, null)
	assert_str(data.get("body", "")).contains("[color=#FFD966]3[/color]")  # (4/2)+1 = 3
	assert_str(data.get("body", "")).contains("Your next skill this turn gains +2 Value.")

func test_build_striker_2_shows_shield_category() -> void:
	var skill: SkillData = SkillData.new()
	skill.skill_name = "striker_2"
	skill.description = "Deal [Value - 1] damage to 2 enemies. Gain 2 Shield."
	skill.merged_description = "Merged (Instead): Deal [Value - 2] damage to all enemies. Gain 4 Shield."
	skill.base_categories = ["damage", "shield"]
	skill.merged_categories = ["damage", "shield"]
	skill.merged_mode = SkillData.MergedMode.OR
	skill.base_effects = [
		_make_effect_block("deal_damage", "card_value", 1, 1, -1),
		_make_effect_block("gain_shield", "fixed", 1, 1, 0, -1, 2),
	]
	skill.merged_effects = [
		_make_effect_block("deal_damage", "card_value", 1, 1, -2),
		_make_effect_block("gain_shield", "fixed", 1, 1, 0, -1, 4),
	]
	
	var state: GameState = GameState.new()
	state.hand = [Card.new(3)]
	var ally: Unit = _make_ally(null, skill, null, 0)
	var card: Card = Card.new(4)
	
	var data: Dictionary = SkillPreviewFormatter.build_card_on_ally_data(ally, card, state, null)
	assert_array(data.get("categories", [])).contains(["damage", "shield"])
#endregion
#endregion