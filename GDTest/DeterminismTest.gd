class_name DeterminismTest
extends GdUnitTestSuite
## Locks the property the whole telemetry story rests on: a battle is reproducible from
## its run seed. If it is not, "replay this seed to see the bug" is a lie, and every
## balance number describes a game nobody can reproduce.
##
## Three kinds of check:
##
## - a scripted battle run twice must produce the same trace, and a plan recorded from
##   one run must replay against a fresh board. The seed alone is not enough: a path that
##   reached for the global RNG would drift while the seed stayed the same;
## - a sweep over many seeds asserting the board's invariants at every decision, so a
##   state-corrupting path fails loudly instead of quietly changing an outcome;
## - a source audit, so a new global-RNG call cannot creep in unnoticed.
##
## The harness lives in Tools/BattleSimulator.gd, shared with Tools/simulate_runs.tscn, so
## the seed replayed here is the seed that tool replays.
##
## @author TheGreatJellyfish
## @version 11/28/2026


#region Constants
## The seed every determinism check starts from.
const SEED: int = 20260101
## How many seeds the invariant sweep covers.
const SWEEP_SEEDS: int = 24
## How many seeds the shipped-battle sweep covers: fewer, because these are real battles
## with real skills rather than a two-card fixture.
const SHIPPED_SEEDS: int = 12
## Shipped scripts that may draw from the global RNG, and why. A *seeded* member call
## (`generator.randi_range(...)`) is not one of these: the audit looks for bare calls, so
## the run generator seeding itself needs no entry.
const GLOBAL_RNG_ALLOWED: Dictionary = {
	"Scenes/BattleUnit/UnitUI.gd": "the shield-shatter shard scatter, which is view state only",
}
## A *bare* global-RNG call (not `rng.randi_range(...)`) or a built-in shuffle.
const GLOBAL_RNG_PATTERN: String = "(?<![.\\w])(randi_range|randf_range|randi|randf|randomize)\\s*\\(|Array\\.shuffle|\\.shuffle\\("
## Directories whose scripts never ship, so their randomness cannot affect a replay.
const NON_SHIPPED_DIRS: PackedStringArray = [
	"res://GDTest", "res://Tools", "res://addons", "res://reports", "res://Trash",
	"res://bin", "res://.godot",
]
#endregion


#region Helpers
func _damage_skill(skill_id: String, target_mode: int, amount: int) -> SkillData:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_DAMAGE
	block.target_mode = target_mode
	block.value_source = EffectBlock.ValueSource.FIXED
	block.fixed_amount = amount
	block.condition = EffectBlock.Condition.NONE
	var effects: Array[SkillEffect] = [block]
	var skill: SkillData = SkillData.new()
	skill.skill_id = skill_id
	skill.skill_name = skill_id
	skill.base_effects = effects
	return skill


func _ally_data(unit_id: String) -> UnitData:
	var data: UnitData = UnitData.new()
	data.unit_id = unit_id
	data.display_name = unit_id
	# Deep enough to survive both waves, so a swept run exercises the win path rather
	# than ending in a wipe a few turns in.
	data.max_hp = 60
	data.max_moxie = 20
	data.skill_1 = _damage_skill("%s_1" % unit_id, EffectBlock.TargetMode.ALL_ENEMIES, 4)
	data.skill_2 = _damage_skill("%s_2" % unit_id, EffectBlock.TargetMode.ALL_ENEMIES, 4)
	data.ultimate = _damage_skill("%s_ult" % unit_id, EffectBlock.TargetMode.ALL_ENEMIES, 8)
	return data


func _enemy_data(unit_id: String, max_hp: int) -> UnitData:
	var data: UnitData = UnitData.new()
	data.unit_id = unit_id
	data.display_name = unit_id
	data.is_enemy = true
	data.max_hp = max_hp
	data.max_moxie = 20
	# From an enemy caster ALL_ENEMIES resolves to the player's allies, so these are the
	# enemy's attacks. The two skills deliberately differ: the enemy picks one by rolling
	# its intent die, so a roll that stopped coming from the run seed would show up as a
	# different board rather than as the same board reached a different way.
	data.skill_1 = _damage_skill("%s_1" % unit_id, EffectBlock.TargetMode.ALL_ENEMIES, 4)
	data.skill_2 = _damage_skill("%s_2" % unit_id, EffectBlock.TargetMode.ALL_ENEMIES, 9)
	data.ultimate = _damage_skill("%s_ult" % unit_id, EffectBlock.TargetMode.ALL_ENEMIES, 4)
	return data


func _waves() -> Array:
	var first: Array[UnitData] = [_enemy_data("wave0_enemy", 40)]
	var second: Array[UnitData] = [_enemy_data("wave1_boss", 55)]
	var waves: Array = [first, second]
	return waves


func _config(seed_value: int) -> Dictionary:
	return {
		"hand_size": 7,
		"actions_per_turn": 3,
		"merges_per_turn": 2,
		"decklist": [[3, 8], [5, 7]],
		"dice_progression": [6, 8, 10, 12],
		"wave_transition_mode": "full_turn",
		"seed": seed_value,
	}


## A simulator already in the tree, so its GameManager and recorder are ready.
func _simulator() -> BattleSimulator:
	var sim: BattleSimulator = BattleSimulator.new()
	add_child(sim)
	auto_free(sim)
	return sim


## Runs one seeded battle to the end. `plan` replays a recorded run instead of playing
## the policy, which is what makes the replay check possible.
func _run(seed_value: int, sim: BattleSimulator, plan: Array = []) -> void:
	var allies: Array[UnitData] = [_ally_data("striker"), _ally_data("healer")]
	await sim.run(allies, _waves(), _config(seed_value), plan)


## Runs `count` battles from `seed_value` and returns every invariant break found,
## prefixed with the seed that produced it. `shipped` runs the real battle from Data/json
## instead of the fixture.
func _sweep_seeds(seed_value: int, count: int, shipped: bool) -> PackedStringArray:
	var broken: PackedStringArray = PackedStringArray()
	for offset: int in count:
		var run_seed: int = seed_value + offset
		var sim: BattleSimulator = _simulator()
		if shipped:
			await sim.run_shipped(run_seed)
		else:
			await _run(run_seed, sim)
		if not sim.recorder.violation.is_empty():
			broken.append("seed %d: %s" % [run_seed, sim.recorder.violation])
		if not sim.recorder.card_leak.is_empty():
			broken.append("seed %d: %s" % [run_seed, sim.recorder.card_leak])
		if sim.manager.game_running:
			broken.append("seed %d never finished" % run_seed)
		if sim.recorder.trace.is_empty():
			broken.append("seed %d produced no decisions" % run_seed)
	return broken


## Every first-party script that ships, so the RNG audit covers the game and not the
## tooling around it.
func _shipped_scripts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_collect_scripts("res://", found)
	return found


func _collect_scripts(dir_path: String, found: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	for sub_name: String in dir.get_directories():
		var child: String = dir_path.path_join(sub_name)
		if NON_SHIPPED_DIRS.has(child):
			continue
		_collect_scripts(child, found)


func _rng_calls(rel: String, path: String) -> PackedStringArray:
	var offenders: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.create_from_string(GLOBAL_RNG_PATTERN)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		if line.strip_edges().begins_with("#"):
			continue
		if regex.search(line) != null:
			offenders.append("%s:%d: %s" % [rel, index + 1, line.strip_edges()])
	return offenders
#endregion


#region The same seed, the same battle
## The core promise: the same seed and the same decisions produce the same battle. Both
## runs are fingerprinted at every decision, so a divergence is caught at the step it
## happens rather than only at the end.
func test_the_same_seed_replays_the_same_battle() -> void:
	var first: BattleSimulator = _simulator()
	await _run(SEED, first)
	var second: BattleSimulator = _simulator()
	await _run(SEED, second)

	assert_int(first.recorder.decisions.size()).is_greater(0)
	assert_str("|".join(first.recorder.trace)).is_equal("|".join(second.recorder.trace))
	assert_array(first.recorder.decisions).is_equal(second.recorder.decisions)
	assert_bool(first.manager.game_running).is_false()
	assert_bool(second.manager.game_running).is_false()
	assert_str(BattleSimulator.Recorder.fingerprint(first.manager.state)).is_equal(
		BattleSimulator.Recorder.fingerprint(second.manager.state)
	)


## Guards against the failure mode where the test above passes because nothing in the
## battle is random at all.
func test_a_different_seed_deals_a_different_battle() -> void:
	var distinct: Dictionary = {}
	for offset: int in 4:
		var sim: BattleSimulator = _simulator()
		await _run(SEED + offset, sim)
		distinct["|".join(sim.recorder.trace)] = true

	assert_int(distinct.size()).is_greater(1)


## The seed alone is not enough: if any path reached for the global RNG, the decisions
## recorded from one run would not fit a fresh board. Replaying them is what proves the
## run really is a function of the seed.
func test_a_recorded_plan_replays_against_a_fresh_board() -> void:
	var recorded: BattleSimulator = _simulator()
	await _run(SEED, recorded)

	var replayed: BattleSimulator = _simulator()
	await _run(SEED, replayed, recorded.recorder.decisions)

	assert_int(recorded.recorder.decisions.size()).is_greater(0)
	assert_bool(replayed.recorder.diverged).is_false()
	assert_str("|".join(replayed.recorder.trace)).is_equal("|".join(recorded.recorder.trace))
	# It replayed the plan rather than falling back to the policy.
	assert_array(replayed.recorder.decisions).is_empty()
#endregion


#region Invariants under a sweep
## A sweep rather than a single battle, because an invariant that only breaks on one
## deck order is exactly the bug a single scripted run would miss.
func test_the_board_holds_its_invariants_across_many_seeds() -> void:
	var broken: PackedStringArray = await _sweep_seeds(SEED, SWEEP_SEEDS, false)

	assert_str("\n".join(broken)).is_equal("")


## The same invariants against the battle the game actually ships, not just the fixture:
## real skills draw cards, buff values and pick targets in ways a two-card deck never
## does. This sweep is what showed `max_hand_size` to be a draw *target* rather than a cap
## (a "Draw 2 cards" skill legitimately ends a turn holding nine), which is why the hand's
## size is not asserted anywhere.
func test_the_shipped_battle_holds_its_invariants_across_seeds() -> void:
	var broken: PackedStringArray = await _sweep_seeds(SEED, SHIPPED_SEEDS, true)

	assert_str("\n".join(broken)).is_equal("")




## The sweep is only meaningful if the runs are real: a battle that ended on turn one
## would satisfy every invariant above by never reaching the interesting states.
func test_a_swept_battle_is_a_real_battle() -> void:
	var sim: BattleSimulator = _simulator()
	await _run(SEED, sim)

	assert_bool(sim.manager.state.all_allies_dead()).is_false()
	assert_int(sim.manager.state.turn_number).is_greater(2)
	assert_int(sim.recorder.trace.size()).is_greater(8)
	assert_str(BattleSimulator.Recorder.invariant_break(sim.manager.state)).is_equal("")
#endregion


#region The generator itself
func test_a_roll_is_reproducible_from_its_generator() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = SEED
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	second.seed = SEED
	var first_rolls: PackedStringArray = PackedStringArray()
	var second_rolls: PackedStringArray = PackedStringArray()
	for _roll: int in 20:
		first_rolls.append(str(DiceRoller.roll(6, first)))
		second_rolls.append(str(DiceRoller.roll(6, second)))

	assert_str("|".join(first_rolls)).is_equal("|".join(second_rolls))
	# And the die is actually a die: every roll lands inside its range.
	for roll_text: String in first_rolls:
		assert_int(roll_text.to_int()).is_between(1, 6)
	# A one-sided die is still a die, not a zero.
	assert_int(DiceRoller.roll(0, first)).is_equal(1)
#endregion



#region The audit
## The check that keeps this file honest over time: a new global-RNG call in shipped code
## would break replays without failing any other test, so it fails this one instead.
func test_no_shipped_script_reaches_for_the_global_rng() -> void:
	var offenders: PackedStringArray = PackedStringArray()
	var scripts: PackedStringArray = _shipped_scripts()
	for path: String in scripts:
		var rel: String = path.trim_prefix("res://")
		if GLOBAL_RNG_ALLOWED.has(rel):
			continue
		offenders.append_array(_rng_calls(rel, path))

	# A walk that found nothing would make the audit vacuous, so it is asserted first.
	assert_int(scripts.size()).is_greater(20)
	assert_str("\n".join(offenders)).is_equal("")


## The allowlist is a decision, so it is checked rather than trusted: every entry must
## name a script that exists and really does use the global RNG. A stale entry would
## silently exempt a file again if it were ever reintroduced.
func test_every_rng_allowlist_entry_is_still_needed() -> void:
	var stale: PackedStringArray = PackedStringArray()
	for rel: String in GLOBAL_RNG_ALLOWED:
		var path: String = "res://" + rel
		if not FileAccess.file_exists(path):
			stale.append("%s: no such script" % rel)
			continue
		if _rng_calls(rel, path).is_empty():
			stale.append("%s: no global RNG call left, drop the entry" % rel)

	assert_str("\n".join(stale)).is_equal("")
#endregion

