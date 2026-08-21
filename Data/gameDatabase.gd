class_name GameDatabase
extends Resource

func _init() -> void:
	if Engine.is_editor_hint():
		print("[GameDatabase] _init, script path = ", get_script().resource_path if get_script() else "NONE")
		
@export var units: Dictionary = {}
@export var waves: Array = []
@export var config: Dictionary = {}
func get_unit(id: String) -> UnitData: return units.get(id)
