class_name EnemySkillBalanceTest
extends GdUnitTestSuite
## Locks the enemy-skill balance pass:
##   - an enemy threshold matches the parity of the slot it sits in (an Odd skill
##     can never be gated on an even number like 6, which it can never roll)
##   - the dice curve stays smooth so no single roll runs away
##   - a shielded ally always survives one max single-target hit (the counterplay)
##   - every enemy skill tooltip resolves with no raw [Value ...] tokens left
##   - a caster that dies mid-skill stops the remaining effects (no zombie attack)
##
## @author TheGreatJellyfish
## @version 11/25/2026

#region Helpers
func _db() -> GameDatabase:
	return DataLoader.load_database()

func _make_ally(shield: int = 0) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = "Test Ally"
	data.max_hp = 20
	data.max_moxie = 20
	data.skill_1 = SkillData.new()
	data.skill_2 = SkillData.new()
	data.ultimate = SkillData.new()
	var unit: Unit = Unit.new(data)
	unit.shield = shield
	return unit

func _make_enemy(max_hp: int = 20) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = "Test Enemy"
	data.max_hp = max_hp
	data.max_moxie = 20
	data.is_enemy = true
	data.skill_1 = SkillData.new()
	data.skill_2 = SkillData.new()
	data.ultimate = SkillData.new()
	return Unit.new(data)

## JSON numbers arrive as Variant; coerce to int without tripping strict typing.
static func _as_int(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return int(str(value))
## Removes the BBCode tags the formatter emits, so a stray token bracket like the
## leftover "[13 ...]" from a mis-consumed [N + Highest Card] shows up in a check.
static func _strip_bbcode(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[/?(?:color|font_size|b|i)(?:=[^\\]]*)?\\]")
	return rx.sub(text, "", true)

#endregion

#region Threshold parity
func test_enemy_thresholds_match_their_slot_parity() -> void:
	var db: GameDatabase = _db()
	for unit_id: String in db.enemies.keys():
		var unit: UnitData = db.enemies[unit_id]
		if unit.skill_1 != null and unit.skill_1.condition_threshold > 0:
			assert_int(unit.skill_1.condition_threshold % 2).is_equal(1)
		if unit.skill_2 != null and unit.skill_2.condition_threshold > 0:
			assert_int(unit.skill_2.condition_threshold % 2).is_equal(0)

func test_normal_enemy_odd_gate_is_reachable_on_turn_one() -> void:
	var db: GameDatabase = _db()
	var first_die: int = _as_int(db.config.get("dice_progression", [6])[0])
	var unit: UnitData = db.enemies["normal_enemy"]
	# An Odd skill gated at 5 fires on a d6; a gate of 6 would be impossible.
	assert_int(unit.skill_1.condition_threshold).is_equal(5)
	assert_bool(unit.skill_1.condition_threshold <= first_die).is_true()
#endregion

#region Dice curve & survivability
func test_dice_progression_is_smooth() -> void:
	var db: GameDatabase = _db()
	var progression: Array = db.config.get("dice_progression", [])
	assert_array(progression).is_not_empty()
	var previous: int = 0
	for value: Variant in progression:
		var sides: int = _as_int(value)
		assert_int(sides).is_less_equal(12)
		if previous > 0:
			assert_int(sides - previous).is_less_equal(2)  # no runaway +4 jumps
		previous = sides

## The weakest ally must survive one maximum single-target hit *while shielded*.
## Being unshielded is the risk the player is expected to answer with Shield.
func test_shielded_ally_survives_one_max_single_target_hit() -> void:
	var db: GameDatabase = _db()
	var progression: Array = db.config.get("dice_progression", [])
	var top_die: int = _as_int(progression[progression.size() - 1])
	var max_odd: int = top_die if top_die % 2 == 1 else top_die - 1
	var weakest_hp: int = 9999
	for ally_id: String in db.allies.keys():
		var ally: UnitData = db.allies[ally_id]
		weakest_hp = mini(weakest_hp, ally.max_hp)
	# boss_enemy_1 deals [Value + 2]; the +3 unshielded bonus is skipped when shielded.
	var shielded_worst: int = max_odd + 2
	assert_int(shielded_worst).is_less(weakest_hp)

## The AoE boss skill halves the roll, so it can never wipe a full-HP team either.
func test_boss_aoe_hit_stays_below_weakest_ally_hp() -> void:
	var db: GameDatabase = _db()
	var progression: Array = db.config.get("dice_progression", [])
	var top_die: int = _as_int(progression[progression.size() - 1])
	var max_even: int = top_die if top_die % 2 == 0 else top_die - 1
	var weakest_hp: int = 9999
	for ally_id: String in db.allies.keys():
		var ally: UnitData = db.allies[ally_id]
		weakest_hp = mini(weakest_hp, ally.max_hp)
	var aoe_worst: int = (max_even / 2) + 2  # [Value / 2 + 2]
	assert_int(aoe_worst).is_less(weakest_hp)
#endregion

#region Tooltip resolution
## Every enemy (and ally) description must resolve to plain prose: no raw
## [Value ...] / [.. Shield] tokens may survive the formatter.
func test_all_skill_tooltips_resolve_without_raw_tokens() -> void:
	var db: GameDatabase = _db()
	var state: GameState = GameState.new()
	state.hand = [Card.new(5), Card.new(3), Card.new(2)]
	var caster: Unit = _make_ally(4)
	for skill_id: String in db.skills.keys():
		var skill: SkillData = db.skills[skill_id]
		for text: String in [skill.description, skill.merged_description]:
			if text.strip_edges() == "":
				continue
			var resolved: String = SkillPreviewFormatter._substitute_tokens(
				text, 6, state, [], caster, null, 0
			)
			assert_str(resolved).not_contains("[Value")
			assert_str(resolved).not_contains("Highest Card in Hand]")
			assert_str(resolved).not_contains("Shield]")
			assert_str(resolved).not_contains("Caster's Shield")
#endregion

#region Dead-caster guard
func test_dead_caster_stops_remaining_effects() -> void:
	var caster: Unit = _make_ally(0)
	caster.current_hp = 0
	var target: Unit = _make_enemy(20)
	var state: GameState = GameState.new()
	state.enemies = [target]
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_DAMAGE
	block.target_mode = EffectBlock.TargetMode.PICK_N_ENEMY
	block.target_count = 1
	block.value_source = EffectBlock.ValueSource.CARD_VALUE
	var ctx: SkillContext = SkillContext.new(caster, null, state)
	ctx.card_value = 5
	await block.execute(ctx)
	assert_int(target.current_hp).is_equal(20)  # never fired; caster was dead

func test_living_caster_still_fires_effects() -> void:
	var caster: Unit = _make_ally(0)
	var target: Unit = _make_enemy(20)
	var state: GameState = GameState.new()
	state.enemies = [target]
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_DAMAGE
	block.target_mode = EffectBlock.TargetMode.PICK_N_ENEMY
	block.target_count = 1
	block.value_source = EffectBlock.ValueSource.CARD_VALUE
	var ctx: SkillContext = SkillContext.new(caster, null, state)
	ctx.card_value = 5
	ctx.pick_n_target = func(_count: int, _filter: Callable) -> Array[Unit]:
		var arr: Array[Unit] = [target]
		return arr
	await block.execute(ctx)
	assert_int(target.current_hp).is_equal(15)  # 20 - 5
#endregion

#region Target-cache preservation
## Reproduces the merged healer_1 / buff_1 order: pick an enemy, run a utility
## block (target_mode none), then deal cached damage. The utility block must not
## erase the cached target, or the damage block would prompt a SECOND time.
func test_utility_block_preserves_cached_targets() -> void:
	var caster: Unit = _make_ally(3)
	var enemy: Unit = _make_enemy(30)
	var state: GameState = GameState.new()
	state.enemies = [enemy]
	var picks: Array[int] = [0]
	var ctx: SkillContext = SkillContext.new(caster, null, state)
	ctx.card_value = 5
	ctx.pick_n_target = func(_count: int, _filter: Callable) -> Array[Unit]:
		picks[0] += 1
		var arr: Array[Unit] = [enemy]
		return arr

	# merged block: pick + reduce the enemy's roll (caches the target)
	var mod: EffectBlock = EffectBlock.new()
	mod.action_type = EffectBlock.Action.APPLY_MODIFIER
	mod.target_mode = EffectBlock.TargetMode.PICK_N_ENEMY
	mod.target_count = 1
	mod.value_source = EffectBlock.ValueSource.CARD_VALUE
	mod.value_divisor = 2
	mod.value_cap = 5
	await mod.execute(ctx)

	# base utility block: must NOT wipe ctx.targets
	var bonus: EffectBlock = EffectBlock.new()
	bonus.action_type = EffectBlock.Action.ADD_BONUS
	bonus.target_mode = EffectBlock.TargetMode.NONE
	bonus.value_source = EffectBlock.ValueSource.FIXED
	bonus.fixed_amount = 0
	await bonus.execute(ctx)

	# base damage block: must reuse the cached target (no second prompt)
	var strike: EffectBlock = EffectBlock.new()
	strike.action_type = EffectBlock.Action.DEAL_DAMAGE
	strike.target_mode = EffectBlock.TargetMode.CACHED_OR_PICK_ENEMY
	strike.target_count = 1
	strike.value_source = EffectBlock.ValueSource.CARD_VALUE
	await strike.execute(ctx)

	assert_int(picks[0]).is_equal(1)  # exactly one target prompt
	assert_int(enemy.current_hp).is_equal(25)  # 30 - 5

## The add_bonus fix-up must still reach the damage block when it adds value.
func test_bonus_before_cached_damage_still_applies() -> void:
	var caster: Unit = _make_ally(0)
	var enemy: Unit = _make_enemy(30)
	var state: GameState = GameState.new()
	state.enemies = [enemy]
	var ctx: SkillContext = SkillContext.new(caster, null, state)
	ctx.card_value = 5
	ctx.pick_n_target = func(_count: int, _filter: Callable) -> Array[Unit]:
		var arr: Array[Unit] = [enemy]
		return arr
	var bonus: EffectBlock = EffectBlock.new()
	bonus.action_type = EffectBlock.Action.ADD_BONUS
	bonus.target_mode = EffectBlock.TargetMode.NONE
	bonus.value_source = EffectBlock.ValueSource.FIXED
	bonus.fixed_amount = 3
	await bonus.execute(ctx)
	var strike: EffectBlock = EffectBlock.new()
	strike.action_type = EffectBlock.Action.DEAL_DAMAGE
	strike.target_mode = EffectBlock.TargetMode.CACHED_OR_PICK_ENEMY
	strike.target_count = 1
	strike.value_source = EffectBlock.ValueSource.CARD_VALUE
	await strike.execute(ctx)
	assert_int(enemy.current_hp).is_equal(22)  # 30 - (5 + 3)
#endregion

#region No stray brackets
## After substitution every description must be plain prose once the BBCode is
## stripped: a leftover token like "[13 (+5 from your highest card in hand)]" fails here.
func test_no_stray_brackets_after_substitution() -> void:
	var db: GameDatabase = _db()
	var state: GameState = GameState.new()
	state.hand = [Card.new(5), Card.new(3), Card.new(2)]
	var caster: Unit = _make_ally(4)
	for skill_id: String in db.skills.keys():
		var skill: SkillData = db.skills[skill_id]
		for text: String in [skill.description, skill.merged_description]:
			if text.strip_edges() == "":
				continue
			var resolved: String = SkillPreviewFormatter._substitute_tokens(
				text, 6, state, [], caster, null, 0
			)
			var plain: String = _strip_bbcode(resolved)
			assert_str(plain).not_contains("[")
			assert_str(plain).not_contains("]")
#endregion