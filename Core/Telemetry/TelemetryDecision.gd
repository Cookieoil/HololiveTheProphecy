class_name TelemetryDecision
extends RefCounted
## Pure shapers for one recorded decision: what the player could have done (`offered`)
## and what they actually did (`chosen`).
##
## Split out of Managers/TelemetryManager.gd, which had grown the whole decision
## vocabulary inside its event plumbing. Every function here is static and takes the
## live objects it needs, so the shape of a decision is testable without a recorder, a
## sink or a battle - the same reason Core/Telemetry/TelemetrySchema.gd exists beside
## it. TelemetryManager routes; these decide what a decision event carries.
##
## @author TheGreatJellyfish
## @version 11/28/2026

#region Public Methods
## Everything the player could have done at this instant: the full hand, every legal
## (ally, card) play, every legal merge pair, the ready Ultimates, the living enemies
## and how threatening their intents are. This is what makes a "pick rate" metric
## meaningful - the denominator, not just the choice.
##
## Deliberately branch-free: each part is one helper, so the shape of the event can be
## read at a glance and no single step can quietly grow.
static func offered(state: GameState, intents: Array[EnemyIntent]) -> Dictionary:
	var readiness: Dictionary = _ally_readiness(state)
	var options: Array = playable_skill_options(state)
	var threat: Dictionary = _intent_threat(intents)
	return {
		"actions_left": state.actions_left,
		"merges_left": state.merges_left,
		"hand_size": state.hand.size(),
		"cards_in_hand": TelemetrySchema.cards_snapshot(state.hand),
		"offered_card_keys": _card_keys(state),
		"living_ally_ids": readiness["living_ally_ids"],
		"dead_ally_ids": readiness["dead_ally_ids"],
		"playable_skill_ids": _playable_skill_ids(options),
		"playable_skills": options,
		"legal_merge_pairs": legal_merge_pairs(state),
		"ready_ultimates": readiness["ready_ultimates"],
		"ready_ultimate_skills": readiness["ready_ultimate_skills"],
		"active_enemy_ids": threat["active_enemy_ids"],
		"intent_max_roll": threat["intent_max_roll"],
		"intent_condition_met": threat["intent_condition_met"],
		"intent_ultimate_imminent": threat["intent_ultimate_imminent"],
	}


## Every (ally, card) play the player could legally make right now. This is the true
## denominator behind a skill pick rate: "striker_1 was playable on N decisions and
## was the choice on M of them".
static func playable_skill_options(state: GameState) -> Array:
	var options: Array = []
	for unit: Unit in state.allies:
		if unit.is_dead or unit.data == null:
			continue
		for card: Card in state.hand:
			if card.costs_action() and state.actions_left <= 0:
				continue
			var skill: SkillData = unit.data.skill_1 if card.is_odd() else unit.data.skill_2
			var skill_id: String = TelemetrySchema.skill_id_of(skill)
			if skill_id.is_empty():
				continue
			if options.size() >= TelemetrySchema.MAX_ROWS:
				return options
			options.append({
				"ally_id": TelemetrySchema.unit_id_of(unit),
				"slot": unit.slot_index,
				"skill_id": skill_id,
				"skill_slot": 1 if card.is_odd() else 2,
				"card_key": TelemetrySchema.card_key(card),
				"card_effective_value": card.get_effective_value(),
				"costs_action": card.costs_action(),
				"is_merged": card.is_merged,
				"is_double_merged": card.is_double_merged,
			})
	return options


## Every pair in hand that could legally be merged, with the value the result would
## have. Capped at MAX_ROWS, so a wide hand cannot bloat the event.
static func legal_merge_pairs(state: GameState) -> Array:
	var pairs: Array = []
	var hand: Array[Card] = state.hand
	for i: int in hand.size():
		for j: int in range(i + 1, hand.size()):
			if pairs.size() >= TelemetrySchema.MAX_ROWS:
				return pairs
			var a: Card = hand[i]
			var b: Card = hand[j]
			if not state.can_merge_pair(a, b):
				continue
			var is_double: bool = a.is_merged or b.is_merged
			var result_value: int = a.get_effective_value() + b.get_effective_value()
			if is_double:
				result_value += 1
			pairs.append({
				"a": a.id, "b": b.id,
				"kind": "double" if is_double else "cross",
				"a_value": a.get_effective_value(), "b_value": b.get_effective_value(),
				"result_value": result_value,
			})
	return pairs


## What one played card did: which card left the hand, which ally it went on and which
## skill that unlocked. `applied` is false when the play was rejected, which the card
## still sitting in hand tells apart.
static func chosen_play(action: Dictionary, state: GameState) -> Dictionary:
	var card: Card = action.get("card", null)
	var ally: Unit = action.get("target_ally", null)
	var applied: bool = card != null and not state.hand.has(card)
	var payload: Dictionary = {
		"applied": applied,
		"card": TelemetrySchema.card_snapshot(card),
		"target_ally_id": TelemetrySchema.unit_id_of(ally),
		"target_slot": ally.slot_index if ally != null else -1,
	}
	if applied and ally != null and ally.data != null:
		var skill: SkillData = ally.data.skill_1 if card.is_odd() else ally.data.skill_2
		payload["skill_id"] = TelemetrySchema.skill_id_of(skill)
		payload["skill_slot"] = 1 if card.is_odd() else 2
	return payload


## What one merge produced. `merge_result` is the recorder's note of the forged card,
## empty when the merge was rejected.
static func chosen_merge(action: Dictionary, merge_result: Dictionary) -> Dictionary:
	var card_a: Card = action.get("card_a", null)
	var card_b: Card = action.get("card_b", null)
	return {
		"applied": not merge_result.is_empty(),
		"card_a": TelemetrySchema.card_snapshot(card_a),
		"card_b": TelemetrySchema.card_snapshot(card_b),
		"result": merge_result,
	}


## What one cast Ultimate did: which ally spent it and which skill it was.
static func chosen_ultimate(action: Dictionary) -> Dictionary:
	var caster: Unit = action.get("caster", null)
	var payload: Dictionary = {
		"applied": caster != null and caster.ult_used_this_turn,
		"caster_id": TelemetrySchema.unit_id_of(caster),
		"slot": caster.slot_index if caster != null else -1,
	}
	if caster != null and caster.data != null:
		payload["ultimate_skill_id"] = TelemetrySchema.skill_id_of(caster.data.ultimate)
	return payload
#endregion


#region Private Methods
## The ally roster split into living / dead ids, plus the Ultimates that are ready
## right now (with their skill ids, de-duplicated).
static func _ally_readiness(state: GameState) -> Dictionary:
	var living_ally_ids: Array = []
	var dead_ally_ids: Array = []
	var ready_ultimates: Array = []
	var ready_ultimate_skills: Array = []
	for unit: Unit in state.allies:
		if unit.is_dead:
			dead_ally_ids.append(TelemetrySchema.unit_id_of(unit))
			continue
		living_ally_ids.append(TelemetrySchema.unit_id_of(unit))
		if unit.can_cast_ultimate:
			ready_ultimates.append(TelemetrySchema.unit_ref(unit))
			var ult: SkillData = unit.data.ultimate if unit.data != null else null
			var ult_id: String = TelemetrySchema.skill_id_of(ult)
			if not ult_id.is_empty() and not ready_ultimate_skills.has(ult_id):
				ready_ultimate_skills.append(ult_id)
	return {
		"living_ally_ids": living_ally_ids,
		"dead_ally_ids": dead_ally_ids,
		"ready_ultimates": ready_ultimates,
		"ready_ultimate_skills": ready_ultimate_skills,
	}


## A stable key per card in hand, capped so a pathological hand cannot bloat the event.
static func _card_keys(state: GameState) -> Array:
	var card_keys: Array = []
	for card: Card in state.hand:
		if card_keys.size() >= TelemetrySchema.MAX_ROWS:
			break
		card_keys.append(TelemetrySchema.card_key(card))
	return card_keys


## The distinct skill ids behind a list of playable (ally, card) options.
static func _playable_skill_ids(options: Array) -> Array:
	var playable_skill_ids: Array = []
	for option: Dictionary in options:
		var skill_id: String = str(option.get("skill_id", ""))
		if not skill_id.is_empty() and not playable_skill_ids.has(skill_id):
			playable_skill_ids.append(skill_id)
	return playable_skill_ids


## Who is still standing, and how threatening this turn's intents are.
static func _intent_threat(intents: Array[EnemyIntent]) -> Dictionary:
	var active_enemy_ids: Array = []
	var intent_max_roll: int = 0
	var intent_condition_met: bool = false
	var intent_ult_imminent: bool = false
	for intent: EnemyIntent in intents:
		if intent.enemy == null or intent.enemy.is_dead:
			continue
		active_enemy_ids.append(TelemetrySchema.unit_id_of(intent.enemy))
		intent_max_roll = maxi(intent_max_roll, intent.effective_value)
		if intent.condition_met:
			intent_condition_met = true
		if intent.will_trigger_ultimate():
			intent_ult_imminent = true
	return {
		"active_enemy_ids": active_enemy_ids,
		"intent_max_roll": intent_max_roll,
		"intent_condition_met": intent_condition_met,
		"intent_ultimate_imminent": intent_ult_imminent,
	}
#endregion
