extends Node
## Replays a run seed headlessly, or sweeps a range of seeds, and prints what happened.
##
## A seed is only worth recording if it can be re-run, and this is the command that does
## it: a seed from a telemetry report (the triage output lists them) or from a bug report
## can be played back here, and its per-turn trace compared with the report. It runs the
## shipped battle through Tools/BattleSimulator.gd, the same harness the determinism test
## uses, so the seed replayed here is the seed that suite pins.
##
## Usage:
##   godot --headless --path . res://Tools/simulate_runs.tscn -- --seed 20260101
##   godot --headless --path . res://Tools/simulate_runs.tscn -- --seeds 50
##   godot --headless --path . res://Tools/simulate_runs.tscn -- --seed 7 --flag my_experiment
##
## `--seed N` replays one seed and prints its trace; `--seeds N` sweeps N seeds starting
## at `--seed` (default 20260101) and prints a summary. `--flag NAME` (repeatable) forces
## a staged feature flag on, the same way `BattleScene.flag_overrides` does.
##
## Exit code 0 = every run finished with the board's invariants intact, 1 otherwise.
##
## It is a scene on purpose, not a `--script`: a main-loop script compiles its
## dependencies before the autoload singletons exist, and GameManager needs EventBus and
## ColorUtils to compile.
##
## @author TheGreatJellyfish
## @version 11/28/2026


#region Constants
## The seed a run falls back to when the command line gives none.
const DEFAULT_SEED: int = 20260101
## The longest trace printed for a single seed, so one runaway run cannot flood a log.
const TRACE_LIMIT: int = 40
## Frames one run may take before the command gives up, so a battle that cannot end (a
## balance bug) fails instead of hanging the shell.
const WATCHDOG_FRAMES: int = 600
## The flag that forces a staged feature flag on for the run.
const ARG_FLAG: String = "--flag"
#endregion


#region Private Variables
var _failures: PackedStringArray = PackedStringArray()
## Frames left before the current run is declared stuck; 0 disarms the watchdog.
var _watchdog: int = 0
var _running_seed: int = 0
#endregion


#region Lifecycle Methods
func _ready() -> void:
	var seed_value: int = _arg_int("--seed", DEFAULT_SEED)
	var sweep: int = _arg_int("--seeds", 0)
	if sweep > 0:
		await _sweep(seed_value, sweep)
	else:
		await _replay(seed_value)
	_finish()


func _process(_delta: float) -> void:
	if _watchdog <= 0:
		return
	_watchdog -= 1
	if _watchdog == 0:
		printerr("[simulate] seed %d never ended: giving up" % _running_seed)
		get_tree().quit(1)
#endregion


#region Private Methods
## One seed, printed turn by turn: the shape a bug report needs.
func _replay(seed_value: int) -> void:
	var sim: BattleSimulator = await _run(seed_value)
	if sim == null:
		return
	print("[simulate] seed %d" % seed_value)
	_print_trace(sim)
	_report(seed_value, sim)
	sim.queue_free()


## N seeds from `seed_value`, summarised: how the runs ended, and whether any of them left
## the board inconsistent.
func _sweep(seed_value: int, count: int) -> void:
	var victories: int = 0
	for offset: int in count:
		var sim: BattleSimulator = await _run(seed_value + offset)
		if sim == null:
			continue
		if not sim.manager.state.all_allies_dead():
			victories += 1
		_report(seed_value + offset, sim)
		sim.queue_free()
	print("[simulate] %d seed(s) from %d: %d victory(ies), %d defeat(s)" % [
		count, seed_value, victories, count - victories
	])


## Runs one shipped battle with the watchdog armed, or null when it had to be abandoned.
func _run(seed_value: int) -> BattleSimulator:
	_running_seed = seed_value
	var sim: BattleSimulator = BattleSimulator.new()
	add_child(sim)
	_watchdog = WATCHDOG_FRAMES
	await sim.run_shipped(seed_value, _flags())
	_watchdog = 0
	return sim


## Records anything wrong with a finished run: a broken invariant, a card that leaked, or
## a battle that never ended.
func _report(seed_value: int, sim: BattleSimulator) -> void:
	if not sim.recorder.violation.is_empty():
		_fail("seed %d: %s" % [seed_value, sim.recorder.violation])
	if not sim.recorder.card_leak.is_empty():
		_fail("seed %d: %s" % [seed_value, sim.recorder.card_leak])
	if sim.manager.game_running:
		_fail("seed %d never finished" % seed_value)


## The per-turn trace, so a reported board can be compared against the replay's.
func _print_trace(sim: BattleSimulator) -> void:
	var trace: PackedStringArray = sim.recorder.trace
	var shown: int = mini(trace.size(), TRACE_LIMIT)
	for index: int in shown:
		print("  %2d. %s" % [index + 1, trace[index]])
	if trace.size() > shown:
		print("  ... %d more decision(s)" % (trace.size() - shown))
	var outcome: String = "defeat" if sim.manager.state.all_allies_dead() else "victory"
	print("  %s after %d decision(s) over %d turn(s)" % [
		outcome, trace.size(), sim.manager.state.turn_number
	])


## `--flag NAME` (repeatable) forces a staged feature flag on for this run.
func _flags() -> Dictionary:
	var forced: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == ARG_FLAG and index + 1 < args.size():
			forced[args[index + 1]] = true
	return forced


## The integer value after `name` on the command line, or `fallback`.
func _arg_int(name: String, fallback: int) -> int:
	var raw: String = _arg_value(name, "")
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		_fail("%s expects a number, got '%s'" % [name, raw])
		return fallback
	return raw.to_int()


## The value after `name` on the command line, or `fallback`.
func _arg_value(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	for failure: String in _failures:
		printerr("[simulate] %s" % failure)
	if _failures.is_empty():
		print("[simulate] every run finished with the board intact")
		get_tree().quit(0)
		return
	print("[simulate] FAILED: %d problem(s)" % _failures.size())
	get_tree().quit(1)
#endregion
