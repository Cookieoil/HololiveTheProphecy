class_name TelemetryUploader
extends Node
## Drains the telemetry outbox to the metric server, in the background.
##
## It picks up the per-run JSONL files HttpBatchSink leaves in
## user://telemetry/outbox/, POSTs them in batches to the configured endpoint and
## only then moves the file to the archive. A failed request keeps the file where
## it is and tries again later, so nothing is ever lost or uploaded twice.
##
## Configure with the project settings `telemetry/endpoint` and
## `telemetry/anon_key`. With no endpoint the game stays local-only and this node
## does nothing at all.
##
## @author TheGreatJellyfish
## @version 11/26/2026

#region Signals
## Emitted after one drain pass: `sent` files moved to the archive, `failed` kept.
signal drain_finished(sent: int, failed: int)
#endregion

#region Constants
const OUTBOX_DIR: String = "user://telemetry/outbox"
const ARCHIVE_DIR: String = "user://telemetry/archive"
const ENDPOINT_SETTING: String = "telemetry/endpoint"
const ANON_KEY_SETTING: String = "telemetry/anon_key"
## Events per POST; the Edge function rejects larger batches.
const MAX_EVENTS: int = 500
const REQUEST_TIMEOUT: float = 20.0
## Seconds to wait before retrying the outbox after a failed drain.
const RETRY_DELAY: float = 60.0
#endregion

#region Exports
## Overrides the `telemetry/endpoint` project setting when set (tests use this).
@export var endpoint_override: String = ""
#endregion

#region Private Variables
var _http: HTTPRequest
var _busy: bool = false
var _pending_files: PackedStringArray = PackedStringArray()
var _current_file: String = ""
var _current_batches: Array = []
var _current_index: int = 0
var _sent: int = 0
var _failed: int = 0
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "TelemetryHTTP"
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	# No drain here on purpose: BattleScene drives it once the disclosure has been
	# answered this launch, so a queued run is never uploaded before the player has
	# had the chance to see (or change) their answer.


## True when an endpoint is configured and the player agreed to telemetry during
## this launch (a stored answer from an earlier session is not enough).
func is_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if endpoint().is_empty():
		return false
	if not TelemetryConsent.answered_this_launch():
		return false
	return TelemetryConsent.load_from().is_granted()


func endpoint() -> String:
	if not endpoint_override.is_empty():
		return endpoint_override
	return str(ProjectSettings.get_setting(ENDPOINT_SETTING, ""))


func anon_key() -> String:
	return str(ProjectSettings.get_setting(ANON_KEY_SETTING, ""))
#endregion

#region Public Methods
## Starts one drain pass. Safe to call often: a second call while a pass is in
## flight is ignored, and a disabled uploader does nothing.
func drain() -> void:
	if _busy or not is_enabled():
		return
	_sent = 0
	_failed = 0
	_pending_files = _list_outbox()
	_busy = true
	_next_file()
#endregion


#region Private Methods
func _list_outbox() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(OUTBOX_DIR)
	if dir == null:
		return files
	for file_name: String in dir.get_files():
		if file_name.ends_with(JsonlFileSink.FILE_SUFFIX):
			files.append(file_name)
	return files


## Moves on to the next queued file, skipping (and archiving) empty ones.
func _next_file() -> void:
	while not _pending_files.is_empty():
		var file_name: String = _pending_files[0]
		_pending_files.remove_at(0)
		_current_file = file_name
		_current_batches = _read_batches(OUTBOX_DIR + "/" + file_name)
		_current_index = 0
		if _current_batches.is_empty():
			if not _archive(file_name):
				_fail_current()
				return
			_sent += 1
			continue
		_post_current()
		return
	_finish()


func _read_batches(path: String) -> Array:
	var events: Array = []
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json: JSON = JSON.new()
		# JSON.parse (not parse_string) so one corrupt line cannot print an error
		# and abort the whole upload.
		if json.parse(line) != OK:
			continue
		var parsed: Variant = json.data
		if parsed is Dictionary:
			events.append(parsed)
	file.close()
	var batches: Array = []
	var index: int = 0
	while index < events.size():
		batches.append(events.slice(index, mini(index + MAX_EVENTS, events.size())))
		index += MAX_EVENTS
	return batches


func _post_current() -> void:
	var url: String = endpoint()
	if url.is_empty():
		_finish()
		return
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + anon_key(),
	])
	var body: String = JSON.stringify({"events": _current_batches[_current_index]})
	var error: int = _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_fail_current()


## Moves an uploaded run out of the outbox. Returns false when it could not be
## moved, so the caller keeps it queued instead of pretending it was delivered.
func _archive(file_name: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARCHIVE_DIR))
	var from: String = OUTBOX_DIR + "/" + file_name
	var to: String = ARCHIVE_DIR + "/" + file_name
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from),
		ProjectSettings.globalize_path(to)
	) == OK


## A failed request keeps the file in the outbox so the next pass retries it.
func _fail_current() -> void:
	_failed += 1
	_pending_files = PackedStringArray()
	_busy = false
	retry_later()


func _finish() -> void:
	_busy = false
	var sent: int = _sent
	var failed: int = _failed
	drain_finished.emit(sent, failed)


## Waits, then tries the whole outbox again (a dropped connection is temporary).
func retry_later() -> void:
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(RETRY_DELAY)
	timer.timeout.connect(drain)
#endregion


#region Signal Handlers
func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fail_current()
		return
	# This batch is safely stored; move on to the next one, or archive the file.
	_current_index += 1
	if _current_index >= _current_batches.size():
		if not _archive(_current_file):
			_fail_current()
			return
		_sent += 1
		_next_file()
		return
	_post_current()
#endregion

