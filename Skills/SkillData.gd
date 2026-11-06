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
@export var base_effects: Array[SkillEffect] = []
@export var merged_effects: Array[SkillEffect] = []

## For enemy skills: merged_effects trigger when dice value >= this.
## Leave at 0 for ally skills (uses card merge state instead).
@export var condition_threshold: int = 0

var base_categories: PackedStringArray = []
var merged_categories: PackedStringArray = []

## Ensure each instance owns its own arrays 
## (no shared-default-array bug).
func _init() -> void:
	base_effects = []
	merged_effects = []
	
## Helper: Returns the active categories based on current merge status.
## Handles whether 'or' replaces base categories or if 'and' combines them.
func get_active_categories(is_merged: bool) -> PackedStringArray:
	if not is_merged:
		return base_categories
	
	# If the skill completely replaces the base effect on merge (Mode: OR)
	if merged_mode == MergedMode.OR:
		return merged_categories
	
	# If it's additive (AND_MERGED_FIRST or AND_BASE_FIRST), combine them without duplicates
	var combined: PackedStringArray = base_categories.duplicate()
	for cat in merged_categories:
		if not cat in combined:
			combined.append(cat)
	return combined
