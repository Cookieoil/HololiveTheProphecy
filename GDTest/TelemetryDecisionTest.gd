class_name TelemetryDecisionTest
extends GdUnitTestSuite
## Locks Core/Telemetry/TelemetryDecision.gd directly. GDTest/TelemetryTest.gd covers
## the same shapes end to end through a real battle, but it can only assert the pieces
## a scripted turn happens to produce; this pins the shapers themselves, including the
## cases a battle rarely reaches (a dead ally, a defeated enemy's stale intent, a card
## that costs an action with none left).
##
## @author TheGreatJellyfish
## @version 11/28/2026


#region Fixtures
func _skill(skill_id: String) -> SkillData:
	var skill: SkillData = SkillData.new()
	skill.skill_id = skill_id
	skill.skill_name = skill_id
	return skill


func _unit(unit_id: String, is_enemy: bool) -> Unit:
	var data: UnitData = UnitData.new()
	data.unit_id = unit_id
	data.display_name = unit_id
	data.is_enemy = is_enemy
	data.max_hp = 20
	data.max_moxie = 20
	data.skill_1 = _skill("%s_1" % unit_id)
	data.skill_2 = _skill("%s_2" % unit_id)
	data.ultimate = _skill("%s_ult" % unit_id)
	return Unit.new(data)


## One ally, one enemy, three cards in hand and three actions: enough for every shaper
## to have something real to describe.
func _state() -> GameState:
	var state: GameState = GameState.new()
	state.set_run_seed(7)
	var allies: Array[Unit] = [_unit("striker", false)]
	state.allies = allies
	var enemies: Array[Unit] = [_unit("normal_enemy", true)]
	state.enemies = enemies
	state.build_deck([[2, 3], [3, 3]])
	state.draw_n_cards(3)
	state.actions_left = 3
	state.merges_left = 2
	return state


func _no_intents() -> Array[EnemyIntent]:
	return []


## The event Dictionaries hold Variants, so they are read back through the same helper
## the serialisers use instead of an unsafe cast.
func _int_of(source: Dictionary, key: String) -> int:
	return TelemetrySchema.to_int(source.get(key, 0))


func _bool_of(source: Dictionary, key: String) -> bool:
	var value: Variant = source.get(key, false)
	if value is bool:
		var flag: bool = value
		return flag
	return false


func _array_of(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		var listed: Array = value
		return listed
	return []
#endregion


#region Offered
func test_offered_describes_the_hand_the_roster_and_the_plays() -> void:
	var state: GameState = _state()

	var decision: Dictionary = TelemetryDecision.offered(state, _no_intents())

	assert_int(_int_of(decision, "hand_size")).is_equal(3)
	assert_int(_int_of(decision, "actions_left")).is_equal(3)
	assert_int(_int_of(decision, "merges_left")).is_equal(2)
	assert_int(_array_of(decision, "offered_card_keys").size()).is_equal(3)
	assert_int(_array_of(decision, "living_ally_ids").size()).is_equal(1)
	assert_int(_array_of(decision, "dead_ally_ids").size()).is_equal(0)
	# One ally and three playable cards, so its skills are on offer.
	assert_int(_array_of(decision, "playable_skill_ids").size()).is_greater(0)
	assert_int(_array_of(decision, "playable_skills").size()).is_greater(0)


func test_a_defeated_ally_is_reported_as_dead_not_living() -> void:
	var state: GameState = _state()
	state.allies[0].take_damage(999)

	var decision: Dictionary = TelemetryDecision.offered(state, _no_intents())

	assert_int(_array_of(decision, "living_ally_ids").size()).is_equal(0)
	assert_int(_array_of(decision, "dead_ally_ids").size()).is_equal(1)
	# A dead ally can cast nothing, so nothing is on offer.
	assert_int(_array_of(decision, "playable_skill_ids").size()).is_equal(0)


## A defeated enemy keeps its stale intent in the list until the turn rolls over, and a
## stale intent must not read as a live threat.
func test_a_defeated_enemy_is_not_a_threat() -> void:
	var state: GameState = _state()
	var alive_intent: EnemyIntent = EnemyIntent.new(state.enemies[0], 5)
	var corpse: Unit = _unit("boss", true)
	corpse.take_damage(999)
	var stale_intent: EnemyIntent = EnemyIntent.new(corpse, 9)
	var intents: Array[EnemyIntent] = [alive_intent, stale_intent]

	var decision: Dictionary = TelemetryDecision.offered(state, intents)

	assert_int(_array_of(decision, "active_enemy_ids").size()).is_equal(1)
	assert_int(_int_of(decision, "intent_max_roll")).is_equal(5)


## A card that costs an action is not playable with none left, so it must not inflate
## the pick-rate denominator.
func test_a_card_that_costs_an_action_is_not_offered_with_no_actions_left() -> void:
	var state: GameState = _state()
	state.actions_left = 0

	assert_int(TelemetryDecision.playable_skill_options(state).size()).is_equal(0)
	assert_int(
		_array_of(TelemetryDecision.offered(state, _no_intents()), "playable_skill_ids").size()
	).is_equal(0)


func test_legal_merge_pairs_name_the_value_the_merge_would_produce() -> void:
	var state: GameState = _state()

	var pairs: Array = TelemetryDecision.legal_merge_pairs(state)

	# Three cards drawn from two values, so at least two of them share a value.
	assert_int(pairs.size()).is_greater(0)
	var first: Variant = pairs[0]
	assert_bool(first is Dictionary).is_true()
	if first is Dictionary:
		var pair: Dictionary = first
		assert_int(_int_of(pair, "result_value")).is_greater(0)
		assert_str(str(pair.get("kind", ""))).is_equal("cross")
#endregion


#region Chosen
func test_chosen_play_tells_a_rejected_play_from_an_applied_one() -> void:
	var state: GameState = _state()
	var card: Card = state.hand[0]
	var action: Dictionary = {"card": card, "target_ally": state.allies[0]}

	# The card is still in hand, so nothing happened.
	assert_bool(_bool_of(TelemetryDecision.chosen_play(action, state), "applied")).is_false()

	state.hand.remove_at(0)
	var applied: Dictionary = TelemetryDecision.chosen_play(action, state)
	assert_bool(_bool_of(applied, "applied")).is_true()
	# A play that landed names the skill it unlocked.
	assert_str(str(applied.get("skill_id", ""))).is_not_empty()
	assert_int(_int_of(applied, "skill_slot")).is_greater(0)


## The recorder notes the forged card only when the merge actually happened, so an
## empty note is exactly "this merge was rejected".
func test_chosen_merge_reports_a_rejected_merge_as_not_applied() -> void:
	var action: Dictionary = {"card_a": null, "card_b": null}

	assert_bool(_bool_of(TelemetryDecision.chosen_merge(action, {}), "applied")).is_false()
	assert_bool(
		_bool_of(TelemetryDecision.chosen_merge(action, {"key": "5_merged"}), "applied")
	).is_true()


func test_chosen_ultimate_requires_the_caster_to_have_spent_it() -> void:
	var state: GameState = _state()
	var caster: Unit = state.allies[0]
	var action: Dictionary = {"caster": caster}

	# Nothing has been cast yet.
	assert_bool(_bool_of(TelemetryDecision.chosen_ultimate(action), "applied")).is_false()

	# A cast empties the gauge and takes the once-per-turn lock, which is what tells a
	# spent Ultimate apart from one that was merely charged.
	caster.set_moxie(caster.max_moxie)
	caster.consume_moxie()
	var cast: Dictionary = TelemetryDecision.chosen_ultimate(action)
	assert_bool(_bool_of(cast, "applied")).is_true()
	assert_str(str(cast.get("ultimate_skill_id", ""))).is_equal("striker_ult")
#endregion
