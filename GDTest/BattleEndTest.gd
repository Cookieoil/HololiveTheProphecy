class_name BattleEndTest
extends GdUnitTestSuite
## Locks the end of a battle:
##   - a unit that dies never keeps Moxie (or a "ULT READY" glow) on the board
##   - the skill that kills the final boss does not charge the caster's gauge
##   - a cleared final wave ends the battle right away, with no empty enemy turn
##   - every way out of the loop (Victory / Defeat, player phase / enemy turn /
##     status tick) goes through one exit that wipes intents and Moxie
##   - the Victory / Defeat cutscene stays flat (SDR colours, no neon) and its
##     "Play Again" button asks the scene to restart
##
## @author TheGreatJellyfish
## @version 11/25/2026


## Test double that records what GameManager asks the presentation to do.
class RecordingUI extends GameUI:
	var intents_shown: int = 0
	var last_intent_count: int = 0
	var hand_refreshes: int = 0
	var battle_results: Array[bool] = []
	var messages: Array[String] = []
	var skill_plays: Array[Unit] = []
	## Actions handed back by `get_player_action`, in order. An empty queue answers
	## "end_turn", so a test only has to list the actions it cares about.
	var scripted_actions: Array[Dictionary] = []

	func show_message(msg: String) -> void:
		messages.append(msg)

	func show_game_state(_state: GameState) -> void:
		pass

	func show_enemy_intents(intents: Array[EnemyIntent]) -> void:
		intents_shown += 1
		last_intent_count = intents.size()

	func show_hand_and_resources(_state: GameState) -> void:
		hand_refreshes += 1

	func play_unit_skill(unit: Unit, _skill_index: int, _rank: int = 0, _lead: float = 1.0) -> void:
		skill_plays.append(unit)

	func play_unit_ultimate(unit: Unit) -> void:
		skill_plays.append(unit)

	func get_player_action(_state: GameState) -> Dictionary:
		if scripted_actions.is_empty():
			return {"type": "end_turn"}
		return scripted_actions.pop_front()

	func show_battle_result(victory: bool) -> void:
		battle_results.append(victory)


#region Helpers
func _make_unit_data(unit_name: String, is_enemy: bool, hp: int) -> UnitData:
	var data: UnitData = UnitData.new()
	data.display_name = unit_name
	data.is_enemy = is_enemy
	data.max_hp = hp
	data.max_moxie = 20
	return data


## A skill that hits every enemy for a fixed amount, so a test can one-shot a wave.
func _make_nuke_skill(amount: int) -> SkillData:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_DAMAGE
	block.target_mode = EffectBlock.TargetMode.ALL_ENEMIES
	block.value_source = EffectBlock.ValueSource.FIXED
	block.fixed_amount = amount
	block.condition = EffectBlock.Condition.NONE

	var effects: Array[SkillEffect] = []
	effects.append(block)

	var skill: SkillData = SkillData.new()
	skill.skill_name = "Test Nuke"
	skill.base_effects = effects
	return skill


func _make_manager() -> GameManager:
	var manager: GameManager = GameManager.new()
	add_child(manager)
	manager.state = GameState.new()
	var recorder: RecordingUI = RecordingUI.new()
	add_child(recorder)
	manager.ui = recorder
	return manager


func _recorder(manager: GameManager) -> RecordingUI:
	return manager.ui as RecordingUI


## Builds a run of `wave_count` waves whose last one holds a single boss, and puts
## the player on wave `current_wave` with one action and one odd card in hand.
## @return the boss unit of the current wave
func _prepare_wave(manager: GameManager, wave_count: int, current_wave: int) -> Unit:
	var boss_data: UnitData = _make_unit_data("Final Boss", true, 30)
	var ally_data: UnitData = _make_unit_data("Ally", false, 20)
	ally_data.skill_1 = _make_nuke_skill(99)
	ally_data.skill_2 = _make_nuke_skill(99)

	var waves: Array = []
	for i: int in wave_count:
		var wave: Array[UnitData] = []
		wave.append(boss_data)
		waves.append(wave)
	manager.state.wave_definitions = waves
	manager.state.current_wave = current_wave

	var allies: Array[Unit] = [Unit.new(ally_data, 0)]
	var enemies: Array[Unit] = [Unit.new(boss_data, 0)]
	enemies[0].is_ally = false
	manager.state.allies = allies
	manager.state.enemies = enemies
	manager.state.actions_left = 1

	var card: Card = Card.new(1) # odd -> skill 1
	var hand: Array[Card] = [card]
	manager.state.hand = hand
	return enemies[0]
#endregion


#region Unit: a dead unit never keeps Moxie
func test_a_dead_unit_empties_its_moxie_gauge() -> void:
	var unit: Unit = Unit.new(_make_unit_data("Boss", true, 30))
	unit.gain_moxie(14)
	assert_int(unit.moxie).is_equal(14)

	unit.take_damage(999)

	assert_bool(unit.is_dead).is_true()
	assert_int(unit.moxie).is_equal(0)


func test_death_releases_a_full_ready_gauge() -> void:
	var unit: Unit = Unit.new(_make_unit_data("Boss", true, 30))
	unit.data.ultimate = SkillData.new()
	unit.gain_moxie(20)
	assert_bool(unit.can_cast_ultimate).is_true()

	unit.take_damage(999)

	assert_bool(unit.can_cast_ultimate).is_false()
	assert_int(unit.moxie).is_equal(0)


func test_clear_moxie_emits_only_when_the_gauge_had_something() -> void:
	var unit: Unit = Unit.new(_make_unit_data("Ally", false, 20))
	var emissions: Array[int] = []
	unit.moxie_changed.connect(
		func(current: int, _maximum: int) -> void: emissions.append(current)
	)

	unit.clear_moxie() # already empty and unlocked: nothing to report
	assert_int(emissions.size()).is_equal(0)

	unit.gain_moxie(5)
	assert_int(emissions.size()).is_equal(1)

	unit.clear_moxie()
	assert_int(emissions.size()).is_equal(2)
	assert_int(emissions[1]).is_equal(0)


func test_clear_moxie_releases_the_once_per_turn_ultimate_lock() -> void:
	var unit: Unit = Unit.new(_make_unit_data("Ally", false, 20))
	unit.data.ultimate = SkillData.new()
	unit.gain_moxie(20)
	unit.consume_moxie()
	assert_bool(unit.ult_used_this_turn).is_true()

	unit.clear_moxie()

	assert_bool(unit.ult_used_this_turn).is_false()
#endregion


#region Final wave detection
func test_a_run_with_a_later_wave_is_not_the_final_wave() -> void:
	var manager: GameManager = _make_manager()
	var boss: Unit = _prepare_wave(manager, 2, 0)
	boss.take_damage(999)

	assert_bool(manager._has_remaining_waves()).is_true()
	assert_bool(manager._is_final_wave_cleared()).is_false()


func test_the_last_wave_of_the_run_is_the_final_wave() -> void:
	var manager: GameManager = _make_manager()
	var boss: Unit = _prepare_wave(manager, 2, 1)
	boss.take_damage(999)

	assert_bool(manager._has_remaining_waves()).is_false()
	assert_bool(manager._is_final_wave_cleared()).is_true()


func test_a_living_boss_is_never_a_cleared_wave() -> void:
	var manager: GameManager = _make_manager()
	_prepare_wave(manager, 1, 0)

	assert_bool(manager._is_final_wave_cleared()).is_false()
#endregion


#region The winning skill does not charge Moxie
func test_the_winning_skill_does_not_charge_the_casters_moxie() -> void:
	var manager: GameManager = _make_manager()
	var boss: Unit = _prepare_wave(manager, 1, 0)
	boss.gain_moxie(9)
	var ally: Unit = manager.state.allies[0]
	var card: Card = manager.state.hand[0]

	await manager._handle_play(card, ally)

	assert_bool(boss.is_dead).is_true()
	assert_int(boss.moxie).is_equal(0)   # the dead boss keeps no crystals
	assert_int(ally.moxie).is_equal(0)   # the winning skill charges nothing
	assert_bool(manager._is_final_wave_cleared()).is_true()


func test_clearing_a_wave_with_a_successor_still_charges_moxie() -> void:
	var manager: GameManager = _make_manager()
	var boss: Unit = _prepare_wave(manager, 2, 0)
	boss.gain_moxie(7)
	var ally: Unit = manager.state.allies[0]
	var card: Card = manager.state.hand[0]

	await manager._handle_play(card, ally)

	assert_bool(boss.is_dead).is_true()
	assert_int(boss.moxie).is_equal(0)   # the dead enemy keeps no crystals
	assert_int(ally.moxie).is_equal(1)   # but the run continues, so the gauge charges
	assert_bool(manager._is_final_wave_cleared()).is_false()
#endregion


#region Post-action clear check
func test_a_cleared_final_wave_ends_the_player_phase() -> void:
	var manager: GameManager = _make_manager()
	var boss: Unit = _prepare_wave(manager, 1, 0)
	boss.take_damage(999)

	assert_bool(manager._resolve_enemy_clear_after_action()).is_true()


func test_a_full_turn_wave_clear_ends_the_player_phase_without_advancing() -> void:
	var manager: GameManager = _make_manager()
	manager.state.wave_transition_mode = GameState.WaveTransition.FULL_TURN
	var boss: Unit = _prepare_wave(manager, 2, 0)
	boss.take_damage(999)

	assert_bool(manager._resolve_enemy_clear_after_action()).is_true()
	assert_int(manager.state.current_wave).is_equal(0) # the next wave waits for the new turn


func test_an_immediate_skip_wave_clear_spawns_the_next_wave_and_continues() -> void:
	var manager: GameManager = _make_manager()
	manager.state.wave_transition_mode = GameState.WaveTransition.IMMEDIATE_SKIP
	var boss: Unit = _prepare_wave(manager, 2, 0)
	boss.take_damage(999)

	assert_bool(manager._resolve_enemy_clear_after_action()).is_false()
	assert_int(manager.state.current_wave).is_equal(1)
	assert_int(manager.state.get_living_enemies().size()).is_equal(1)


func test_a_living_board_never_ends_the_player_phase() -> void:
	var manager: GameManager = _make_manager()
	_prepare_wave(manager, 1, 0)

	assert_bool(manager._resolve_enemy_clear_after_action()).is_false()
#endregion


#region Player phase: an Ultimate that wins the battle
func test_an_ultimate_that_clears_the_final_wave_ends_the_player_phase() -> void:
	var manager: GameManager = _make_manager()
	_prepare_wave(manager, 1, 0)
	var ally: Unit = manager.state.allies[0]
	ally.data.ultimate = _make_nuke_skill(99)
	ally.gain_moxie(20)
	assert_bool(ally.can_cast_ultimate).is_true()

	var recorder: RecordingUI = _recorder(manager)
	var ultimate_action: Dictionary = {"type": "ultimate", "caster": ally}
	recorder.scripted_actions = [ultimate_action, {"type": "end_turn"}]

	await manager._player_action_phase()

	assert_bool(manager.state.all_enemies_dead()).is_true()
	# The queued "end_turn" was never asked for: the phase ended on its own.
	assert_int(recorder.scripted_actions.size()).is_equal(1)
#endregion


#region One exit for every ending
func test_finish_battle_wipes_moxie_and_intents_then_reports_victory() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = Unit.new(_make_unit_data("Ally", false, 20), 0)
	ally.data.ultimate = SkillData.new()
	var enemy: Unit = Unit.new(_make_unit_data("Enemy", true, 20), 0)
	enemy.is_ally = false
	var allies: Array[Unit] = [ally]
	var enemies: Array[Unit] = [enemy]
	manager.state.allies = allies
	manager.state.enemies = enemies
	ally.gain_moxie(20)
	enemy.gain_moxie(12)
	manager.game_running = true
	var intents: Array[EnemyIntent] = [EnemyIntent.new(enemy, 4)]
	manager.current_intents = intents

	var recorder: RecordingUI = _recorder(manager)
	await manager._finish_battle(true)

	assert_bool(manager.game_running).is_false()
	assert_int(manager.current_intents.size()).is_equal(0)
	assert_int(recorder.last_intent_count).is_equal(0)
	assert_int(ally.moxie).is_equal(0)
	assert_int(enemy.moxie).is_equal(0)
	assert_bool(ally.can_cast_ultimate).is_false()
	assert_int(recorder.battle_results.size()).is_equal(1)
	assert_bool(recorder.battle_results[0]).is_true()


func test_finish_battle_on_defeat_also_wipes_moxie() -> void:
	var manager: GameManager = _make_manager()
	var ally: Unit = Unit.new(_make_unit_data("Ally", false, 20), 0)
	var enemy: Unit = Unit.new(_make_unit_data("Enemy", true, 20), 0)
	enemy.is_ally = false
	var allies: Array[Unit] = [ally]
	var enemies: Array[Unit] = [enemy]
	manager.state.allies = allies
	manager.state.enemies = enemies
	ally.take_damage(999)
	enemy.gain_moxie(15)
	manager.game_running = true

	var recorder: RecordingUI = _recorder(manager)
	await manager._finish_battle(false)

	assert_bool(manager.game_running).is_false()
	assert_int(enemy.moxie).is_equal(0) # the surviving enemy's gauge is emptied too
	assert_int(recorder.battle_results.size()).is_equal(1)
	assert_bool(recorder.battle_results[0]).is_false()


func test_finish_battle_refreshes_the_hand_and_resources() -> void:
	var manager: GameManager = _make_manager()
	var allies: Array[Unit] = [Unit.new(_make_unit_data("Ally", false, 20), 0)]
	manager.state.allies = allies

	var recorder: RecordingUI = _recorder(manager)
	await manager._finish_battle(true)

	assert_int(recorder.hand_refreshes).is_equal(1)
#endregion


#region The loop ends the battle on the winning action
func test_the_loop_ends_the_battle_as_soon_as_the_final_wave_dies() -> void:
	var manager: GameManager = _make_manager()
	_prepare_wave(manager, 1, 0)
	manager.state.wave_transition_mode = GameState.WaveTransition.FULL_TURN
	var ally: Unit = manager.state.allies[0]
	var card: Card = manager.state.hand[0]

	var recorder: RecordingUI = _recorder(manager)
	recorder.scripted_actions = [{"type": "play", "card": card, "target_ally": ally}]
	manager.game_running = true

	await manager._run_game_loop()

	assert_bool(manager.game_running).is_false()
	assert_int(recorder.battle_results.size()).is_equal(1)
	assert_bool(recorder.battle_results[0]).is_true()
	# The enemy turn never ran: the only animation played is the ally's own skill.
	assert_int(recorder.skill_plays.size()).is_equal(1)
	assert_bool(recorder.skill_plays[0] == ally).is_true()
#endregion


#region Moxie orb: a dead unit's orb drains
func _make_orb(enemy: Unit) -> MoxieOrbUI:
	var orb: MoxieOrbUI = MoxieOrbUI.new()
	add_child(orb)
	orb.bind_unit(enemy, "E1")
	return orb


func test_the_orb_releases_its_preview_when_the_unit_dies() -> void:
	var enemy: Unit = Unit.new(_make_unit_data("Enemy", true, 20))
	enemy.is_ally = false
	var orb: MoxieOrbUI = _make_orb(enemy)
	orb.set_preview_gain(6)
	assert_int(orb._preview_gain).is_equal(6)

	enemy.take_damage(999)
	orb._process(0.016)

	assert_bool(orb._was_dead).is_true()
	assert_int(orb._preview_gain).is_equal(0)


## The reported bug: a unit that dies without its gauge moving (it was empty, or
## its fill never changed) used to keep a fully lit ring, because the ring only
## re-synced while the gauge was animating. The death itself must re-sync it.
func test_the_orb_ring_dims_even_when_the_gauge_never_moved() -> void:
	var enemy: Unit = Unit.new(_make_unit_data("Enemy", true, 20))
	enemy.is_ally = false
	var orb: MoxieOrbUI = _make_orb(enemy)

	var alive_alpha: Variant = orb._ring_mat.get_shader_parameter("alpha_mul")
	assert_bool(alive_alpha is float).is_true()
	assert_float(alive_alpha).is_equal(1.0)

	enemy.take_damage(999)
	orb._process(0.016)

	var dead_alpha: Variant = orb._ring_mat.get_shader_parameter("alpha_mul")
	assert_bool(dead_alpha is float).is_true()
	assert_float(dead_alpha).is_equal(0.35)


func test_the_orb_ring_follows_the_drained_gauge_to_empty() -> void:
	var enemy: Unit = Unit.new(_make_unit_data("Enemy", true, 20))
	enemy.is_ally = false
	var orb: MoxieOrbUI = _make_orb(enemy)
	enemy.gain_moxie(12)

	enemy.take_damage(999)
	for i: int in 40:
		orb._process(0.05)

	var fill: Variant = orb._ring_mat.get_shader_parameter("fill_ratio")
	assert_bool(fill is float).is_true()
	assert_float(fill).is_equal(0.0)
#endregion


#region Victory / Defeat cutscene
func _make_overlay() -> BattleResultOverlay:
	var overlay: BattleResultOverlay = BattleResultOverlay.new()
	add_child(overlay)
	return overlay


## The project runs with `viewport/hdr_2d=true`, so a channel above 1.0 would
## bloom. The cutscene is deliberately flat: every colour has to stay in SDR range.
func _is_flat_sdr(color: Color) -> bool:
	return color.r <= 1.0 and color.g <= 1.0 and color.b <= 1.0 and color.a <= 1.0


## True when a stylebox draws no border on any edge.
func _has_no_border(style: StyleBox) -> bool:
	var flat: StyleBoxFlat = style as StyleBoxFlat
	if flat == null:
		return false
	return flat.border_width_left == 0 and flat.border_width_top == 0 \
		and flat.border_width_right == 0 and flat.border_width_bottom == 0


## Reads one shader uniform off a node's material as a Color.
func _shader_color(node: CanvasItem, param: String) -> Color:
	var mat: ShaderMaterial = node.material as ShaderMaterial
	assert_object(mat).is_not_null()
	var value: Variant = mat.get_shader_parameter(param)
	assert_bool(value is Color).is_true()
	var color: Color = value
	return color


func test_the_victory_banner_uses_its_placeholder_emblem_and_flat_colours() -> void:
	var overlay: BattleResultOverlay = _make_overlay()

	await overlay.play_cutscene(true)

	assert_bool(overlay.is_showing()).is_true()
	assert_str(overlay._title.text).is_equal("VICTORY")
	assert_str(overlay._title_ghost.text).is_equal("VICTORY")
	assert_bool(overlay.victory_icon == BattleResultOverlay.PLACEHOLDER_VICTORY_ICON).is_true()
	assert_bool(overlay._emblem.texture == overlay.victory_icon).is_true()
	assert_bool(_is_flat_sdr(overlay._title.get_theme_color("font_color"))).is_true()
	assert_bool(_is_flat_sdr(_shader_color(overlay._backdrop, "grade_tint"))).is_true()
	assert_bool(_is_flat_sdr(_shader_color(overlay._emblem, "seal_color"))).is_true()
	# The reveal ends with the tracking condensed into its locked value.
	assert_int(overlay._title_variation.spacing_glyph).is_equal(BattleResultOverlay.TITLE_TRACK_TO)


func test_the_defeat_banner_swaps_to_its_own_emblem_and_text() -> void:
	var overlay: BattleResultOverlay = _make_overlay()

	await overlay.play_cutscene(false)

	assert_str(overlay._title.text).is_equal("DEFEAT")
	assert_str(overlay._title_ghost.text).is_equal("DEFEAT")
	assert_bool(overlay.defeat_icon == BattleResultOverlay.PLACEHOLDER_DEFEAT_ICON).is_true()
	assert_bool(overlay._emblem.texture == overlay.defeat_icon).is_true()
	assert_bool(_is_flat_sdr(overlay._title.get_theme_color("font_color"))).is_true()


## Removed on request: the small rectangle around the title (the slab) and the
## rectangle around the icon (the emblem tile). The backdrop stays, and so do the
## emblem, the title and the prompt - and no subtitle or divider between them.
func test_the_cutscene_boxes_neither_the_title_nor_the_icon() -> void:
	var overlay: BattleResultOverlay = _make_overlay()

	await overlay.play_cutscene(true)

	assert_object(overlay.find_child("Backdrop", true, false)).is_not_null()
	assert_object(overlay.find_child("Banner", true, false)).is_null()
	assert_object(overlay.find_child("EmblemFrame", true, false)).is_null()
	assert_object(overlay.find_child("Subtitle", true, false)).is_null()
	assert_object(overlay.find_child("Divider", true, false)).is_null()


## The requested look: the title laps over the emblem, and the emblem is added
## before the title stack so it stays behind it.
func test_the_title_laps_over_the_emblem() -> void:
	var overlay: BattleResultOverlay = _make_overlay()

	await overlay.play_cutscene(true)

	var separation: int = overlay._mark.get_theme_constant("separation")
	assert_bool(separation < 0).is_true()
	assert_bool(overlay._mark.get_child(0) == overlay._emblem).is_true()
	assert_bool(overlay._mark.get_child(1) == overlay._title_stack).is_true()
	var emblem: Rect2 = overlay._emblem.get_global_rect()
	var title: Rect2 = overlay._title.get_global_rect()
	assert_bool(emblem.end.y > title.position.y).is_true()


## The prompt replaced the old filled button: no box, no border, and pressing it
## asks the scene to restart.
func test_the_prompt_has_no_box_and_asks_the_owner_to_restart() -> void:
	var overlay: BattleResultOverlay = _make_overlay()
	await overlay.play_cutscene(true)
	var requests: Array[bool] = []
	overlay.restart_requested.connect(func() -> void: requests.append(true))

	assert_bool(overlay._prompt is BattleResultPrompt).is_true()
	assert_bool(overlay._prompt.interactive).is_true()
	var variation: FontVariation = overlay._prompt._label.get_theme_font("font") as FontVariation
	assert_object(variation).is_not_null()
	assert_int(variation.spacing_glyph).is_equal(BattleResultPrompt.GLYPH_SPACING)

	overlay._prompt.pressed.emit()

	assert_int(requests.size()).is_equal(1)
	assert_bool(overlay.is_showing()).is_false()


func test_the_result_screen_blocks_clicks_to_the_board_behind_it() -> void:
	var overlay: BattleResultOverlay = _make_overlay()

	await overlay.play_cutscene(true)

	assert_int(overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(overlay._backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(overlay._prompt.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
#endregion


#region Scene wiring
func _load_battle_scene() -> BattleScene:
	var packed: PackedScene = load("res://Scenes/BattleScene/BattleScene.tscn") as PackedScene
	assert_object(packed).is_not_null()
	var scene: BattleScene = packed.instantiate() as BattleScene
	add_child(scene)
	auto_free(scene)
	return scene


## The battle scene is where the cutscene layer, the overlay and the restart
## signal meet, so this loads the real scene and checks they are connected.
func test_the_battle_scene_mounts_the_cutscene_above_every_other_layer() -> void:
	var scene: BattleScene = _load_battle_scene()

	# _setup_result_overlay() runs before the first await in _ready(), so the layer
	# and its overlay already exist by the time add_child() returns.
	assert_object(scene.result_layer).is_not_null()
	assert_object(scene.result_overlay).is_not_null()
	# The backdrop shader grades what is behind it, so the battle has to be copied
	# into the back buffer first.
	assert_object(scene.result_back_buffer).is_not_null()
	assert_bool(scene.result_back_buffer.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT).is_true()
	assert_bool(scene.result_overlay.visible).is_false()
	# Above the HUD (2), the Moxie rails (3), the tooltip layer (10) and debug (20).
	assert_int(scene.result_layer.layer).is_equal(30)
	assert_bool(scene.result_layer.layer > scene.debug_layer.layer).is_true()
	# "Play Again" is wired to the scene's own restart handler.
	assert_bool(
		scene.result_overlay.restart_requested.is_connected(
			Callable(scene, "_on_restart_requested")
		)
	).is_true()


## The Moxie rails are combat chrome, so they step off stage before the cutscene
## takes the screen and leave the battlefield alone behind it.
func test_the_moxie_rails_retreat_for_the_result() -> void:
	var scene: BattleScene = _load_battle_scene()

	await scene.battle_overlay.retreat_for_result()

	assert_float(scene.battle_overlay._enemy_rail.modulate.a).is_equal(0.0)
	assert_float(scene.battle_overlay._ally_rail.modulate.a).is_equal(0.0)


## The scene's cutscene: banner up, player controls locked, placeholder emblem in
## place. The game loop is parked on the player action, so this never restarts.
func test_the_scene_cutscene_raises_the_banner_and_locks_the_player_controls() -> void:
	var scene: BattleScene = _load_battle_scene()

	await scene.show_battle_result(true)

	assert_bool(scene.result_overlay.is_showing()).is_true()
	assert_str(scene.result_overlay._title.text).is_equal("VICTORY")
	assert_bool(scene.end_turn_button.disabled).is_true()
	assert_bool(scene.convert_button.disabled).is_true()
#endregion
