class_name JsonlFileSink
extends TelemetrySink
## Stage 1 telemetry sink: appends one JSON object per line to a per-run file
## under user://telemetry/spool/. Every line is flushed as it is written, so a
## crash or an alt-F4 loses at most the event being written, never the session.
##
## The spool is written in user:// (never res://) and is deliberately outside the
## project tree so a build can never ship a player's own log with the game.
##
## @author TheGreatJellyfish
## @version 11/26/2026

#region Constants
const DEFAULT_DIR: String = "user://telemetry/spool"
const FILE_PREFIX: String = "run_"
const FILE_SUFFIX: String = ".jsonl"
#endregion

#region Public Variables
var dir_path: String = DEFAULT_DIR
var file_path: String = ""
var event_count: int = 0
#endregion

#region Private Variables
var _file: FileAccess = null
#endregion

#region Lifecycle Methods
func _init(p_dir_path: String = DEFAULT_DIR, run_id: String = "") -> void:
	dir_path = p_dir_path
	if not run_id.is_empty():
		open(run_id)
#endregion

#region Public Methods
## Truncates (or creates) the spool file for one run id.
func open(run_id: String) -> void:
	close()
	_ensure_dir()
	file_path = "%s/%s%s%s" % [dir_path, FILE_PREFIX, run_id, FILE_SUFFIX]
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	event_count = 0


func write_event(event: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify(event))
	_file.flush()
	event_count += 1


func flush() -> void:
	if _file != null:
		_file.flush()


func close() -> void:
	if _file != null:
		_file.close()
		_file = null


func is_open() -> bool:
	return _file != null


## Reads every event back (used by the analyser and by tests).
func read_all() -> Array:
	var events: Array = []
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return events
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return events
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			events.append(parsed)
	file.close()
	return events
#endregion

#region Private Methods
func _ensure_dir() -> void:
	var global_dir: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_recursive_absolute(global_dir)
#endregion
