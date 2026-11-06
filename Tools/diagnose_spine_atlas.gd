extends SceneTree

const ROOT := "res://Scenes/GameUI/GraphicalUI/BattleUnit/Spine/300101_zhujue"
const PNG_PATH := ROOT + "/300101_zhujue.png"
const ATLAS_PATH := ROOT + "/300101_zhujue.atlas"

func _initialize() -> void:
	print("Godot version: ", Engine.get_version_info())

	# Test the PNG directly from disk, independently of Godot's texture importer.
	var image := Image.new()
	var image_error := image.load(PNG_PATH)
	print("PNG Image.load error: ", image_error)
	print("PNG Image size: ", image.get_size())

	# Test Godot's imported Texture2D.
	var texture := ResourceLoader.load(
		PNG_PATH,
		"Texture2D",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	print("Imported Texture2D: ", texture)
	if texture is Texture2D:
		print("Imported Texture2D size: ", texture.get_size())

	# Bypass the .spatlas and parse the original .atlas directly.
	print("=== BEGIN RAW ATLAS TEST ===")
	var raw_atlas := SpineAtlasResource.new()
	var raw_error := raw_atlas.load_from_atlas_file(ATLAS_PATH)
	print("Raw atlas error: ", raw_error)
	print("Raw atlas textures: ", raw_atlas.get_textures().size())
	print("=== END RAW ATLAS TEST ===")

	# Load through the .atlas.import -> .spatlas remap.
	print("=== BEGIN IMPORTED ATLAS TEST ===")
	var imported_atlas := ResourceLoader.load(
		ATLAS_PATH,
		"SpineAtlasResource",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	print("Imported atlas: ", imported_atlas)

	if imported_atlas is SpineAtlasResource:
		print("Imported source path: ", imported_atlas.get_source_path())
		print("Imported atlas textures: ", imported_atlas.get_textures().size())

	print("=== END IMPORTED ATLAS TEST ===")
	quit()