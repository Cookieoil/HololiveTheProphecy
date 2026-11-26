class_name GameDatabase
extends Resource

## Skill definitions keyed by skill_id (effects embedded).
@export var skills: Dictionary = {}
## Ally unit templates keyed by unit_id (from allies.json).
@export var allies: Dictionary = {}
## Enemy unit templates keyed by unit_id (from enemies.json).
@export var enemies: Dictionary = {}
## Union of allies and enemies, kept for unit lookups by id.
@export var units: Dictionary = {}
@export var waves: Array = []
@export var config: Dictionary = {}
## Deterministic SHA-256 of the five JSON data files, computed when the database
## is loaded. Two builds with different balance numbers get different hashes, so
## telemetry can partition by balance patch without a manual version bump.
@export var balance_hash: String = ""
## Returns the unit template for an id, or null when unknown.
func get_unit(id: String) -> UnitData:
	if not units.has(id):
		return null
	var unit: UnitData = units[id]
	return unit

## Returns the skill definition for an id, or null when unknown.
func get_skill(id: String) -> SkillData:
	if not skills.has(id):
		return null
	var skill: SkillData = skills[id]
	return skill
