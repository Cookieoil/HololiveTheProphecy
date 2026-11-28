<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryUploader.gd` — `class_name TelemetryUploader` extends `Node`

`449` lines · [back to the map](../../CODEBASE_MAP.md)

> Drains the telemetry outbox to the metric server, in the background. It picks up the per-run JSONL files HttpBatchSink leaves in user://telemetry/outbox/, POSTs…

Sections: Signals · Constants · Exports · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Private Methods · (+1 more)

Signals:
- L29 `drain_finished(sent: int, failed: int, rejected: int)` — Emitted after one drain pass: `sent` files moved to the archive, `failed` kept in the outbox for a later retry, `rejected` quarantined as permanently undelivera…

Constants:
- L33 `OUTBOX_DIR: String = "user://telemetry/outbox"`
- L34 `ARCHIVE_DIR: String = "user://telemetry/archive"`
- L37 `REJECTED_DIR: String = "user://telemetry/rejected"` — Files the server refused outright (a malformed batch) are parked here instead of being retried forever, which would block every later run behind them.
- L38 `ENDPOINT_SETTING: String = "telemetry/endpoint"`
- L39 `ANON_KEY_SETTING: String = "telemetry/anon_key"`
- L41 `MAX_EVENTS: int = 500` — Events per POST; the Edge function rejects larger batches.
- L42 `REQUEST_TIMEOUT: float = 20.0`
- L45 `RETRY_DELAY: float = 60.0` — Seconds to wait before retrying the outbox after a failed drain, and the ceiling the exponential backoff climbs to.
- L46 `RETRY_MAX_DELAY: float = 600.0`
- L50 `ARCHIVE_KEEP: int = 200` — How many delivered runs the local archive keeps. The archive is a diagnostic trail, not the record (the server holds that), so it is capped rather than left to…

Exports:
- L55 `endpoint_override: String = ""` — Overrides the `telemetry/endpoint` project setting when set (tests use this).
- L57 `anon_key_override: String = ""` — Overrides the `telemetry/anon_key` project setting when set (tests use this).

State:
- L64 `telemetry_root: String = "user://telemetry"` — The folder the telemetry subdirectories live in. Defaults to the real `user://telemetry`; a suite points it at a scratch folder so it never reads or moves the p…
- L67 `archive_keep: int = ARCHIVE_KEEP` — How many delivered runs the archive keeps (see ARCHIVE_KEEP); a suite lowers it instead of creating hundreds of files.
- L71 `transport_override: Callable = Callable()` — Test seam: when set, replaces the HTTPRequest so a suite can drive response codes without a socket. `Callable(url: String, anon_key: String, body: String) -> Ar…
- L74 `ignore_gates: bool = false` — Test seam: skips the headless / consent gates so a suite can exercise the drain state machine. Never set in game code.
- L76 `last_rejected: int = 0` — Diagnostics only: files quarantined by the most recent drain pass.
- L80 `_http: HTTPRequest`
- L83 `_retry_timer: Timer` — One-shot retry clock. A Timer node (not SceneTreeTimer) so it pauses with the scene and is freed with the uploader instead of firing into a dead node.
- L84 `_busy: bool = false`
- L85 `_pending_files: PackedStringArray = PackedStringArray()`
- L86 `_current_file: String = ""`
- L87 `_current_batches: Array = []`
- L88 `_current_index: int = 0`
- L89 `_sent: int = 0`
- L90 `_failed: int = 0`
- L91 `_rejected: int = 0`
- L93 `_retry_delay: float = RETRY_DELAY` — Current retry wait, doubled after every failed pass up to RETRY_MAX_DELAY.

Public API:
- L120-129 `is_enabled() -> bool` — True when an endpoint is configured and the player agreed to telemetry during this launch (a stored answer from an earlier session is not enough).
- L132-135 `endpoint() -> String`
- L138-141 `anon_key() -> String`
- L147-148 `outbox_path() -> String` — The four telemetry directories, resolved from `telemetry_root` so a suite only has to redirect one path. Each is derived from the same constant the game uses (H…
- L152-153 `archive_path() -> String` — Where a delivered run is parked (see `_archive`).
- L157-158 `rejected_path() -> String` — Where a batch the server refused outright is parked (see `_reject_current`).
- L162-163 `spool_path() -> String` — The Stage 1 spool, swept for crash orphans when a server is configured.
- L168-176 `drain() -> void` — Starts one drain pass. Safe to call often: a second call while a pass is in flight is ignored, and a disabled uploader does nothing.
- L404-409 `retry_later() -> void` — Waits, then tries the whole outbox again (a dropped connection is temporary). The wait doubles after each failed pass so a server that is down is not hammered o…

Private:
- L97-114 `_ready`
- L182-190 `_list_files`
- L197-201 `_promote_orphans`
- L205-220 `_next_file`
- L223-248 `_read_batches`
- L251-262 `_post_current`
- L270-278 `_headers`
- L283-292 `_apply_transport`
- L295-305 `_coerce_int`
- L309-316 `_apply_response`
- L319-320 `_is_success`
- L332-339 `_is_transient`
- L343-353 `_advance_batch`
- L358-362 `_archive`
- L367-373 `_reject_current`
- L378-384 `_move_to`
- L388-392 `_fail_current`
- L395-398 `_finish`
- L412-413 `_reset_backoff`
- L418-435 `_prune_archive`
- L440-446 `_on_request_completed`

Uses: JsonlFileSink, TelemetryConsent
Used by: GDTest/TelemetryTest.gd, GDTest/TelemetryUploaderTest.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

