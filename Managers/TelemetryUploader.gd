class_name TelemetryUploader
extends Node
## Drains the telemetry outbox to the metric server, in the background.
##
## It picks up the per-run JSONL files HttpBatchSink leaves in
## user://telemetry/outbox/, POSTs them in batches to the configured endpoint and
## only then moves the file to the archive. A failed request keeps the file where
## it is and tries again later, so nothing is ever lost or uploaded twice.
##
## A failure is only ever retried when retrying could help. A dropped connection, a
## timeout, a 408/429 or a 5xx is transient: the file stays in the outbox and the
## pass is retried with exponential backoff. A 400/413/422 means the batch itself
## is wrong, so retrying it forever would starve every later run queued behind it:
## that file is quarantined in user://telemetry/rejected/ instead and the drain
## carries on with the next one.
##
## Configure with the project settings `telemetry/endpoint` and
## `telemetry/anon_key`. With no endpoint the game stays local-only and this node
## does nothing at all.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Signals
## Emitted after one drain pass: `sent` files moved to the archive, `failed` kept in
## the outbox for a later retry, `rejected` quarantined as permanently undeliverable.
signal drain_finished(sent: int, failed: int, rejected: int)
#endregion

#region Constants
const OUTBOX_DIR: String = "user://telemetry/outbox"
const ARCHIVE_DIR: String = "user://telemetry/archive"
## Files the server refused outright (a malformed batch) are parked here instead of
## being retried forever, which would block every later run behind them.
const REJECTED_DIR: String = "user://telemetry/rejected"
const ENDPOINT_SETTING: String = "telemetry/endpoint"
const ANON_KEY_SETTING: String = "telemetry/anon_key"
## Events per POST; the Edge function rejects larger batches.
const MAX_EVENTS: int = 500
const REQUEST_TIMEOUT: float = 20.0
## Seconds to wait before retrying the outbox after a failed drain, and the ceiling
## the exponential backoff climbs to.
const RETRY_DELAY: float = 60.0
const RETRY_MAX_DELAY: float = 600.0
## How many delivered runs the local archive keeps. The archive is a diagnostic
## trail, not the record (the server holds that), so it is capped rather than left
## to grow until it fills the player's disk.
const ARCHIVE_KEEP: int = 200
#endregion

#region Exports
## Overrides the `telemetry/endpoint` project setting when set (tests use this).
@export var endpoint_override: String = ""
#endregion

#region Public Variables
## The folder the telemetry subdirectories live in. Defaults to the real
## `user://telemetry`; a suite points it at a scratch folder so it never reads or
## moves the player's own telemetry. The four paths below are derived from it.
var telemetry_root: String = "user://telemetry"
## How many delivered runs the archive keeps (see ARCHIVE_KEEP); a suite lowers it
## instead of creating hundreds of files.
var archive_keep: int = ARCHIVE_KEEP
## Test seam: when set, replaces the HTTPRequest so a suite can drive response codes
## without a socket. `Callable(url: String, anon_key: String, body: String) -> Array`
## returning `[HTTPRequest.Result, int]` (transport result, HTTP status).
var transport_override: Callable = Callable()
## Test seam: skips the headless / consent gates so a suite can exercise the drain
## state machine. Never set in game code.
var ignore_gates: bool = false
## Diagnostics only: files quarantined by the most recent drain pass.
var last_rejected: int = 0
#endregion

#region Private Variables
var _http: HTTPRequest
## One-shot retry clock. A Timer node (not SceneTreeTimer) so it pauses with the
## scene and is freed with the uploader instead of firing into a dead node.
var _retry_timer: Timer
var _busy: bool = false
var _pending_files: PackedStringArray = PackedStringArray()
var _current_file: String = ""
var _current_batches: Array = []
var _current_index: int = 0
var _sent: int = 0
var _failed: int = 0
var _rejected: int = 0
## Current retry wait, doubled after every failed pass up to RETRY_MAX_DELAY.
var _retry_delay: float = RETRY_DELAY
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "TelemetryHTTP"
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_retry_timer = Timer.new()
	_retry_timer.name = "TelemetryRetry"
	_retry_timer.one_shot = true
	_retry_timer.wait_time = RETRY_DELAY
	_retry_timer.timeout.connect(drain)
	add_child(_retry_timer)
	# No drain here on purpose: BattleScene drives it once the disclosure has been
	# answered this launch, so a queued run is never uploaded before the player has
	# had the chance to see (or change) their answer. Sweeping the spool is safe
	# here and only here: this node is mounted before the launch's first battle, so
	# no run is mid-write yet (a retry-time sweep could catch one).
	_promote_orphans()
#endregion

#region Public Methods
## True when an endpoint is configured and the player agreed to telemetry during
## this launch (a stored answer from an earlier session is not enough).
func is_enabled() -> bool:
	if endpoint().is_empty():
		return false
	if ignore_gates:
		return true
	if DisplayServer.get_name() == "headless":
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


## The four telemetry directories, resolved from `telemetry_root` so a suite only
## has to redirect one path. Each is derived from the same constant the game uses
## (HttpBatchSink.OUTBOX_DIR, JsonlFileSink.DEFAULT_DIR), so the two can never drift.
func outbox_path() -> String:
	return telemetry_root + "/" + OUTBOX_DIR.get_file()


## Where a delivered run is parked (see `_archive`).
func archive_path() -> String:
	return telemetry_root + "/" + ARCHIVE_DIR.get_file()


## Where a batch the server refused outright is parked (see `_reject_current`).
func rejected_path() -> String:
	return telemetry_root + "/" + REJECTED_DIR.get_file()


## The Stage 1 spool, swept for crash orphans when a server is configured.
func spool_path() -> String:
	return telemetry_root + "/" + JsonlFileSink.DEFAULT_DIR.get_file()


## Starts one drain pass. Safe to call often: a second call while a pass is in
## flight is ignored, and a disabled uploader does nothing.
func drain() -> void:
	if _busy or not is_enabled():
		return
	_sent = 0
	_failed = 0
	_rejected = 0
	_pending_files = _list_files(outbox_path())
	_busy = true
	_next_file()
#endregion


#region Private Methods
## The `.jsonl` runs in one directory. Sorted so a pass is deterministic.
func _list_files(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return files
	for file_name: String in dir.get_files():
		if file_name.ends_with(JsonlFileSink.FILE_SUFFIX):
			files.append(file_name)
	return files


## Recovers a run the game never got to seal. With a server configured the sink is
## HttpBatchSink, which only promotes a run to the outbox in `close()`, so anything
## still in the spool is a crash orphan. Without an endpoint the spool *is* the
## record (Stage 1, read by Tools/analyze_telemetry.py), so it is left alone.
func _promote_orphans() -> void:
	if endpoint().is_empty():
		return
	for file_name: String in _list_files(spool_path()):
		_move_to(outbox_path(), file_name, spool_path())


## Moves on to the next queued file, skipping (and archiving) empty ones.
func _next_file() -> void:
	while not _pending_files.is_empty():
		var file_name: String = _pending_files[0]
		_pending_files.remove_at(0)
		_current_file = file_name
		_current_batches = _read_batches(outbox_path() + "/" + file_name)
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
	var body: String = JSON.stringify({"events": _current_batches[_current_index]})
	if transport_override.is_valid():
		_apply_transport(url, body)
		return
	var error: int = _http.request(url, _headers(), HTTPClient.METHOD_POST, body)
	if error != OK:
		_fail_current()


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + anon_key(),
	])


## Drives one batch through an injected transport, so a suite can exercise every
## status code without opening a socket.
func _apply_transport(url: String, body: String) -> void:
	var raw: Variant = transport_override.call(url, anon_key(), body)
	if not (raw is Array):
		_fail_current()
		return
	var response: Array = raw
	_apply_response(
		_coerce_int(response, 0, HTTPRequest.RESULT_CANT_CONNECT),
		_coerce_int(response, 1, 0)
	)


func _coerce_int(values: Array, index: int, fallback: int) -> int:
	if index >= values.size():
		return fallback
	var value: Variant = values[index]
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return fallback


## One place decides what a response means, whichever transport produced it.
func _apply_response(result: int, code: int) -> void:
	if _is_success(result, code):
		_advance_batch()
		return
	if _is_transient(result, code):
		_fail_current()
		return
	_reject_current()


func _is_success(result: int, code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300


## A retry can help: the connection dropped, the server timed out or throttled, or
## it is temporarily broken. Any other 4xx cannot be fixed by sending the same bytes
## again, so it must not be retried.
func _is_transient(result: int, code: int) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		return true
	if code == HTTPClient.RESPONSE_REQUEST_TIMEOUT or code == HTTPClient.RESPONSE_TOO_MANY_REQUESTS:
		return true
	return code >= 500


## This batch is stored: move to the next one, or archive the finished file.
func _advance_batch() -> void:
	_current_index += 1
	if _current_index < _current_batches.size():
		_post_current()
		return
	if not _archive(_current_file):
		_fail_current()
		return
	_sent += 1
	_reset_backoff()
	_next_file()


## Moves an uploaded run out of the outbox. Returns false when it could not be
## moved, so the caller keeps it queued instead of pretending it was delivered.
func _archive(file_name: String) -> bool:
	if not _move_to(archive_path(), file_name, outbox_path()):
		return false
	_prune_archive()
	return true


## Parks a batch the server refused outright so it cannot block the queue, then
## carries on with the next file.
func _reject_current() -> void:
	if not _move_to(rejected_path(), _current_file, outbox_path()):
		_fail_current()
		return
	_rejected += 1
	_reset_backoff()
	_next_file()


## Moves one file between two telemetry directories. Returns false when the move
## failed, so a caller never assumes a file was delivered or parked.
func _move_to(target_dir: String, file_name: String, source_dir: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	var error: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_dir + "/" + file_name),
		ProjectSettings.globalize_path(target_dir + "/" + file_name)
	)
	return error == OK


## A failed request keeps the file in the outbox so the next pass retries it.
func _fail_current() -> void:
	_failed += 1
	_pending_files = PackedStringArray()
	_busy = false
	retry_later()


func _finish() -> void:
	_busy = false
	last_rejected = _rejected
	drain_finished.emit(_sent, _failed, _rejected)


## Waits, then tries the whole outbox again (a dropped connection is temporary).
## The wait doubles after each failed pass so a server that is down is not hammered
## once a minute, and resets as soon as a batch lands.
func retry_later() -> void:
	if not is_inside_tree() or _retry_timer == null:
		return
	_retry_timer.wait_time = _retry_delay
	_retry_timer.start()
	_retry_delay = minf(_retry_delay * 2.0, RETRY_MAX_DELAY)


func _reset_backoff() -> void:
	_retry_delay = RETRY_DELAY


## Keeps the local diagnostic archive bounded: the server holds the record, so the
## oldest delivered runs are dropped once there are more than `archive_keep`.
func _prune_archive() -> void:
	var names: PackedStringArray = _list_files(archive_path())
	if names.size() <= archive_keep:
		return
	var modified: Dictionary[String, int] = {}
	for file_name: String in names:
		modified[file_name] = FileAccess.get_modified_time(archive_path() + "/" + file_name)
	var ordered: Array[String] = []
	for file_name: String in modified:
		ordered.append(file_name)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return modified[a] < modified[b]
	)
	var excess: int = ordered.size() - archive_keep
	for index: int in excess:
		var _removed: int = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(archive_path() + "/" + ordered[index])
		)
#endregion


#region Signal Handlers
func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	_apply_response(result, response_code)
#endregion

