<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetryUploader.gd` — `class_name TelemetryUploader` extends `Node`

`230` lines · [back to the map](../../../CODEBASE_MAP.md)

> Drains the telemetry outbox to the metric server, in the background. It picks up the per-run JSONL files HttpBatchSink leaves in user://telemetry/outbox/, POSTs…

Sections: Signals · Constants · Exports · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L19 `drain_finished(sent: int, failed: int)` — Emitted after one drain pass: `sent` files moved to the archive, `failed` kept.

Constants:
- L23 `OUTBOX_DIR: String = "user://telemetry/outbox"`
- L24 `ARCHIVE_DIR: String = "user://telemetry/archive"`
- L25 `ENDPOINT_SETTING: String = "telemetry/endpoint"`
- L26 `ANON_KEY_SETTING: String = "telemetry/anon_key"`
- L28 `MAX_EVENTS: int = 500` — Events per POST; the Edge function rejects larger batches.
- L29 `REQUEST_TIMEOUT: float = 20.0`
- L31 `RETRY_DELAY: float = 60.0` — Seconds to wait before retrying the outbox after a failed drain.

Exports:
- L36 `endpoint_override: String = ""` — Overrides the `telemetry/endpoint` project setting when set (tests use this).

State:
- L40 `_http: HTTPRequest`
- L41 `_busy: bool = false`
- L42 `_pending_files: PackedStringArray = PackedStringArray()`
- L43 `_current_file: String = ""`
- L44 `_current_batches: Array = []`
- L45 `_current_index: int = 0`
- L46 `_sent: int = 0`
- L47 `_failed: int = 0`

Public API:
- L64-71 `is_enabled() -> bool` — True when an endpoint is configured and the player agreed to telemetry during this launch (a stored answer from an earlier session is not enough).
- L74-77 `endpoint() -> String`
- L80-81 `anon_key() -> String`
- L87-94 `drain() -> void` — Starts one drain pass. Safe to call often: a second call while a pass is in flight is ignored, and a disabled uploader does nothing.
- L200-204 `retry_later() -> void` — Waits, then tries the whole outbox again (a dropped connection is temporary).

Private:
- L51-59 `_ready`
- L99-107 `_list_outbox`
- L111-126 `_next_file`
- L129-154 `_read_batches`
- L157-169 `_post_current`
- L174-181 `_archive`
- L185-189 `_fail_current`
- L192-196 `_finish`
- L209-227 `_on_request_completed`

Uses: JsonlFileSink, TelemetryConsent
Used by: GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

