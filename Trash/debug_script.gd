@tool
extends EditorScript

func _run() -> void:
	var p := "res://.godot/imported/game_data.xlsx-6c069a5764b3ac5dc02c5ae55c9a3bdd.res"
	var r := ResourceLoader.load(p)     # no type hint
	print("direct load: ", r, " script: ", (r.get_script() if r else "N/A"))
