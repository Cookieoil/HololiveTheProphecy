class_name TelemetryFoundationTest
extends GdUnitTestSuite
## Locks the data foundation the telemetry system keys on: every UnitData and
## SkillData carries its stable id from the JSON (unit_id / skill_id), wave
## overrides never lose the id, and GameDatabase.balance_hash is a deterministic
## SHA-256 of the five data files.
##
## @author TheGreatJellyfish
## @version 11/26/2026


## Every unit template must expose the JSON key it was loaded from, so telemetry
## can key on "boss_enemy" even after the display name changes.
func test_units_carry_stable_ids() -> void:
	var db: GameDatabase = DataLoader.db()
	assert_bool(db.allies.has("striker")).is_true()
	for unit_id: String in db.units:
		var unit: UnitData = db.units[unit_id]
		assert_str(unit.unit_id).is_equal(unit_id)


## Every skill must expose the JSON key it was loaded from, independent of the
## human-readable skill_name.
func test_skills_carry_stable_ids() -> void:
	var db: GameDatabase = DataLoader.db()
	assert_bool(db.skills.has("striker_1")).is_true()
	for skill_id: String in db.skills:
		var skill: SkillData = db.skills[skill_id]
		assert_str(skill.skill_id).is_equal(skill_id)
	assert_str(db.skills["striker_1"].skill_name).is_equal("Skill 1 (odd)")
	assert_str(db.skills["striker_1"].skill_id).is_equal("striker_1")


## A wave override may rename and resize an enemy, but the stable id must survive
## the clone so the metric server still sees "boss_enemy" behind "Sample Boss".
func test_wave_override_keeps_unit_id() -> void:
	var db: GameDatabase = DataLoader.db()
	var found_overridden: bool = false
	for wave: Array in db.waves:
		for unit: UnitData in wave:
			if unit.is_enemy and unit.unit_id == "boss_enemy" and unit.display_name != "Boss Enemy":
				found_overridden = true
				assert_str(unit.unit_id).is_equal("boss_enemy")
	assert_bool(found_overridden).is_true()


## The balance hash must be a stable 64-char SHA-256 and must be identical across
## two independent loads of the same files.
func test_balance_hash_is_deterministic() -> void:
	var first: String = DataLoader.load_database().balance_hash
	var second: String = DataLoader.load_database().balance_hash
	assert_int(first.length()).is_equal(64)
	assert_str(first).is_equal(second)


## A missing data file must not crash the hash (it hashes an empty part instead)
## so the loader keeps reporting the real problem through get_errors().
func test_balance_hash_handles_missing_file() -> void:
	assert_str(DataLoader._read_text("res://Data/json/does_not_exist.json")).is_empty()
