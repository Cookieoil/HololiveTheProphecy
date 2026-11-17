# CardIconCatalog.gd
class_name CardIconCatalog
extends Resource
## Central skill-type icon registry for cards / skill previews.
## One instance, set as project autoload or exported on UI roots.
## No res://Trash paths live in class code.
##
## Renamed from IconCatalog (kept the same UID so existing scenes/resources
## keep resolving). Behaviour is unchanged.

@export var icons: Dictionary = {}    # StringName -> Texture2D

func get_icon(category: StringName) -> Texture2D:
	return icons.get(category, null)
