@tool
extends EditorPlugin

const XlsxImportPlugin := preload("res://addons/xlsx_importPlugin/xlsx_importPlugin.gd")

var import_plugin: EditorImportPlugin

func _enter_tree() -> void:
	import_plugin = XlsxImportPlugin.new()
	add_import_plugin(import_plugin)
	print("[xlsx-plugin] import plugin registered")

func _exit_tree() -> void:
	if import_plugin:
		remove_import_plugin(import_plugin)
		import_plugin = null
