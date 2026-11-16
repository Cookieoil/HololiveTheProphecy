class_name UnitData
extends Resource
## Template definition for a unit type.
##
## @author TheGreatJellyfish
## @version 5/11/2026

@export var display_name: String = ""
@export var max_hp: int = 10
@export var portrait: Texture2D = null
@export var skill_1: SkillData = null
@export var skill_2: SkillData = null
@export var ultimate: SkillData = null
@export var max_moxie: int = 20
@export var is_enemy: bool = false
