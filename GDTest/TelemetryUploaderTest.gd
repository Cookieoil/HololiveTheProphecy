class_name TelemetryUploaderTest
extends GdUnitTestSuite
## Locks the uploader's delivery rules (Managers/TelemetryUploader.gd), which decide
## whether a finished run reaches the metric server or is lost:
##
## - a batch the server refused outright is quarantined, and the drain carries on
##   with the next file instead of retrying the same bad bytes forever,
## - a transient failure keeps the file queued and backs the retry off (including a
##   401/403, which is a deployment or key problem rather than a bad batch),
## - the request carries the anon key as both `apikey` and `Authorization: Bearer`,
##   which are the two headers Supabase's gateway and JWT check read,
## - a run larger than one POST is uploaded in pieces and only then archived,
## - an empty file is archived without a request,
## - a crash orphan left in the spool is recovered when a server is configured, and
##   left alone when it is not (there the spool is the record).
##
## Every case drives a scripted transport, so no socket is ever opened and no
## response timing has to be guessed.
##
## @author TheGreatJellyfish
## @version 11/27/2026

const TEMP_ROOT: String = "user://telemetry_uploader_test"
const ENDPOINT: String = "https://metrics.invalid/ingest"
## The 4xx codes a retry can still fix: 408/429 are timing, 401/403 are a deployment or a
## key problem (see TelemetryUploader._is_transient).
const RETRYABLE_CODES: Array[int] = [
	HTTPClient.RESPONSE_REQUEST_TIMEOUT,
	HTTPClient.RESPONSE_TOO_MANY_REQUESTS,
	HTTPClient.RESPONSE_UNAUTHORIZED,
	HTTPClient.RESPONSE_FORBIDDEN,
]


#region Helpers
func after() -> void:
	_remove_tree(TEMP_ROOT)


## Deletes a directory tree under user:// (tests only).
func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)
		for sub_name: String in dir.get_directories():
			_remove_tree(path + "/" + sub_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## An uploader pointed at its own scratch telemetry root, with the gates opened and
## the transport replaced by `responses` (each entry `[HTTPRequest.Result, int]`).
## `calls` collects every body the uploader tried to send. Not mounted yet, so a
## test can stage the spool before `_ready()` sweeps it.
func _new_uploader(responses: Array, calls: Array[String]) -> TelemetryUploader:
	var uploader: TelemetryUploader = TelemetryUploader.new()
	uploader.name = "TestUploader"
	uploader.telemetry_root = "%s/%s" % [TEMP_ROOT, TelemetrySchema.new_id()]
	uploader.endpoint_override = ENDPOINT
	uploader.ignore_gates = true
	uploader.archive_keep = 3
	var queue: Array = responses.duplicate(true)
	uploader.transport_override = func(_url: String, _key: String, body: String) -> Array:
		calls.append(body)
		if queue.is_empty():
			return [HTTPRequest.RESULT_SUCCESS, HTTPClient.RESPONSE_OK]
		var response: Array = queue[0]
		queue.remove_at(0)
		return response
	return uploader


## Mounts the uploader (which fires `_ready` and the spool sweep) and frees it with
## the test.
func _mount(uploader: TelemetryUploader) -> void:
	add_child(uploader)
	auto_free(uploader)


## Writes a run file of `event_count` valid events, or an empty file when 0.
func _write_run(dir_path: String, file_name: String, event_count: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var file: FileAccess = FileAccess.open(dir_path + "/" + file_name, FileAccess.WRITE)
	if file == null:
		return
	for index: int in event_count:
		file.store_line(JSON.stringify({"i": index}))
	file.close()


## How many `.jsonl` runs a directory holds (0 when it does not exist).
func _count_runs(dir_path: String) -> int:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	var total: int = 0
	for file_name: String in dir.get_files():
		if file_name.ends_with(JsonlFileSink.FILE_SUFFIX):
			total += 1
	return total


func _retry_timer(uploader: TelemetryUploader) -> Timer:
	return uploader.get_node_or_null("TelemetryRetry") as Timer


## The `events` array of one recorded request body.
func _sent_events(body: String) -> Array:
	var parsed: Variant = JSON.parse_string(body)
	if not (parsed is Dictionary):
		return []
	var payload: Dictionary = parsed
	var events: Variant = payload.get("events", [])
	if not (events is Array):
		return []
	var listed: Array = events
	return listed


## True when `headers` carries `name: value` (the name compared case-insensitively).
func _has_header(headers: PackedStringArray, name: String, value: String) -> bool:
	for header: String in headers:
		var parts: PackedStringArray = header.split(":", true, 1)
		if parts.size() < 2:
			continue
		if parts[0].strip_edges().to_lower() == name.to_lower() \
				and parts[1].strip_edges() == value:
			return true
	return false


## One run, one scripted response: a fresh uploader, mounted and drained once. Each code
## gets its own uploader, so one response cannot decide the next code's outcome.
func _drained_uploader_with_response(code: int) -> TelemetryUploader:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([[HTTPRequest.RESULT_SUCCESS, code]], calls)
	_write_run(uploader.outbox_path(), "run_probe.jsonl", 1)
	_mount(uploader)

	uploader.drain()

	return uploader


## Which of `codes` ended up quarantined as permanently undeliverable.
func _quarantined_codes(codes: Array[int]) -> Array[int]:
	var quarantined: Array[int] = []
	for code: int in codes:
		if _count_runs(_drained_uploader_with_response(code).rejected_path()) != 0:
			quarantined.append(code)
	return quarantined


## Which of `codes` failed to move the run out of the outbox (delivered or quarantined).
func _calls_that_left_the_run_queued(codes: Array[int]) -> Array[int]:
	var queued: Array[int] = []
	for code: int in codes:
		var uploader: TelemetryUploader = _drained_uploader_with_response(code)
		if _count_runs(uploader.outbox_path()) != 0 and _count_runs(uploader.archive_path()) == 0:
			queued.append(code)
	return queued
#endregion


#region Refused batches
## A 400 means the batch itself is wrong: retrying it would block every later run
## behind it, so it is quarantined and the drain moves on.
func test_a_refused_batch_is_quarantined_and_the_drain_continues() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader(
		[[HTTPRequest.RESULT_SUCCESS, 400], [HTTPRequest.RESULT_SUCCESS, HTTPClient.RESPONSE_OK]],
		calls
	)
	_write_run(uploader.outbox_path(), "run_bad.jsonl", 1)
	_write_run(uploader.outbox_path(), "run_good.jsonl", 1)
	_mount(uploader)

	uploader.drain()

	assert_int(_count_runs(uploader.rejected_path())).is_equal(1)
	assert_int(_count_runs(uploader.archive_path())).is_equal(1)
	assert_int(_count_runs(uploader.outbox_path())).is_equal(0)
	assert_int(uploader.last_rejected).is_equal(1)
	# Both files were attempted: the refusal did not abort the pass.
	assert_int(calls.size()).is_equal(2)
#endregion


#region Transient failures
## A dropped connection, a 5xx or a throttle is worth retrying: the file stays put
## and the pass is retried later, with the wait doubling each time.
func test_a_transient_failure_keeps_the_file_and_backs_the_retry_off() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader(
		[[HTTPRequest.RESULT_SUCCESS, 503], [HTTPRequest.RESULT_SUCCESS, 503]],
		calls
	)
	_write_run(uploader.outbox_path(), "run_later.jsonl", 1)
	_mount(uploader)

	uploader.drain()

	assert_int(_count_runs(uploader.outbox_path())).is_equal(1)
	assert_int(_count_runs(uploader.archive_path())).is_equal(0)
	assert_int(_count_runs(uploader.rejected_path())).is_equal(0)
	var timer: Timer = _retry_timer(uploader)
	assert_object(timer).is_not_null()
	if timer == null:
		return
	assert_bool(timer.is_stopped()).is_false()
	assert_bool(is_equal_approx(timer.wait_time, TelemetryUploader.RETRY_DELAY)).is_true()

	uploader.drain()
	assert_bool(
		is_equal_approx(timer.wait_time, TelemetryUploader.RETRY_DELAY * 2.0)
	).is_true()


## The 4xx codes a retry *can* fix: 408 and 429 are timing, 401 and 403 are a deployment
## or key problem. None may be mistaken for the permanent kind - quarantining real player
## runs over a rotated key would throw the data away for good.
func test_a_timeout_a_throttle_and_a_credential_error_are_retried_not_quarantined() -> void:
	var quarantined: Array[int] = _quarantined_codes(RETRYABLE_CODES)

	assert_array(quarantined).is_empty()


## The other side of the boundary, so the rule above cannot be satisfied by never
## quarantining anything: a 400/413/422 *is* the batch, so the drain parks it.
func test_a_batch_the_server_calls_malformed_is_quarantined() -> void:
	var still_queued: Array[int] = _calls_that_left_the_run_queued([400, 413, 422])

	assert_array(still_queued).is_empty()
#endregion


#region Credentials
## Supabase reads the anon key as `apikey` at the gateway and as `Authorization: Bearer`
## at the Edge function's JWT check. Sending only `apikey` is a 401 on the default
## deployment, so every batch would be refused (and, with the retry rule above, retried
## forever instead of being quarantined - correct, but it would never upload).
func test_requests_carry_the_anon_key_as_a_bearer_token_too() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	uploader.anon_key_override = "anon-key-123"
	_mount(uploader)

	var headers: PackedStringArray = uploader._headers()

	assert_bool(_has_header(headers, "content-type", "application/json")).is_true()
	assert_bool(_has_header(headers, "apikey", "anon-key-123")).is_true()
	assert_bool(_has_header(headers, "Authorization", "Bearer anon-key-123")).is_true()


## With no key configured there is nothing to authenticate with, so no credential header
## is invented. (A local, endpoint-less build never gets here: `is_enabled()` is false.)
func test_no_credential_header_is_invented_without_a_key() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	_mount(uploader)

	for header: String in uploader._headers():
		assert_bool(header.begins_with("apikey:")).is_false()
		assert_bool(header.begins_with("Authorization:")).is_false()
#endregion


#region Batching
## A run with more events than one POST carries is uploaded in pieces, and the file
## is only archived once the last piece has landed.
func test_a_multi_batch_run_is_posted_in_pieces_then_archived() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	_write_run(uploader.outbox_path(), "run_big.jsonl", TelemetryUploader.MAX_EVENTS + 1)
	_mount(uploader)

	uploader.drain()

	assert_int(calls.size()).is_equal(2)
	assert_int(_sent_events(calls[0]).size()).is_equal(TelemetryUploader.MAX_EVENTS)
	assert_int(_sent_events(calls[1]).size()).is_equal(1)
	assert_int(_count_runs(uploader.archive_path())).is_equal(1)
	assert_int(_count_runs(uploader.outbox_path())).is_equal(0)


## A half-written or truncated file carries nothing worth sending, so it is archived
## without a request rather than blocking the queue.
func test_an_empty_run_file_is_archived_without_a_request() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	_write_run(uploader.outbox_path(), "run_empty.jsonl", 0)
	_mount(uploader)

	uploader.drain()

	assert_int(calls.size()).is_equal(0)
	assert_int(_count_runs(uploader.archive_path())).is_equal(1)
#endregion


#region Crash orphans and the archive cap
## With a server configured the sink is HttpBatchSink, which only promotes a run to
## the outbox in `close()`, so a run still in the spool is a crash orphan: it is
## recovered on the next launch instead of being stranded forever.
func test_a_crash_orphan_in_the_spool_is_promoted_when_a_server_is_configured() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	_write_run(uploader.spool_path(), "run_orphan.jsonl", 1)

	_mount(uploader)

	assert_int(_count_runs(uploader.outbox_path())).is_equal(1)
	assert_int(_count_runs(uploader.spool_path())).is_equal(0)


## Without an endpoint the spool *is* the record - Tools/analyze_telemetry.py reads
## it - so the sweep must leave it exactly where it is.
func test_the_spool_is_left_alone_without_a_server() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	uploader.endpoint_override = ""
	_write_run(uploader.spool_path(), "run_local.jsonl", 1)

	_mount(uploader)

	assert_int(_count_runs(uploader.spool_path())).is_equal(1)
	assert_int(_count_runs(uploader.outbox_path())).is_equal(0)


## The archive is a diagnostic trail, not the record, so it is capped instead of
## growing until it fills the player's disk.
func test_the_archive_is_pruned_to_the_cap() -> void:
	var calls: Array[String] = []
	var uploader: TelemetryUploader = _new_uploader([], calls)
	for index: int in uploader.archive_keep:
		_write_run(uploader.archive_path(), "run_old_%d.jsonl" % index, 1)
	_write_run(uploader.outbox_path(), "run_new.jsonl", 1)
	_mount(uploader)

	uploader.drain()

	assert_int(_count_runs(uploader.archive_path())).is_equal(uploader.archive_keep)
#endregion
