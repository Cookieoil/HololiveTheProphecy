<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryUploaderTest.gd` — `class_name TelemetryUploaderTest` extends `GdUnitTestSuite`

`256` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the uploader's delivery rules (Managers/TelemetryUploader.gd), which decide whether a finished run reaches the metric server or is lost: - a batch the ser…

Sections: Helpers · Refused batches · Transient failures · Batching · Crash orphans and the archive cap

Constants:
- L20 `TEMP_ROOT: String = "user://telemetry_uploader_test"`
- L21 `ENDPOINT: String = "https://metrics.invalid/ingest"`

Public API:
- L25-26 `after() -> void`
- L113-130 `test_a_refused_batch_is_quarantined_and_the_drain_continues() -> void` — A 400 means the batch itself is wrong: retrying it would block every later run behind it, so it is quarantined and the drain moves on.
- L137-161 `test_a_transient_failure_keeps_the_file_and_backs_the_retry_off() -> void` — A dropped connection, a 5xx or a throttle is worth retrying: the file stays put and the pass is retried later, with the wait doubling each time.
- L166-176 `test_a_timeout_and_a_throttle_are_retried_not_quarantined() -> void` — 408 and 429 are the two 4xx codes a retry *can* fix, so they must not be mistaken for the permanent kind.
- L183-195 `test_a_multi_batch_run_is_posted_in_pieces_then_archived() -> void` — A run with more events than one POST carries is uploaded in pieces, and the file is only archived once the last piece has landed.
- L200-209 `test_an_empty_run_file_is_archived_without_a_request() -> void` — A half-written or truncated file carries nothing worth sending, so it is archived without a request rather than blocking the queue.
- L217-225 `test_a_crash_orphan_in_the_spool_is_promoted_when_a_server_is_configured() -> void` — With a server configured the sink is HttpBatchSink, which only promotes a run to the outbox in `close()`, so a run still in the spool is a crash orphan: it is r…
- L230-239 `test_the_spool_is_left_alone_without_a_server() -> void` — Without an endpoint the spool *is* the record - Tools/analyze_telemetry.py reads it - so the sweep must leave it exactly where it is.
- L244-254 `test_the_archive_is_pruned_to_the_cap() -> void` — The archive is a diagnostic trail, not the record, so it is capped instead of growing until it fills the player's disk.

Private:
- L30-37 `_remove_tree`
- L44-59 `_new_uploader`
- L64-66 `_mount`
- L70-77 `_write_run`
- L81-89 `_count_runs`
- L92-93 `_retry_timer`
- L97-106 `_sent_events`

Uses: JsonlFileSink, TelemetrySchema, TelemetryUploader
Used by: —
Loads: —

