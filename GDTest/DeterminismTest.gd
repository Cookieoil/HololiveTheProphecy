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
## @author TheGreatJellyfish
## @version 11/28/2026


## A GameUI that plays a policy and records it, or replays a recorded plan.
##
## Decisions are recorded as *positions* (hand index, ally index) rather than object
## references, so they can be replayed against a fresh board: the same seed deals the
## same hand and the same units, so index 2 is the same card in both runs. It observes
## the board before every decision, which is the only hook the turn loop offers.
class ScriptedUI extends GameUI:
	## The plan to replay. Empty means "play the built-in policy and record what you did".
	var plan: Array = []
	var cursor: int = 0
	## Every decision this run made, in order, as positions.
	var decisions: Array = []
	## One board fingerprint per observation, so two runs can be compared step by step.
	var trace: PackedStringArray = PackedStringArray()
	## The first broken invariant, or "" when the board stayed healthy all run.
	var violation: String = ""
	## True when the plan ran out early or a recorded decision no longer fits the board:
	## both mean the replay diverged from the run it came from.
	var diverged: bool = false
	## The base cards in play at the first observation, so the run can be checked for
	## conserving them.
	var starting_cards: int = -1
	## The first card-conservation break, or "".
	var card_leak: String = ""

	func show_message(_msg: String) -> void:
		pass

	func show_game_state(_state: GameState) -> void:
		pass

	func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
		pass

	func show_hand_and_resources(_state: GameState) -> void:
		pass

	func play_unit_skill(_unit: Unit, _skill_index: int, _rank: int = 0, _lead: float = 1.0) -> void:
		pass

	func play_unit_ultimate(_unit: Unit) -> void:
		pass

	func show_battle_result(_victory: bool) -> void:
		pass

	func clear_unit_intent(_unit: Unit) -> void:
		pass

	## Deterministic prompt answers: the first N candidates, in board order.
	func ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]:
		var picked: Array[Unit] = []
		for unit: Unit in units:
			if picked.size() >= count:
				break
			picked.append(unit)
		return picked

	func ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]:
		var picked: Array[Card] = []
		for card: Card in cards:
			if picked.size() >= count:
				break
			picked.append(card)
		return picked

	func get_player_action(state: GameState) -> Dictionary:
		_observe(state)
		if not plan.is_empty():
			return _replay(state)
		var decision: Dictionary = _choose(state)
		decisions.append(decision)
		return _resolve(state, decision)


	## Records the board and checks its invariants. Every decision passes through here,
	## which is the only observation point the turn loop offers.
	func _observe(state: GameState) -> void:
		trace.append(fingerprint(state))
		if violation.is_empty():
			violation = invariant_break(state)
		var held: int = base_card_count(state)
		if starting_cards < 0:
			starting_cards = held
		elif card_leak.is_empty() and held != starting_cards:
			card_leak = "turn %d holds %d base card(s), started with %d" % [
				state.turn_number, held, starting_cards
			]


	## The policy: an Ultimate if one is ready, then a merge, then a play, then end the
	## turn. Always legal, so a battle always terminates.
	func _choose(state: GameState) -> Dictionary:
		for index: int in state.allies.size():
			if state.allies[index].can_cast_ultimate:
				return {"kind": "ultimate", "ally": index}
		if state.merges_left > 0:
			var pair: Array = _first_legal_merge(state)
			if not pair.is_empty():
				return {"kind": "merge", "a": pair[0], "b": pair[1]}
		if state.actions_left > 0 and not state.hand.is_empty():
			var ally: int = _first_living_ally(state)
			if ally >= 0:
				return {"kind": "play", "card": 0, "ally": ally}
		return {"kind": "end_turn"}


	## The first mergeable pair in hand, or [] when there is none.
	func _first_legal_merge(state: GameState) -> Array:
		for i: int in state.hand.size():
			for j: int in range(i + 1, state.hand.size()):
				if state.can_merge_pair(state.hand[i], state.hand[j]):
					return [i, j]
		return []


	func _first_living_ally(state: GameState) -> int:
		for index: int in state.allies.size():
			if not state.allies[index].is_dead:
				return index
		return -1


	## Plays one recorded decision against the current board.
	func _replay(state: GameState) -> Dictionary:
		if cursor >= plan.size():
			diverged = true
			return {"type": "end_turn"}
		var decision: Dictionary = plan[cursor]
		cursor += 1
		if not _fits(state, decision):
			diverged = true
			return {"type": "end_turn"}
		return _resolve(state, decision)


	## True when a recorded decision still names something on this board.
	func _fits(state: GameState, decision: Dictionary) -> bool:
		match str(decision.get("kind", "")):
			"play":
				return _index_fits(decision, "card", state.hand.size()) \
					and _index_fits(decision, "ally", state.allies.size())
			"merge":
				return _index_fits(decision, "a", state.hand.size()) \
					and _index_fits(decision, "b", state.hand.size())
			"ultimate":
				return _index_fits(decision, "ally", state.allies.size())
			_:
				return true


	static func _index_fits(decision: Dictionary, key: String, size: int) -> bool:
		var index: int = decision_int(decision, key, -1)
		return index >= 0 and index < size


	## Turns a decision into the action Dictionary the turn loop expects.
	func _resolve(state: GameState, decision: Dictionary) -> Dictionary:
		match str(decision.get("kind", "")):
			"play":
				return {
					"type": "play",
					"card": state.hand[decision_int(decision, "card", 0)],
					"target_ally": state.allies[decision_int(decision, "ally", 0)],
				}
			"merge":
				return {
					"type": "merge",
					"card_a": state.hand[decision_int(decision, "a", 0)],
					"card_b": state.hand[decision_int(decision, "b", 1)],
				}
			"ultimate":
				return {"type": "ultimate", "caster": state.allies[decision_int(decision, "ally", 0)]}
			_:
				return {"type": "end_turn"}


	## A stable text digest of everything a replay has to reproduce. Card identity is
	## (value, merge tier) rather than the instance id, so the digest describes the game
	## rather than the order the objects happened to be allocated in.
	static func fingerprint(state: GameState) -> String:
		var parts: PackedStringArray = PackedStringArray()
		parts.append("t%d/w%d/a%d/m%d" % [
			state.turn_number, state.current_wave, state.actions_left, state.merges_left
		])
		parts.append("deck%d/disc%d/played%d" % [
			state.deck.size(), state.discard.size(), state.played_this_turn.size()
		])
		for unit: Unit in state.allies:
			parts.append("A%s:%d/%d:s%d:m%d" % [
				unit.data.unit_id, unit.current_hp, unit.max_hp, unit.shield, unit.moxie
			])
		for unit: Unit in state.enemies:
			parts.append("E%s:%d/%d:s%d:m%d" % [
				unit.data.unit_id, unit.current_hp, unit.max_hp, unit.shield, unit.moxie
			])
		for card: Card in state.hand:
			parts.append("C%d.%d" % [card.get_effective_value(), TelemetrySchema.merge_rank(card)])
		return "|".join(parts)


	## The first broken board invariant as text, or "" when the board is healthy.
	static func invariant_break(state: GameState) -> String:
		for unit: Unit in state.allies:
			var ally_break: String = unit_break(unit)
			if not ally_break.is_empty():
				return ally_break
		for unit: Unit in state.enemies:
			var enemy_break: String = unit_break(unit)
			if not enemy_break.is_empty():
				return enemy_break
		if state.hand.size() > state.max_hand_size:
			return "hand holds %d card(s) over the cap %d" % [state.hand.size(), state.max_hand_size]
		if state.actions_left < 0:
			return "actions_left is %d" % state.actions_left
		if state.merges_left < 0:
			return "merges_left is %d" % state.merges_left
		return ""


	## The invariants one unit must hold at every moment.
	static func unit_break(unit: Unit) -> String:
		if unit.current_hp < 0:
			return "%s has %d HP" % [unit.data.unit_id, unit.current_hp]
		if unit.current_hp > unit.max_hp:
			return "%s has %d HP over its max %d" % [unit.data.unit_id, unit.current_hp, unit.max_hp]
		if unit.shield < 0:
			return "%s has %d shield" % [unit.data.unit_id, unit.shield]
		if unit.moxie < 0 or unit.moxie > unit.max_moxie:
			return "%s has %d Moxie of %d" % [unit.data.unit_id, unit.moxie, unit.max_moxie]
		return ""


	## The base cards the run is holding. The deck and the discard pile always hold base
	## cards (a discarded merge is unpacked), while a card in hand *or played this turn*
	## may stand for the two or three it was merged from, so both are counted through
	## `_merged_sources`.
	static func base_card_count(state: GameState) -> int:
		var total: int = state.deck.size() + state.discard.size()
		for card: Card in state.hand:
			total += source_count(state, card)
		for card: Card in state.played_this_turn:
			total += source_count(state, card)
		return total


	## How many base deck cards one hand card stands for: a merged card's recorded
	## sources, or 1 for a base card. Read through an untyped `Array` because
	## `_merged_sources` holds typed `Array[Card]` values, which an `is Array` check
	## rejects.
	static func source_count(state: GameState, card: Card) -> int:
		if not state._merged_sources.has(card):
			return 1
		var listed: Array = state._merged_sources[card]
		return listed.size()


	## A recorded decision's index, read safely out of a Dictionary.
	static func decision_int(decision: Dictionary, key: String, fallback: int) -> int:
		var raw: Variant = decision.get(key, fallback)
		if raw is int:
			var value: int = raw
			return value
		return fallback


#region Constants
## The seed every determinism check starts from.
const SEED: int = 20260101
## Shipped scripts that may draw from the global RNG, and why. Note that a *seeded*
## member call (`generator.randi_range(...)`) is not one of these: the audit looks for
## bare calls, so the run generator seeding itself needs no entry.
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


## Runs one seeded battle to the end. `plan` replays a recorded run instead of playing
## the policy, which is what makes the replay check possible.
func _run(seed_value: int, ui: ScriptedUI, plan: Array = []) -> GameManager:
	ui.plan = plan
	var manager: GameManager = GameManager.new()
	add_child(manager)
	auto_free(manager)
	add_child(ui)
	auto_free(ui)
	manager.ui = ui
	var allies: Array[UnitData] = [_ally_data("striker"), _ally_data("healer")]
	await manager.setup_game(allies, _waves(), ui, _config(seed_value))
	return manager


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
	var first: ScriptedUI = ScriptedUI.new()
	var first_manager: GameManager = await _run(SEED, first)
	var second: ScriptedUI = ScriptedUI.new()
	var second_manager: GameManager = await _run(SEED, second)

	assert_int(first.decisions.size()).is_greater(0)
	assert_str("|".join(first.trace)).is_equal("|".join(second.trace))
	assert_array(first.decisions).is_equal(second.decisions)
	assert_bool(first_manager.game_running).is_false()
	assert_bool(second_manager.game_running).is_false()
	assert_str(ScriptedUI.fingerprint(first_manager.state)).is_equal(
		ScriptedUI.fingerprint(second_manager.state)
	)


## Guards against the failure mode where the test above passes because nothing in the
## battle is random at all.
func test_a_different_seed_deals_a_different_battle() -> void:
	var distinct: Dictionary = {}
	for offset: int in 4:
		var ui: ScriptedUI = ScriptedUI.new()
		await _run(SEED + offset, ui)
		distinct["|".join(ui.trace)] = true

	assert_int(distinct.size()).is_greater(1)


## The seed alone is not enough: if any path reached for the global RNG, the decisions
## recorded from one run would not fit a fresh board. Replaying them is what proves the
## run really is a function of the seed.
func test_a_recorded_plan_replays_against_a_fresh_board() -> void:
	var recorded: ScriptedUI = ScriptedUI.new()
	await _run(SEED, recorded)

	var replayed: ScriptedUI = ScriptedUI.new()
	await _run(SEED, replayed, recorded.decisions)

	assert_int(recorded.decisions.size()).is_greater(0)
	assert_bool(replayed.diverged).is_false()
	assert_str("|".join(replayed.trace)).is_equal("|".join(recorded.trace))
	# It replayed the plan rather than falling back to the policy.
	assert_array(replayed.decisions).is_empty()
#endregion


#region Invariants under a sweep
## A sweep rather than a single battle, because an invariant that only breaks on one
## deck order is exactly the bug a single scripted run would miss.
func test_the_board_holds_its_invariants_across_many_seeds() -> void:
	var broken: PackedStringArray = PackedStringArray()
	for offset: int in 24:
		var seed_value: int = SEED + offset
		var ui: ScriptedUI = ScriptedUI.new()
		var manager: GameManager = await _run(seed_value, ui)
		if not ui.violation.is_empty():
			broken.append("seed %d: %s" % [seed_value, ui.violation])
		if not ui.card_leak.is_empty():
			broken.append("seed %d: %s" % [seed_value, ui.card_leak])
		if manager.game_running:
			broken.append("seed %d never finished" % seed_value)

	assert_str("\n".join(broken)).is_equal("")


## The sweep is only meaningful if the runs are real: a battle that ended on turn one
## would satisfy every invariant above by never reaching the interesting states.
func test_a_swept_battle_is_a_real_battle() -> void:
	var ui: ScriptedUI = ScriptedUI.new()
	var manager: GameManager = await _run(SEED, ui)

	assert_bool(manager.state.all_allies_dead()).is_false()
	assert_int(manager.state.turn_number).is_greater(2)
	assert_int(ui.trace.size()).is_greater(8)
	assert_str(ScriptedUI.invariant_break(manager.state)).is_equal("")
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
