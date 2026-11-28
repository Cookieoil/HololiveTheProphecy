<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryUploaderTest.gd` — `class_name TelemetryUploaderTest` extends `GdUnitTestSuite`

`344` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the uploader's delivery rules (Managers/TelemetryUploader.gd), which decide whether a finished run reaches the metric server or is lost: - a batch the ser…

Sections: Helpers · Refused batches · Transient failures · Credentials · Batching · Crash orphans and the archive cap

Constants:
- L23 `TEMP_ROOT: String = "user://telemetry_uploader_test"`
- L24 `ENDPOINT: String = "https://metrics.invalid/ingest"`
- L27 `RETRYABLE_CODES: Array[int] = [` — The 4xx codes a retry can still fix: 408/429 are timing, 401/403 are a deployment or a key problem (see TelemetryUploader._is_transient).

Public API:
- L36-37 `after() -> void`
- L168-185 `test_a_refused_batch_is_quarantined_and_the_drain_continues() -> void` — A 400 means the batch itself is wrong: retrying it would block every later run behind it, so it is quarantined and the drain moves on.
- L192-216 `test_a_transient_failure_keeps_the_file_and_backs_the_retry_off() -> void` — A dropped connection, a 5xx or a throttle is worth retrying: the file stays put and the pass is retried later, with the wait doubling each time.
- L222-225 `test_a_timeout_a_throttle_and_a_credential_error_are_retried_not_quarantined() -> void` — The 4xx codes a retry *can* fix: 408 and 429 are timing, 401 and 403 are a deployment or key problem. None may be mistaken for the permanent kind - quarantining…
- L230-233 `test_a_batch_the_server_calls_malformed_is_quarantined() -> void` — The other side of the boundary, so the rule above cannot be satisfied by never quarantining anything: a 400/413/422 *is* the batch, so the drain parks it.
- L242-252 `test_requests_carry_the_anon_key_as_a_bearer_token_too() -> void` — Supabase reads the anon key as `apikey` at the gateway and as `Authorization: Bearer` at the Edge function's JWT check. Sending only `apikey` is a 401 on the de…
- L257-264 `test_no_credential_header_is_invented_without_a_key() -> void` — With no key configured there is nothing to authenticate with, so no credential header is invented. (A local, endpoint-less build never gets here: `is_enabled()`…
- L271-283 `test_a_multi_batch_run_is_posted_in_pieces_then_archived() -> void` — A run with more events than one POST carries is uploaded in pieces, and the file is only archived once the last piece has landed.
- L288-297 `test_an_empty_run_file_is_archived_without_a_request() -> void` — A half-written or truncated file carries nothing worth sending, so it is archived without a request rather than blocking the queue.
- L305-313 `test_a_crash_orphan_in_the_spool_is_promoted_when_a_server_is_configured() -> void` — With a server configured the sink is HttpBatchSink, which only promotes a run to the outbox in `close()`, so a run still in the spool is a crash orphan: it is r…
- L318-327 `test_the_spool_is_left_alone_without_a_server() -> void` — Without an endpoint the spool *is* the record - Tools/analyze_telemetry.py reads it - so the sweep must leave it exactly where it is.
- L332-342 `test_the_archive_is_pruned_to_the_cap() -> void` — The archive is a diagnostic trail, not the record, so it is capped instead of growing until it fills the player's disk.

Private:
- L41-48 `_remove_tree`
- L55-70 `_new_uploader`
- L75-77 `_mount`
- L81-88 `_write_run`
- L92-100 `_count_runs`
- L103-104 `_retry_timer`
- L108-117 `_sent_events`
- L121-129 `_has_header`
- L134-142 `_drained_uploader_with_response`
- L146-151 `_quarantined_codes`
- L155-161 `_calls_that_left_the_run_queued`

Uses: JsonlFileSink, TelemetrySchema, TelemetryUploader
Used by: —
Loads: —

