<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryFoundationTest.gd` — `class_name TelemetryFoundationTest` extends `GdUnitTestSuite`

`60` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the data foundation the telemetry system keys on: every UnitData and SkillData carries its stable id from the JSON (unit_id / skill_id), wave overrides ne…

Public API:
- L14-19 `test_units_carry_stable_ids() -> void` — Every unit template must expose the JSON key it was loaded from, so telemetry can key on "boss_enemy" even after the display name changes.
- L24-31 `test_skills_carry_stable_ids() -> void` — Every skill must expose the JSON key it was loaded from, independent of the human-readable skill_name.
- L36-44 `test_wave_override_keeps_unit_id() -> void` — A wave override may rename and resize an enemy, but the stable id must survive the clone so the metric server still sees "boss_enemy" behind "Sample Boss".
- L49-53 `test_balance_hash_is_deterministic() -> void` — The balance hash must be a stable 64-char SHA-256 and must be identical across two independent loads of the same files.
- L58-59 `test_balance_hash_handles_missing_file() -> void` — A missing data file must not crash the hash (it hashes an empty part instead) so the loader keeps reporting the real problem through get_errors().

Uses: DataLoader, GameDatabase, SkillData, UnitData
Used by: —
Loads: res://Data/json/does_not_exist.json

