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
## Add `--fixed-fps 60` when the shots are going to be compared rather than looked at:
## the frame delta stops depending on how fast the machine is, which is what makes two
## captures of the same code comparable pixel for pixel (Tools/compare_snapshots.py).
##
## Add `-- --output-dir <path>` to write somewhere other than reports/ui-snapshots/, so a
## branch can be captured next to its baseline (`.../before`, `.../after`).
##
## Exit code 0 = every shot rendered and passed the sanity checks, 1 otherwise.
##
## @author TheGreatJellyfish
## @version 11/28/2026

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
## Short settles for the shots that photograph something mid-animation (a cast ripple, a
## card in flight). At 60 frames a second these are fractions of a second by design.
const EFFECT_SETTLE_FRAMES: int = 12
const FLIGHT_SETTLE_FRAMES: int = 16
## Stagger between two cards leaving the deck, in seconds, for the deal-in shot. Chosen
## so one frame catches several different points of the flight (see `_capture_card_flight`).
const FLIGHT_STAGGER: float = 0.08
const ARG_OUTPUT_DIR: String = "--output-dir"

#endregion

#region Private Variables
var _output_abs: String = ""
var _shots: Array[Dictionary] = []
var _failures: PackedStringArray = PackedStringArray()
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_output_abs = ProjectSettings.globalize_path(_output_dir())
	var err: Error = DirAccess.make_dir_recursive_absolute(_output_abs)
	if err != OK:
		push_error("[snapshots] cannot create %s (%s)" % [_output_abs, error_string(err)])
		get_tree().quit(1)
		return
	await _capture()
#endregion

#region Private Methods
## `--output-dir <path>` when the caller wants the shots somewhere else, else the default.
## Accepts a `res://` path or an absolute one, like Tools/gen_code_index.gd does.
func _output_dir() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == ARG_OUTPUT_DIR and i + 1 < args.size():
			return args[i + 1]
	return OUTPUT_DIR

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
	# Same panel, on the Flags tab: the staged-flag toggles and their descriptions are
	# the one tool that only makes sense visible.
	if scene.debug_menu.show_tab("Flags"):
		await _settle()
		_shot("05_debug_flags.png")
	else:
		_fail("the debug palette has no Flags tab")
	scene.debug_menu.close_menu()

	# The combat states a normal turn passes through too quickly to photograph. They are
	# driven from here rather than played out, and they are captured on the live board
	# because that is where the rails, the auras and the tooltip layer actually are.
	await _capture_orb_states(scene)
	await _capture_cast_effects(scene)
	await _capture_card_flight(scene)

	await scene.show_battle_result(true)
	await _settle()
	_shot("09_victory_cutscene.png")

	_finish()


## A charged ally orb (ready bezel, glow, full ring) next to an enemy one roll away from
## its Ultimate (warning bezel, crimson aura, preview segment). Neither state survives a
## whole turn of ordinary play, and both are pure `_draw`/shader work - exactly what a
## refactor of the orb can break without touching a single assertion.
func _capture_orb_states(scene: BattleScene) -> void:
	var allies: Array[UnitUI] = _unit_uis(scene, true)
	var enemies: Array[UnitUI] = _unit_uis(scene, false)
	if allies.is_empty() or enemies.is_empty():
		_fail("the board has no UnitUI nodes to charge")
		return

	_fill_moxie(allies[0])
	var enemy: UnitUI = enemies[0]
	# Six short of the gauge, so the pending roll is what would fill it: the orb draws a
	# preview segment and the character wears the warning aura.
	enemy.unit.gain_moxie(maxi(0, enemy.unit.max_moxie - 6))
	var orb: MoxieOrbUI = _orb_for(scene, enemy.unit)
	if orb != null:
		orb.set_preview_gain(6)
	enemy.set_intent_ult_warning(true)

	await _settle()
	_shot("06_orb_states.png")


## The two effects that only exist mid-animation: the cast ripple on every orb, and the
## callout anchored close enough to the right edge that its beak flips to the far side of
## the panel. Shot 03 captures the other beak orientation.
func _capture_cast_effects(scene: BattleScene) -> void:
	for orb: MoxieOrbUI in _orbs(scene):
		orb.play_cast_burst()
	# Placed by hand: the flip is a placement decision, and this is the only way to reach
	# the other branch of it without moving the battle camera.
	scene.battle_overlay.get_skill_tooltip().show_callout(
		_callout_data(), Rect2(Vector2(1230.0, 300.0), Vector2(40.0, 40.0))
	)
	await _wait_frames(EFFECT_SETTLE_FRAMES)
	_shot("07_cast_effects.png")
	scene.battle_overlay.get_skill_tooltip().hide_callout()


## The deal, caught in the air. The stagger is the point: at this frame the cards are at
## several different points of the flight, so one shot covers the pose math at once
## instead of photographing the same instant twice.
func _capture_card_flight(scene: BattleScene) -> void:
	var cards: Array[CardUI] = []
	for child: Node in scene.hand_bar.cards_row.get_children():
		var ui: CardUI = child as CardUI
		if ui != null:
			cards.append(ui)
	if cards.is_empty():
		_fail("the hand is empty, so there is nothing to deal")
		return
	for i: int in range(cards.size()):
		cards[i].play_draw_animation(Vector2(700.0, -40.0), FLIGHT_STAGGER * float(i), i)
	await _wait_frames(FLIGHT_SETTLE_FRAMES)
	_shot("08_card_flight.png")
	# Let the deal land flat again, so the cutscene above is photographed on a settled
	# board rather than through a card still in mid-air.
	await _settle()


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


## The UnitUI nodes of one side, read off the row containers the scene already owns.
func _unit_uis(scene: BattleScene, allies: bool) -> Array[UnitUI]:
	var found: Array[UnitUI] = []
	var container: Node = scene.allies_container if allies else scene.enemies_container
	if container == null:
		return found
	for child: Node in container.get_children():
		var ui: UnitUI = child as UnitUI
		if ui != null:
			found.append(ui)
	return found


## Every orb on the board, in tree order. Found by class rather than by walking the
## overlay's private rails, so the search does not depend on how the rails are built.
func _orbs(scene: BattleScene) -> Array[MoxieOrbUI]:
	var found: Array[MoxieOrbUI] = []
	for node: Node in scene.battle_overlay.find_children("*", "MoxieOrbUI", true, false):
		var orb: MoxieOrbUI = node as MoxieOrbUI
		if orb != null:
			found.append(orb)
	return found


func _orb_for(scene: BattleScene, unit: Unit) -> MoxieOrbUI:
	for orb: MoxieOrbUI in _orbs(scene):
		if orb.unit == unit:
			return orb
	return null


## Fills a unit's gauge, which is what turns its orb "ready" and lights the glow preset.
func _fill_moxie(ui: UnitUI) -> void:
	if ui == null or ui.unit == null:
		return
	ui.unit.gain_moxie(maxi(0, ui.unit.max_moxie - ui.unit.moxie))


## Content for the flipped callout: the same shape the overlay builds for a skill, so the
## shot shows a real panel rather than an empty one.
func _callout_data() -> Dictionary:
	return {
		"header": "E1 · Normal Enemy",
		"subtitle": "Ultimate · 20 Moxie",
		"body": "Deal 6 Damage to all allies and apply [b]Gloom[/b] for 2 turns.",
		"footer": "Moxie: 14 / 20 (+6 roll preview)",
		"accent": Color(1.0, 0.34, 0.32),
	}



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
		print("[snapshots] %d shot(s) written to %s" % [_shots.size(), _output_dir()])
		get_tree().quit(0)
		return
	print("[snapshots] FAILED: %d problem(s)" % _failures.size())
	get_tree().quit(1)
#endregion
