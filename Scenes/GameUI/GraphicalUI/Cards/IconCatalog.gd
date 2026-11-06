# icon_catalog.gd
class_name IconCatalog
extends Resource
## Central skill-type icon registry. One instance, set as project autoload
## or exported on UI roots. No res://Trash paths live in class code.

@export var icons: Dictionary = {}    # StringName -> Texture2D

func get_icon(category: StringName) -> Texture2D:
	return icons.get(category, null)
