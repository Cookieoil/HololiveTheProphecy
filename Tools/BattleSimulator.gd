class_name BattleSimulator
extends Node
## Drives a whole battle headlessly through the GameUI contract and reports the board at
## every decision, so a run seed can be replayed and a sweep can assert the board's
## invariants.
##
## Two callers share it: `GDTest/DeterminismTest.gd` proves the same seed replays, and
## `Tools/simulate_runs.tscn` replays a seed from the command line. Sharing one policy is
## the point — a test and a tool that played differently would be checking different
## games.
##
## It is a Node rather than a RefCounted because the turn loop only ever talks to a
## GameUI, which is a Node, and because GameManager has to be inside the tree.
##
## @author TheGreatJellyfish
## @version 11/28/2026


## A GameUI that plays a policy and records it, or replays a recorded plan.
##
## Decisions are recorded as *positions* (hand index, ally index) rather than object
## references, so they can be replayed against a fresh board: the same seed deals the
## same hand and the same units, so index 2 is the same card in both runs. It observes
## the board before every decision, which is the only hook the turn loop offers.
class Recorder extends GameUI:
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
	##
	## It covers the status badges and the pending skill bonus too: a status that ticks at
	## the end of the round changes the board as much as a hit does, and the bonus a merged
	## Buff is holding changes the next card's value, so a replay that differed only there
	## would otherwise look identical.
	static func fingerprint(state: GameState) -> String:
		var parts: PackedStringArray = PackedStringArray()
		parts.append("t%d/w%d/a%d/m%d/b%d" % [
			state.turn_number, state.current_wave, state.actions_left, state.merges_left,
			state.next_skill_bonus
		])
		parts.append("deck%d/disc%d/played%d" % [
			state.deck.size(), state.discard.size(), state.played_this_turn.size()
		])
		for unit: Unit in state.allies:
			parts.append("A%s:%d/%d:s%d:m%d:%s" % [
				unit.data.unit_id, unit.current_hp, unit.max_hp, unit.shield, unit.moxie,
				status_digest(unit)
			])
		for unit: Unit in state.enemies:
			parts.append("E%s:%d/%d:s%d:m%d:%s" % [
				unit.data.unit_id, unit.current_hp, unit.max_hp, unit.shield, unit.moxie,
				status_digest(unit)
			])
		for card: Card in state.hand:
			parts.append("C%d.%d" % [card.get_effective_value(), TelemetrySchema.merge_rank(card)])
		return "|".join(parts)


	## One unit's statuses as `idCOUNT+idCOUNT`, sorted by id, or "-" when it has none.
	##
	## Sorted because the order two statuses arrived in is not part of the board: two units
	## holding the same badges must fingerprint the same either way.
	static func status_digest(unit: Unit) -> String:
		var ids: Array[String] = []
		for raw_id: Variant in unit.statuses.keys():
			ids.append(str(raw_id))
		if ids.is_empty():
			return "-"
		ids.sort()
		var parts: PackedStringArray = PackedStringArray()
		for status_id: String in ids:
			parts.append("%s%d" % [status_id, unit.get_status_count(status_id)])
		return "+".join(parts)


	## The first broken board invariant as text, or "" when the board is healthy.
	##
	## The hand's size is deliberately not one of these. `max_hand_size` is the draw step's
	## *target*, not a hard cap: a card effect may draw past it, and "Draw 2 cards" in the
	## shipped skills does exactly that. A hand that grew out of nothing is caught by card
	## conservation instead, which is the property that actually has to hold.
	static func invariant_break(state: GameState) -> String:
		for unit: Unit in state.allies:
			var ally_break: String = unit_break(unit)
			if not ally_break.is_empty():
				return ally_break
		for unit: Unit in state.enemies:
			var enemy_break: String = unit_break(unit)
			if not enemy_break.is_empty():
				return enemy_break
		if state.actions_left < 0:
			return "actions_left is %d" % state.actions_left
		if state.merges_left < 0:
			return "merges_left is %d" % state.merges_left
		if state.next_skill_bonus < 0:
			return "next_skill_bonus is %d" % state.next_skill_bonus
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
		return status_break(unit)


	## A status at 0 stacks is a leak, not a state: `tick_round_end_statuses` erases a
	## duration status when its last round is spent and a stack status never reaches 0
	## through play, so a badge sitting at 0 would render and tick forever.
	static func status_break(unit: Unit) -> String:
		for raw_id: Variant in unit.statuses.keys():
			var status_id: String = str(raw_id)
			var count: int = unit.get_status_count(status_id)
			if count < 1:
				return "%s has %s at %d stack(s)" % [unit.data.unit_id, status_id, count]
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


#region Public Variables
## The battle that was run, once `run()` has returned.
var manager: GameManager = null
## The policy/observer that drove it. Its `trace`, `decisions`, `violation`, `card_leak`
## and `diverged` are the result of the run.
var recorder: Recorder = null
#endregion


#region Lifecycle Methods
func _ready() -> void:
	recorder = Recorder.new()
	add_child(recorder)
	manager = GameManager.new()
	add_child(manager)
	manager.ui = recorder
#endregion


#region Public Methods
## Runs one whole battle to its end. `plan` replays a recorded run instead of playing the
## policy, which is what makes a replay check possible.
func run(allies: Array[UnitData], waves: Array, config: Dictionary, plan: Array = []) -> void:
	recorder.plan = plan
	await manager.setup_game(allies, waves, recorder, config)


## Runs the battle the game itself ships, from `Data/json` through DataLoader, with the
## run seed pinned: the path BattleScene takes, minus the view. This is what makes a seed
## out of a telemetry report replayable — same data, same seed, same trace.
## @param seed_value the run seed to pin
## @param flag_overrides staged flags to force on (name -> true), for a local experiment
func run_shipped(seed_value: int, flag_overrides: Dictionary = {}) -> void:
	var db: GameDatabase = DataLoader.db()
	var allies: Array[UnitData] = []
	var ally_ids: Array = db.config.get("allies", [])
	for id: String in ally_ids:
		if db.units.has(id):
			allies.append(db.units[id])
	var config: Dictionary = db.config.duplicate()
	config["seed"] = seed_value
	config["flag_definitions"] = db.flags
	config["flag_overrides"] = flag_overrides
	await run(allies, db.waves, config)
#endregion


