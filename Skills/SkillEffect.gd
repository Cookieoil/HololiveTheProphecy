class_name SkillEffect
extends Resource
## Abstract base for all skill effect components.
## Subclasses override execute().
## The GameManager always calls: await effect.execute(ctx).
##
## Note: This base shouldn't contains any enums or resolver logic.
## Those should be in EffectBlock.gd instead.
##
## @author TheGreatJellyfish
## @version 5/29/2026

func execute(_ctx: SkillContext) -> void:
	push_warning("SkillEffect.execute() not overridden: %s" % resource_path)
	

## Auto-description for inspectation/debug
func get_description() -> String:
	return "(base effect - no description)"
