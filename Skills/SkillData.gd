class_name SkillData
extends Resource
## Defines one skill slot (Skill 1 or Skill 2) on a unit
## Holds arrays of effects for unmerged and merged resolution
##
## @author TheGreatJellyfish
## @version 5/11/2026

enum MergedMode {
	AND,    # Merged effects, then base effects
	INSTEAD,# Only merged effect
}

@export var skill_name: String = ""
@export var description: String = ""
@export var merged_description: String = ""
@export var merged_mode: MergedMode = MergedMode.AND

## Populated via inspector (.tres) or code.
@export var base_effects: Array[SkillEffect] = []
@export var merged_effects: Array[SkillEffect] = []

## For enemy skills: merged_effects trigger when dice value >= this.
## Leave at 0 for ally skills (uses card merge state instead).
@export var condition_threshold: int = 0

@export var base_effect: Array[SkillEffect] = []
@export var merged_effect: Array[SkillEffect] = []

## Ensure each instance owns its own arrays 
## (no shared-default-array bug).
func _init() -> void:
	base_effects = []
	merged_effects = []
