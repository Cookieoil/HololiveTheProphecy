class_name EffectBlockMessageTest
extends GdUnitTestSuite
## Locks the colours of the battle-log lines EffectBlock writes. Every number in a
## message wears the colour of the stat it belongs to, and those colours belong to
## ColorUtils - chosen in one file instead of copied into each message:
##   - HP numbers (damage, HP lost, remaining HP, healed, total HP) in the HP orange
##   - Shield numbers in the shield blue, the running total included
##   - the unit a line is about in its own side's colour
##
## @author TheGreatJellyfish
## @version 11/27/2026

## The tags the messages must carry, pinned as literals on purpose: moving a battle-log
## colour is a deliberate act, and this is the check that notices it.
const HP_TAG: String = "[color=#FFA500]"     # ColorUtils.COLOR_HP
const SHIELD_TAG: String = "[color=#00BFFF]" # ColorUtils.COLOR_SHIELD
const ENEMY_TAG: String = "[color=#FF4444]"  # ColorUtils.COLOR_ENEMY
const CLOSE_TAG: String = "[/color]"


#region Helpers
func _make_unit(display_name: String, is_enemy: bool) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = display_name
	data.max_hp = 20
	data.max_moxie = 20
	data.is_enemy = is_enemy
	return Unit.new(data)


## A block aimed at the units already cached on the context, so one effect can be driven
## at one target without a target prompt or a card.
func _make_block(action: String, value: int) -> EffectBlock:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = DataLoader.ACTION_MAP[action]
	block.value_source = DataLoader.VALUE_SOURCE_MAP["fixed"]
	block.fixed_amount = value
	block.target_mode = EffectBlock.TargetMode.CACHED
	return block


func _make_context(caster: Unit, target: Unit) -> SkillContext:
	var ctx: SkillContext = SkillContext.new(caster, null, GameState.new())
	var targets: Array[Unit] = [target]
	ctx.targets = targets
	return ctx


## Runs one effect and returns the log lines it wrote.
func _run(block: EffectBlock, ctx: SkillContext) -> Array[String]:
	var logged: Array[String] = []
	ctx.log_message = func(message: String) -> void:
		logged.append(message)
	await block.execute(ctx)
	return logged
#endregion


#region The palette the messages are built from
func test_the_pinned_tags_are_the_colour_utils_palette() -> void:
	assert_str(ColorUtils.colorize("x", ColorUtils.COLOR_HP)).is_equal(HP_TAG + "x" + CLOSE_TAG)
	assert_str(ColorUtils.colorize("x", ColorUtils.COLOR_SHIELD)).is_equal(SHIELD_TAG + "x" + CLOSE_TAG)
	assert_str(ColorUtils.colorize("x", ColorUtils.COLOR_ENEMY)).is_equal(ENEMY_TAG + "x" + CLOSE_TAG)
#endregion


#region Damage
func test_damage_line_colours_every_hp_number_and_the_unit_it_hit() -> void:
	var ally: Unit = _make_unit("Test Ally", false)
	var enemy: Unit = _make_unit("Test Enemy", true)
	var ctx: SkillContext = _make_context(ally, enemy)

	var logged: Array[String] = await _run(_make_block("deal_damage", 5), ctx)

	assert_int(logged.size()).is_equal(1)
	var line: String = logged[0]
	assert_str(line).contains("deals " + HP_TAG + "5" + CLOSE_TAG + " damage")
	assert_str(line).contains("(HP lost: " + HP_TAG + "5" + CLOSE_TAG + ")")
	assert_str(line).contains("→ HP: " + HP_TAG + "15" + CLOSE_TAG)
	assert_str(line).contains(ENEMY_TAG + "Test Enemy" + CLOSE_TAG)


func test_absorbed_damage_still_names_the_attempted_number_in_hp_colour() -> void:
	var ally: Unit = _make_unit("Test Ally", false)
	var enemy: Unit = _make_unit("Test Enemy", true)
	enemy.shield = 3
	var ctx: SkillContext = _make_context(ally, enemy)

	var logged: Array[String] = await _run(_make_block("deal_damage", 5), ctx)

	var line: String = logged[0]
	assert_str(line).contains("(HP lost: " + HP_TAG + "2" + CLOSE_TAG + ")")
	assert_str(line).contains("[Attempted: " + HP_TAG + "5" + CLOSE_TAG + "]")
#endregion


#region Shield and heal
func test_shield_gain_colours_the_gained_and_the_total_in_shield_colour() -> void:
	var ally: Unit = _make_unit("Test Ally", false)
	var ctx: SkillContext = _make_context(ally, ally)

	var logged: Array[String] = await _run(_make_block("gain_shield", 4), ctx)

	assert_int(logged.size()).is_equal(1)
	var line: String = logged[0]
	assert_str(line).contains("gains " + SHIELD_TAG + "4" + CLOSE_TAG + " Shield")
	assert_str(line).contains("(Total: " + SHIELD_TAG + "4 V" + CLOSE_TAG + ")")


func test_heal_line_colours_the_restored_and_the_total_in_hp_colour() -> void:
	var ally: Unit = _make_unit("Test Ally", false)
	ally.take_damage(5)
	var ctx: SkillContext = _make_context(ally, ally)

	var logged: Array[String] = await _run(_make_block("heal", 3), ctx)

	assert_int(logged.size()).is_equal(1)
	var line: String = logged[0]
	assert_str(line).contains(" for " + HP_TAG + "3" + CLOSE_TAG + " (Total: " + HP_TAG + "18 HP" + CLOSE_TAG + ")")
#endregion
