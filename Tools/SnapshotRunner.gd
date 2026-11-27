extends Node
## Renders the canonical battle screens to PNGs for the "align visually" loop.
##
## Every normal gate is headless, and Godot's headless display driver is the dummy
## renderer: it rasterises nothing, so a layout or shader regression cannot show up
## there. This runner opens the real OpenGL (`gl_compatibility`) renderer instead,
## mounts a *seeded* battle, walks it through its canonical states and writes one
## PNG per state under `res://reports/ui-snapshots/` with a manifest.
##
## It is a scene on purpose, not a `--script`: a main-loop script compiles its
## dependencies before the autoload singletons exist, and the battle scene needs
## EventBus/ColorUtils to compile.
##
## Usage (Windows, off-screen, no audio):
##   godot --audio-driver Dummy --position -4000,-4000 --path . \
##     res://Tools/snapshot_runner.tscn
## Usage (CI, on a virtual framebuffer):
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . \
##     res://Tools/snapshot_runner.tscn
##
## Exit code 0 = every shot rendered and passed the sanity checks, 1 otherwise.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const SCENE_PATH: String = "res://Scenes/BattleScene/BattleScene.tscn"
const OUTPUT_DIR: String = "res://reports/ui-snapshots"
const MANIFEST_NAME: String = "manifest.json"
## Throwaway consent file: a capture must never touch the real `user://` answer.
const CONSENT_FILE_NAME: String = "_snapshot_consent.json"
## A fixed seed makes the dealt hand, the rolls and the enemy intents identical on
## every machine, so two captures of the same code are comparable.
const SEED: int = 424242
## Frames to wait after a state changes so layout and the deal animation have
## settled before the pixels are read.
const SETTLE_FRAMES: int = 45
## Hard cap on waiting for a state, so a broken build cannot hang CI forever.
const MAX_WAIT_FRAMES: int = 600
## The project window size the snapshots are taken at.
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## A blank frame is dummy-renderer output; this many distinct sampled colours
## proves the real renderer drew the screen.
const MIN_DISTINCT_COLORS: int = 8
const COLOR_SAMPLE_STEP: int = 24
#endregion

#region Private Variables
var _output_abs: String = ""
var _shots: Array[Dictionary] = []
var _failures: PackedStringArray = PackedStringArray()
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_output_abs = ProjectSettings.globalize_path(OUTPUT_DIR)
	var err: Error = DirAccess.make_dir_recursive_absolute(_output_abs)
	if err != OK:
		push_error("[snapshots] cannot create %s (%s)" % [_output_abs, error_string(err)])
		get_tree().quit(1)
		return
	await _capture()
#endregion

#region Private Methods
func _capture() -> void:
	var scene: BattleScene = _open_scene()
	if scene == null:
		_finish()
		return

	if await _wait_for_consent(scene):
		await _settle()
		_shot("01_consent_modal.png")
		scene.consent_popup.decide(false)
	else:
		_fail("the consent disclosure never opened (run without --headless)")

	if await _wait_for_board(scene):
		await _settle()
		_shot("02_battle_turn_start.png")
	else:
		_fail("the battle board never reached the player-action state")

	if await _show_ultimate_callout(scene):
		await _settle()
		_shot("03_ultimate_callout.png")
		scene.battle_overlay.get_skill_tooltip().hide_callout()
	else:
		_fail("no ally Ultimate orb was available for the callout shot")

	scene.debug_menu.open_menu()
	await _settle()
	_shot("04_debug_menu.png")
	scene.debug_menu.close_menu()

	await scene.show_battle_result(true)
	await _settle()
	_shot("05_victory_cutscene.png")

	_finish()


func _open_scene() -> BattleScene:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("cannot load %s" % SCENE_PATH)
		return null
	var scene: BattleScene = packed.instantiate() as BattleScene
	if scene == null:
		_fail("the root of %s is not a BattleScene" % SCENE_PATH)
		return null
	scene.fixed_seed_override = SEED
	scene.consent_path_override = _output_abs.path_join(CONSENT_FILE_NAME)
	add_child(scene)
	return scene


func _wait_frames(count: int) -> void:
	for i: int in range(count):
		await RenderingServer.frame_post_draw


func _settle() -> void:
	await _wait_frames(SETTLE_FRAMES)


func _wait_for_consent(scene: BattleScene) -> bool:
	for i: int in range(MAX_WAIT_FRAMES):
		await RenderingServer.frame_post_draw
		if scene.consent_popup != null and scene.consent_popup.is_open():
			return true
	return false


func _wait_for_board(scene: BattleScene) -> bool:
	for i: int in range(MAX_WAIT_FRAMES):
		await RenderingServer.frame_post_draw
		if _board_is_ready(scene):
			return true
	return false


func _board_is_ready(scene: BattleScene) -> bool:
	if scene.game_manager == null or scene.game_manager.state == null:
		return false
	return scene.game_manager.state.hand.size() > 0


func _show_ultimate_callout(scene: BattleScene) -> bool:
	for i: int in range(MAX_WAIT_FRAMES):
		if scene.battle_overlay.show_ally_ultimate_callout(0):
			return true
		await RenderingServer.frame_post_draw
	return false


func _shot(file_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		_fail("%s: the root viewport produced no image" % file_name)
		return
	if image.get_width() != WINDOW_SIZE.x or image.get_height() != WINDOW_SIZE.y:
		_fail("%s: expected %dx%d, got %dx%d" % [
			file_name,
			WINDOW_SIZE.x,
			WINDOW_SIZE.y,
			image.get_width(),
			image.get_height(),
		])
		return
	var path: String = _output_abs.path_join(file_name)
	var err: Error = image.save_png(path)
	if err != OK:
		_fail("%s: save_png failed (%s)" % [file_name, error_string(err)])
		return
	var distinct: int = _distinct_colors(image)
	if distinct < MIN_DISTINCT_COLORS:
		_fail("%s: only %d distinct sampled colours - the frame is blank" % [file_name, distinct])
		return
	_shots.append({
		"file": file_name,
		"width": image.get_width(),
		"height": image.get_height(),
		"bytes": _file_size(path),
		"sha256": FileAccess.get_sha256(path),
	})
	print("[snapshots] %s (%d distinct colours)" % [file_name, distinct])


## Coarse colour census: real UI art has many distinct sampled colours, a dummy or
## all-black frame has one. Cheap enough to run on every shot.
func _distinct_colors(image: Image) -> int:
	var seen: Dictionary = {}
	var y: int = 0
	while y < image.get_height():
		var x: int = 0
		while x < image.get_width():
			seen[image.get_pixel(x, y).to_rgba32()] = true
			x += COLOR_SAMPLE_STEP
		y += COLOR_SAMPLE_STEP
	return seen.size()


func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = file.get_length()
	file.close()
	return size


func _write_manifest() -> void:
	var manifest: Dictionary = {
		"seed": SEED,
		"window": {"width": WINDOW_SIZE.x, "height": WINDOW_SIZE.y},
		"shots": _shots,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(_output_abs.path_join(MANIFEST_NAME), FileAccess.WRITE)
	if file == null:
		_fail("cannot write %s" % MANIFEST_NAME)
		return
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[snapshots] %s" % message)


func _finish() -> void:
	_write_manifest()
	if _failures.is_empty():
		print("[snapshots] %d shot(s) written to %s" % [_shots.size(), OUTPUT_DIR])
		get_tree().quit(0)
		return
	print("[snapshots] FAILED: %d problem(s)" % _failures.size())
	get_tree().quit(1)
#endregion
