class_name EnemyTurnOverlapTest
extends GdUnitTestSuite
## Locks the enemy-turn overlap ("fast mode" pacing):
##   - consecutive enemies hand control to the next one at the impact beat of
##     their skill animation, so wind-downs overlap instead of stacking up
##   - enemy Ultimates and the player's own skills still play in full
##   - the overlap wait is a slice of the animation, never a wall-clock timer
##
## @author TheGreatJellyfish
## @version 11/18/2026


## Test double that records how long GameManager asks the presentation to wait.
class RecordingUI extends GameUI:
	var skill_leads: Array[float] = []
	var ultimate_plays: int = 0
	var play_order: Array[String] = []

	func show_message(_msg: String) -> void:
		pass

	func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
		pass

	func play_unit_skill(_unit: Unit, _skill_index: int, _rank: int = 0, lead: float = 1.0) -> void:
		skill_leads.append(lead)
		play_order.append("skill")

	func play_unit_ultimate(_unit: Unit) -> void:
		ultimate_plays += 1
		play_order.append("ultimate")


func _make_skill() -> SkillData:
	return SkillData.new()


func _make_enemy(max_hp: int = 40) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = "Enemy"
	data.is_enemy = true
	data.max_hp = max_hp
	data.max_moxie = 20
	data.skill_1 = _make_skill()
	data.skill_2 = _make_skill()
	data.ultimate = _make_skill()
	return Unit.new(data)


func _make_ally() -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = "Ally"
	data.max_hp = 20
	data.max_moxie = 20
	data.skill_1 = _make_skill()
	data.skill_2 = _make_skill()
	data.ultimate = _make_skill()
	return Unit.new(data)


func _make_manager(enemies: Array[Unit]) -> GameManager:
	var manager: GameManager = GameManager.new()
	add_child(manager)

	manager.state = GameState.new()
	var allies: Array[Unit] = [_make_ally()]
	manager.state.allies = allies
	manager.state.enemies = enemies

	var recorder: RecordingUI = RecordingUI.new()
	add_child(recorder)
	manager.ui = recorder
	return manager


func _recorder(manager: GameManager) -> RecordingUI:
	return manager.ui as RecordingUI


## Rolls the given values for the prepared enemies and runs their whole turn.
func _play_enemy_turn(manager: GameManager, rolls: Array[int]) -> void:
	var intents: Array[EnemyIntent] = []
	for i: int in rolls.size():
		intents.append(EnemyIntent.new(manager.state.enemies[i], rolls[i]))
	manager.current_intents = intents
	await manager._resolve_enemy_turns()


func test_consecutive_enemy_skills_overlap_at_the_impact_beat() -> void:
	var enemies: Array[Unit] = [_make_enemy(), _make_enemy(), _make_enemy()]
	var manager: GameManager = _make_manager(enemies)

	await _play_enemy_turn(manager, [1, 1, 1])

	var recorder: RecordingUI = _recorder(manager)
	assert_int(recorder.skill_leads.size()).is_equal(3)
	for lead: float in recorder.skill_leads:
		assert_float(lead).is_equal(GameManager.ENEMY_SKILL_OVERLAP_LEAD)


func test_overlap_lead_keeps_an_actual_overlap_window() -> void:
	# 1.0 would restore the old strictly sequential pacing (no overlap at all).
	assert_bool(GameManager.ENEMY_SKILL_OVERLAP_LEAD > 0.0).is_true()
	assert_bool(GameManager.ENEMY_SKILL_OVERLAP_LEAD < 1.0).is_true()


func test_enemy_ultimate_still_plays_in_full_after_the_skill() -> void:
	var enemies: Array[Unit] = [_make_enemy()]
	enemies[0].moxie = 19 # a roll of 1 fills the gauge
	var manager: GameManager = _make_manager(enemies)

	await _play_enemy_turn(manager, [1])

	var recorder: RecordingUI = _recorder(manager)
	assert_int(recorder.skill_leads.size()).is_equal(1)
	assert_float(recorder.skill_leads[0]).is_equal(GameManager.ENEMY_SKILL_OVERLAP_LEAD)
	assert_int(recorder.ultimate_plays).is_equal(1)
	assert_int(recorder.play_order.size()).is_equal(2)
	assert_str(recorder.play_order[0]).is_equal("skill")
	assert_str(recorder.play_order[1]).is_equal("ultimate")


func test_player_skill_still_waits_for_the_full_animation() -> void:
	var no_enemies: Array[Unit] = []
	var manager: GameManager = _make_manager(no_enemies)
	var ally: Unit = manager.state.allies[0]
	var card: Card = Card.new(1) # odd -> skill 1
	var hand: Array[Card] = [card]
	manager.state.hand = hand
	manager.state.actions_left = 1

	await manager._handle_play(card, ally)

	var recorder: RecordingUI = _recorder(manager)
	assert_int(recorder.skill_leads.size()).is_equal(1)
	assert_float(recorder.skill_leads[0]).is_equal(1.0)


func test_lead_wait_is_a_slice_of_the_animation_duration() -> void:
	# A longer animation gets a proportionally longer lead, so the overlap never
	# depends on a fixed wall-clock delay.
	var waited: float = SpinePortrait.lead_wait_seconds(2.0, GameManager.ENEMY_SKILL_OVERLAP_LEAD)
	assert_bool(is_equal_approx(waited, 1.2)).is_true()


func test_full_lead_means_wait_for_the_whole_animation() -> void:
	# -1 tells the caller to await action_finished instead of a lead beat.
	assert_float(SpinePortrait.lead_wait_seconds(2.0, 1.0)).is_equal(-1.0)
	assert_float(SpinePortrait.lead_wait_seconds(2.0, 1.5)).is_equal(-1.0)


func test_lead_wait_never_goes_negative() -> void:
	assert_float(SpinePortrait.lead_wait_seconds(2.0, -1.0)).is_equal(0.0)
	assert_float(SpinePortrait.lead_wait_seconds(-0.5, 0.5)).is_equal(0.0)


## A bare portrait (never added to the tree) lets the release logic be driven by
## hand, without a Spine skeleton or real-time waiting.
func _make_bare_portrait(anim: StringName, lead: float) -> SpinePortrait:
	var portrait: SpinePortrait = SpinePortrait.new()
	portrait._action_running = true
	portrait._active_action = anim
	portrait._action_lead = lead
	portrait._action_lead_armed = true
	portrait._action_watchdog = 100.0
	return portrait


func test_lead_beat_fires_once_once_the_animation_slice_elapsed() -> void:
	var portrait: SpinePortrait = _make_bare_portrait(&"skill1", 0.5)
	var reached: Array[StringName] = []
	portrait.action_lead_reached.connect(
		func(anim: StringName) -> void: reached.append(anim)
	)

	portrait._process(0.4) # still short of the lead beat
	assert_int(reached.size()).is_equal(0)
	assert_bool(portrait._action_lead_armed).is_true()

	portrait._process(0.2) # the lead beat passes
	assert_int(reached.size()).is_equal(1)
	assert_str(String(reached[0])).is_equal("skill1")
	assert_bool(portrait._action_lead_armed).is_false() # cannot fire twice

	portrait._process(1.0)
	assert_int(reached.size()).is_equal(1)
	portrait.free()


func test_lead_beat_is_flushed_when_the_action_ends_early() -> void:
	var portrait: SpinePortrait = _make_bare_portrait(&"skill1", 5.0)
	var reached: Array[StringName] = []
	portrait.action_lead_reached.connect(
		func(anim: StringName) -> void: reached.append(anim)
	)

	portrait._finish_active_action() # animation completed before its lead beat

	assert_int(reached.size()).is_equal(1)
	assert_str(String(reached[0])).is_equal("skill1")
	portrait.free()


func test_lead_beat_is_flushed_while_the_portrait_is_dying() -> void:
	var portrait: SpinePortrait = _make_bare_portrait(&"skill1", 0.2)
	var reached: Array[StringName] = []
	portrait.action_lead_reached.connect(
		func(anim: StringName) -> void: reached.append(anim)
	)
	# set_dead() needs a SceneTree for its death delay, so set the flag directly:
	# the point here is that a dying portrait never strands its chained caller.
	portrait._dead = true

	portrait._process(0.3)

	assert_int(reached.size()).is_equal(1)
	portrait.free()


func test_clearing_the_queue_releases_overlap_waiters() -> void:
	var portrait: SpinePortrait = _make_bare_portrait(&"skill2_1", 5.0)
	var reached: Array[StringName] = []
	portrait.action_lead_reached.connect(
		func(anim: StringName) -> void: reached.append(anim)
	)

	portrait._clear_action_queue() # e.g. skeleton reload, death, wave reset

	assert_int(reached.size()).is_equal(1)
	assert_str(String(reached[0])).is_equal("skill2_1")
	assert_bool(portrait._action_lead_armed).is_false()
	portrait.free()