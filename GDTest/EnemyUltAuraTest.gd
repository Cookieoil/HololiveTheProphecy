class_name EnemyUltAuraTest
extends GdUnitTestSuite
## Locks in the enemy Ultimate warning lifecycle. The crimson character aura and
## the Moxie orb preview both describe one *pending* roll, so neither may outlive
## the roll that created them:
##   - a roll that lands short must release the warning (no phantom "ULT READY")
##   - a roll that fills the gauge must keep it, then release it on the cast
##
## @author TheGreatJellyfish
## @version 11/17/2026

const UNIT_UI_SCENE_PATH: String = "res://Scenes/BattleUnit/UnitUI.tscn"

## Mid colours of the OutlineGlow presets (see OutlineGlow.apply_preset).
const CRIMSON_MID: Color = Color(0.98, 0.26, 0.24)        # THREAT_CRIMSON
const RUNETERRA_BLUE_MID: Color = Color(0.18, 0.70, 1.00) # RUNETERRA_BLUE


## An enemy with an Ultimate, so `Unit.can_cast_ultimate` can ever become true.
func _make_enemy(max_moxie: int = 20) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = "Normal Enemy"
	data.is_enemy = true
	data.max_moxie = max_moxie
	data.ultimate = SkillData.new()
	return Unit.new(data)


func _make_orb(enemy: Unit) -> MoxieOrbUI:
	var orb: MoxieOrbUI = MoxieOrbUI.new()
	add_child(orb)
	orb.bind_unit(enemy, "E1")
	return orb


## Instantiates a real UnitUI (gDUnit4 frees it again after the test case).
## `setup()` is skipped on purpose: these tests only exercise the intent warning.
func _make_unit_ui(enemy: Unit) -> UnitUI:
	var scene: PackedScene = load(UNIT_UI_SCENE_PATH) as PackedScene
	var node: Node = scene.instantiate()
	add_child(node)
	var ui: UnitUI = node as UnitUI
	ui._bind_unit(enemy)
	return ui


## Reads a shader parameter off the unit's glow, so a test can verify which
## OutlineGlow preset is currently live.
func _glow_param(ui: UnitUI, param: String) -> Variant:
	var mat: ShaderMaterial = ui._glow._mat
	if mat == null:
		return null
	return mat.get_shader_parameter(param)


func test_orb_preview_is_spent_when_the_roll_lands_short() -> void:
	var enemy: Unit = _make_enemy()
	var orb: MoxieOrbUI = _make_orb(enemy)
	orb.set_preview_gain(6)
	assert_int(orb._preview_gain).is_equal(6)

	enemy.gain_moxie(6) # 6/20 - the roll landed, no Ultimate this turn

	assert_int(enemy.moxie).is_equal(6)
	assert_int(orb._preview_gain).is_equal(0)
	assert_bool(orb._should_show_glow()).is_false()


func test_orb_preview_never_double_counts_into_a_false_ready_glow() -> void:
	var enemy: Unit = _make_enemy()
	var orb: MoxieOrbUI = _make_orb(enemy)

	enemy.gain_moxie(14)    # 14/20 charged on an earlier turn
	orb.set_preview_gain(6) # pending roll of 6 -> exactly 20/20
	assert_bool(orb._should_show_glow()).is_true()

	enemy.gain_moxie(6) # the roll lands: 20/20, preview must not linger
	assert_int(enemy.moxie).is_equal(20)
	assert_int(orb._preview_gain).is_equal(0)
	assert_bool(orb._should_show_glow()).is_true()

	enemy.consume_moxie() # the Ultimate is spent
	assert_int(orb._preview_gain).is_equal(0)
	assert_bool(orb._should_show_glow()).is_false()


func test_aura_warns_before_the_roll_then_releases_on_the_cast() -> void:
	var enemy: Unit = _make_enemy()
	var ui: UnitUI = _make_unit_ui(enemy)

	ui.set_intent_ult_warning(true)
	assert_bool(ui._ult_warning_active).is_true()
	assert_bool(ui._glow._active).is_true()
	var warned: Variant = _glow_param(ui, "color_mid")
	assert_bool(warned is Color).is_true()
	var warned_col: Color = warned
	assert_bool(warned_col.is_equal_approx(CRIMSON_MID)).is_true()

	enemy.gain_moxie(20) # the roll lands and fills the gauge
	assert_bool(ui._ult_warning_active).is_false()
	assert_bool(ui._glow._active).is_true() # still one step from the Ultimate

	enemy.consume_moxie() # Ultimate unleashed: the aura must drop
	assert_bool(ui._ult_warning_active).is_false()
	assert_bool(ui._glow._active).is_false()


func test_aura_drops_when_the_roll_lands_short() -> void:
	var enemy: Unit = _make_enemy()
	var ui: UnitUI = _make_unit_ui(enemy)

	ui.set_intent_ult_warning(true)
	assert_bool(ui._glow._active).is_true()

	enemy.gain_moxie(5) # 5/20 - the threat is over

	assert_bool(ui._ult_warning_active).is_false()
	assert_bool(ui._enemy_holds_full_gauge()).is_false()
	assert_bool(ui._glow._active).is_false()


func test_ally_highlights_are_never_rewritten_as_the_enemy_warning() -> void:
	var enemy: Unit = _make_enemy()
	var ui: UnitUI = _make_unit_ui(enemy)

	ui.set_target_highlight(true)
	assert_bool(ui._glow._active).is_true()
	var blue: Variant = _glow_param(ui, "color_mid")
	assert_bool(blue is Color).is_true()
	var blue_col: Color = blue
	assert_bool(blue_col.is_equal_approx(RUNETERRA_BLUE_MID)).is_true()

	# An enemy Moxie change must not steal the friendly highlight preset.
	enemy.gain_moxie(5)
	var still_blue: Variant = _glow_param(ui, "color_mid")
	assert_bool(still_blue is Color).is_true()
	var still_blue_col: Color = still_blue
	assert_bool(still_blue_col.is_equal_approx(RUNETERRA_BLUE_MID)).is_true()
