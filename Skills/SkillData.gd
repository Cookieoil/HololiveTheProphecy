class_name SkillData
extends Resource
## Defines one skill slot (Skill 1 or Skill 2) on a unit
## Holds arrays of effects for unmerged and merged resolution
##
## @author TheGreatJellyfish
## @version 5/11/2026

enum MergedMode {
	AND_MERGED_FIRST,	# Merged effects, then base effects
	AND_BASE_FIRST, 	# Base effects first, then merged effects (for "that target" follow-ups)
	OR,					# Only merged effect
}

@export var skill_name: String = ""
@export var description: String = ""
@export var merged_description: String = ""
@export var merged_mode: MergedMode = MergedMode.AND_MERGED_FIRST

## Populated via inspector (.tres) or code.
@export var base_effects: Array[SkillEffect] = []
@export var merged_effects: Array[SkillEffect] = []

## For enemy skills: merged_effects trigger when dice value >= this.
## Leave at 0 for ally skills (uses card merge state instead).
@export var condition_threshold: int = 0

## Ensure each instance owns its own arrays 
## (no shared-default-array bug).
func _init() -> void:
	base_effects = []
	merged_effects = []
