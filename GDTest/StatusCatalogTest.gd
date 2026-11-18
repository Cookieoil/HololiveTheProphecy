class_name StatusCatalogTest
extends GdUnitTestSuite
## Tests for the buff/debuff status system: Unit.statuses + StatusIconCatalog.
##
## @author TheGreatJellyfish
## @version 11/16/2026

const CATALOG_PATH: String = "res://Scenes/BattleScene/Assets/StatusIcons.tres"

## Builds a throwaway unit for status tests.
func _make_unit(max_hp: int = 20) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = "Test Unit"
	data.max_hp = max_hp
	return Unit.new(data, 0)


func test_catalog_resolves_sample_icons() -> void:
	var catalog: StatusIconCatalog = load(CATALOG_PATH) as StatusIconCatalog
	assert_bool(catalog != null).is_true()
	# Both sample files (128x128 SVG and 1000x1000 PNG) must resolve.
	assert_bool(catalog.get_status_icon("regeneration") != null).is_true()
	assert_bool(catalog.get_status_icon("gloom") != null).is_true()
	# Unknown ids fall back to the default icon instead of returning null.
	assert_bool(catalog.get_status_icon("brand_new_status") != null).is_true()
	assert_bool(catalog.is_debuff_id("gloom")).is_true()
	assert_bool(catalog.is_debuff_id("regeneration")).is_false()


func test_regeneration_counts_down_and_heals() -> void:
	var unit: Unit = _make_unit(20)
	assert_int(unit.apply_status("regeneration", 3)).is_equal(3)

	unit.current_hp = 10
	unit.tick_round_end_statuses()
	assert_int(unit.current_hp).is_equal(13)
	assert_int(unit.get_status_count("regeneration")).is_equal(2)

	unit.tick_round_end_statuses()
	unit.tick_round_end_statuses()
	assert_bool(unit.has_status("regeneration")).is_false()


func test_gloom_stacks_and_damages() -> void:
	var unit: Unit = _make_unit(20)
	unit.apply_status("gloom", 2)
	# Stacking is case/space insensitive.
	assert_int(unit.apply_status(" GLOOM ", 2)).is_equal(4)

	unit.current_hp = 12
	unit.tick_round_end_statuses()
	# 4 stacks = 4 true damage, and stacks persist.
	assert_int(unit.current_hp).is_equal(8)
	assert_int(unit.get_status_count("gloom")).is_equal(4)


func test_statuses_clear_when_a_unit_dies() -> void:
	var unit: Unit = _make_unit(5)
	unit.apply_status("gloom", 9)
	unit.tick_round_end_statuses()
	assert_bool(unit.is_dead).is_true()
	assert_int(unit.statuses.size()).is_equal(0)
	# Dead units reject new statuses.
	assert_int(unit.apply_status("regeneration", 3)).is_equal(0)


func test_catalog_extracts_buff_and_debuff() -> void:
	var catalog: StatusIconCatalog = load(CATALOG_PATH) as StatusIconCatalog
	var unit: Unit = _make_unit(12)
	unit.apply_status("regeneration", 3)
	unit.apply_status("gloom", 2)

	var statuses: Array[Dictionary] = catalog.extract_unit_statuses(unit)
	assert_int(statuses.size()).is_equal(2)
	for entry: Dictionary in statuses:
		var status_id: String = str(entry.get("id", ""))
		var count: int = entry.get("count", 0)
		var is_debuff: bool = entry.get("is_debuff", false)
		var icon_raw: Variant = entry.get("icon", null)
		assert_bool(icon_raw is Texture2D).is_true()
		if status_id == "gloom":
			assert_int(count).is_equal(2)
			assert_bool(is_debuff).is_true()
		elif status_id == "regeneration":
			assert_int(count).is_equal(3)
			assert_bool(is_debuff).is_false()

	# Dead units expose no badges.
	unit.current_hp = 0
	assert_int(catalog.extract_unit_statuses(unit).size()).is_equal(0)
