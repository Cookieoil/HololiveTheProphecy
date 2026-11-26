class_name TelemetryConsent
extends RefCounted
## Explicit opt-in gate for gameplay telemetry.
##
## The player is asked on every launch, before the first battle starts: nothing is
## collected until they press "Allow", and "Decline" leaves the recorder a complete
## no-op. A scene reload ("Play Again") belongs to the same launch and is not asked
## again - that is the popup's launch flag, not this record.
##
## This class is the *record* of the answer. It is written to a tiny JSON file under
## user:// (never in res://), so the last answer survives a restart and can be
## re-read when a battle starts; `CONSENT_VERSION` marks which disclosure wording the
## stored answer belongs to.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Enums
enum Status {
	UNDECIDED = 0,
	GRANTED = 1,
	DECLINED = 2,
}
#endregion

#region Constants
## Bump this when the disclosure text changes so the stored answer is recognisably
## older than the wording it was given for.
## v2: the window was restyled and the wording became "Data Consent / I need your
## consent to collect anonymous gameplay data / ... None of your personal data will
## be recorded".
const CONSENT_VERSION: int = 2
const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://telemetry_consent.json"
const STATUS_GRANTED: String = "granted"
const STATUS_DECLINED: String = "declined"
#endregion

#region Public Variables
## Where this record reads and writes its answer. Every mutating method defaults
## to it, so a caller can point one instance at a throwaway file (a test) without
## passing the path around.
var storage_path: String = DEFAULT_PATH
var status: int = Status.UNDECIDED
var consent_version: int = 0
var decided_at_unix: float = 0.0
#endregion

#region Private Variables
## True once the player has answered in *this* launch. A stored "granted" from an
## earlier session must never be enough on its own: the recorder waits for this
## launch's answer, which is what guarantees nothing is collected before the player
## has been asked.
static var _answered_this_launch: bool = false
#endregion

#region Lifecycle Methods
## Loads the stored answer, or starts UNDECIDED when nothing was saved yet.
func _init(path: String = DEFAULT_PATH) -> void:
	storage_path = path
	load_from_path(storage_path)
#endregion

#region Public Methods
## True when the player answered the disclosure during this launch.
##
## A stored "granted" from an earlier session is deliberately not enough: the
## recorder requires this, so nothing can be collected before the player has been
## asked in the session that is running.
static func answered_this_launch() -> bool:
	return _answered_this_launch


## Test seam: forgets that this launch was answered.
static func reset_launch_flag() -> void:
	_answered_this_launch = false


## True once the player answered the current disclosure version.
func is_decided() -> bool:
	return status != Status.UNDECIDED and consent_version >= CONSENT_VERSION


## True while the disclosure still has to be shown.
func needs_prompt() -> bool:
	return not is_decided()


## True only for the explicit "Agree" answer of the current version.
func is_granted() -> bool:
	return status == Status.GRANTED and consent_version >= CONSENT_VERSION


## Stores the answer and persists it. Passing false keeps collection fully off.
func decide(agreed: bool) -> void:
	status = Status.GRANTED if agreed else Status.DECLINED
	consent_version = CONSENT_VERSION
	decided_at_unix = Time.get_unix_time_from_system()
	_answered_this_launch = true
	save_to_path(storage_path)


## Forgets the answer (used by tests and a future "change my mind" control).
func reset() -> void:
	status = Status.UNDECIDED
	consent_version = 0
	decided_at_unix = 0.0
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))


## Re-reads the answer from disk (no-op when the file is missing/corrupt).
func load_from_path(path: String = "") -> void:
	var source: String = path if not path.is_empty() else storage_path
	status = Status.UNDECIDED
	consent_version = 0
	decided_at_unix = 0.0
	if not FileAccess.file_exists(source):
		return
	var file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	# JSON.parse (not parse_string) so a corrupt file stays silent instead of
	# printing an engine error: a bad file simply means "undecided".
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	consent_version = _to_int(data.get("consent_version", 0), 0)
	decided_at_unix = _to_float(data.get("decided_at_unix", 0.0))
	var stored: String = str(data.get("status", "")).strip_edges().to_lower()
	if stored == STATUS_GRANTED:
		status = Status.GRANTED
	elif stored == STATUS_DECLINED:
		status = Status.DECLINED


## Writes the answer to disk. Returns true when the file could be written.
func save_to_path(path: String = "") -> bool:
	var target: String = path if not path.is_empty() else storage_path
	var dir: String = target.get_base_dir()
	if not dir.is_empty():
		var global_dir: String = ProjectSettings.globalize_path(dir)
		if not DirAccess.dir_exists_absolute(global_dir):
			DirAccess.make_dir_recursive_absolute(global_dir)
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"status": _status_key(status),
		"consent_version": consent_version,
		"decided_at_unix": decided_at_unix,
	}, "\t"))
	file.close()
	return true


## Convenience factory; equivalent to TelemetryConsent.new(path).
static func load_from(path: String = DEFAULT_PATH) -> TelemetryConsent:
	return TelemetryConsent.new(path)
#endregion

#region Private Methods
func _status_key(value: int) -> String:
	if value == Status.GRANTED:
		return STATUS_GRANTED
	if value == Status.DECLINED:
		return STATUS_DECLINED
	return "undecided"


func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is String:
		var text: String = value
		if text.is_valid_int():
			return text.to_int()
	return fallback


func _to_float(value: Variant) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return 0.0
#endregion
