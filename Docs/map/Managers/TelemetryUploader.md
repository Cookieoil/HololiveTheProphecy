<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryUploader.gd` — `class_name TelemetryUploader` extends `Node`

`426` lines · [back to the map](../../CODEBASE_MAP.md)

> Drains the telemetry outbox to the metric server, in the background. It picks up the per-run JSONL files HttpBatchSink leaves in user://telemetry/outbox/, POSTs…

Sections: Signals · Constants · Exports · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Private Methods · (+1 more)

Signals:
- L27 `drain_finished(sent: int, failed: int, rejected: int)` — Emitted after one drain pass: `sent` files moved to the archive, `failed` kept in the outbox for a later retry, `rejected` quarantined as permanently undelivera…

Constants:
- L31 `OUTBOX_DIR: String = "user://telemetry/outbox"`
- L32 `ARCHIVE_DIR: String = "user://telemetry/archive"`
- L35 `REJECTED_DIR: String = "user://telemetry/rejected"` — Files the server refused outright (a malformed batch) are parked here instead of being retried forever, which would block every later run behind them.
- L36 `ENDPOINT_SETTING: String = "telemetry/endpoint"`
- L37 `ANON_KEY_SETTING: String = "telemetry/anon_key"`
- L39 `MAX_EVENTS: int = 500` — Events per POST; the Edge function rejects larger batches.
- L40 `REQUEST_TIMEOUT: float = 20.0`
- L43 `RETRY_DELAY: float = 60.0` — Seconds to wait before retrying the outbox after a failed drain, and the ceiling the exponential backoff climbs to.
- L44 `RETRY_MAX_DELAY: float = 600.0`
- L48 `ARCHIVE_KEEP: int = 200` — How many delivered runs the local archive keeps. The archive is a diagnostic trail, not the record (the server holds that), so it is capped rather than left to…

Exports:
- L53 `endpoint_override: String = ""` — Overrides the `telemetry/endpoint` project setting when set (tests use this).

State:
- L60 `telemetry_root: String = "user://telemetry"` — The folder the telemetry subdirectories live in. Defaults to the real `user://telemetry`; a suite points it at a scratch folder so it never reads or moves the p…
- L63 `archive_keep: int = ARCHIVE_KEEP` — How many delivered runs the archive keeps (see ARCHIVE_KEEP); a suite lowers it instead of creating hundreds of files.
- L67 `transport_override: Callable = Callable()` — Test seam: when set, replaces the HTTPRequest so a suite can drive response codes without a socket. `Callable(url: String, anon_key: String, body: String) -> Ar…
- L70 `ignore_gates: bool = false` — Test seam: skips the headless / consent gates so a suite can exercise the drain state machine. Never set in game code.
- L72 `last_rejected: int = 0` — Diagnostics only: files quarantined by the most recent drain pass.
- L76 `_http: HTTPRequest`
- L79 `_retry_timer: Timer` — One-shot retry clock. A Timer node (not SceneTreeTimer) so it pauses with the scene and is freed with the uploader instead of firing into a dead node.
- L80 `_busy: bool = false`
- L81 `_pending_files: PackedStringArray = PackedStringArray()`
- L82 `_current_file: String = ""`
- L83 `_current_batches: Array = []`
- L84 `_current_index: int = 0`
- L85 `_sent: int = 0`
- L86 `_failed: int = 0`
- L87 `_rejected: int = 0`
- L89 `_retry_delay: float = RETRY_DELAY` — Current retry wait, doubled after every failed pass up to RETRY_MAX_DELAY.

Public API:
- L116-125 `is_enabled() -> bool` — True when an endpoint is configured and the player agreed to telemetry during this launch (a stored answer from an earlier session is not enough).
- L128-131 `endpoint() -> String`
- L134-135 `anon_key() -> String`
- L141-142 `outbox_path() -> String` — The four telemetry directories, resolved from `telemetry_root` so a suite only has to redirect one path. Each is derived from the same constant the game uses (H…
- L146-147 `archive_path() -> String` — Where a delivered run is parked (see `_archive`).
- L151-152 `rejected_path() -> String` — Where a batch the server refused outright is parked (see `_reject_current`).
- L156-157 `spool_path() -> String` — The Stage 1 spool, swept for crash orphans when a server is configured.
- L162-170 `drain() -> void` — Starts one drain pass. Safe to call often: a second call while a pass is in flight is ignored, and a disabled uploader does nothing.
- L381-386 `retry_later() -> void` — Waits, then tries the whole outbox again (a dropped connection is temporary). The wait doubles after each failed pass so a server that is down is not hammered o…

Private:
- L93-110 `_ready`
- L176-184 `_list_files`
- L191-195 `_promote_orphans`
- L199-214 `_next_file`
- L217-242 `_read_batches`
- L245-256 `_post_current`
- L259-263 `_headers`
- L268-277 `_apply_transport`
- L280-290 `_coerce_int`
- L294-301 `_apply_response`
- L304-305 `_is_success`
- L311-316 `_is_transient`
- L320-330 `_advance_batch`
- L335-339 `_archive`
- L344-350 `_reject_current`
- L355-361 `_move_to`
- L365-369 `_fail_current`
- L372-375 `_finish`
- L389-390 `_reset_backoff`
- L395-412 `_prune_archive`
- L417-423 `_on_request_completed`

Uses: JsonlFileSink, TelemetryConsent
Used by: GDTest/TelemetryTest.gd, GDTest/TelemetryUploaderTest.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

