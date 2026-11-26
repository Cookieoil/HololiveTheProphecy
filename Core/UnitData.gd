class_name UnitData
extends Resource
## Template definition for a unit type.
##
## @author TheGreatJellyfish
## @version 5/11/2026

## Stable id from allies.json / enemies.json (e.g. "striker", "boss_enemy").
## Unlike display_name it is never localised or overridden by a wave, so
## telemetry and save data can key on it across renames.
@export var unit_id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 10
@export var portrait: Texture2D = null
@export var skill_1: SkillData = null
@export var skill_2: SkillData = null
@export var ultimate: SkillData = null
@export var max_moxie: int = 20
@export var is_enemy: bool = false
