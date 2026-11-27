<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryUploader.gd` — `class_name TelemetryUploader` extends `Node`

`238` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L43 `_retry_timer: Timer` — One-shot retry clock. A Timer node (not SceneTreeTimer) so it pauses with the scene and is freed with the uploader instead of firing into a dead node.
- L44 `_busy: bool = false`
- L45 `_pending_files: PackedStringArray = PackedStringArray()`
- L46 `_current_file: String = ""`
- L47 `_current_batches: Array = []`
- L48 `_current_index: int = 0`
- L49 `_sent: int = 0`
- L50 `_failed: int = 0`

Public API:
- L73-80 `is_enabled() -> bool` — True when an endpoint is configured and the player agreed to telemetry during this launch (a stored answer from an earlier session is not enough).
- L83-86 `endpoint() -> String`
- L89-90 `anon_key() -> String`
- L96-103 `drain() -> void` — Starts one drain pass. Safe to call often: a second call while a pass is in flight is ignored, and a disabled uploader does nothing.
- L209-212 `retry_later() -> void` — Waits, then tries the whole outbox again (a dropped connection is temporary).

Private:
- L54-68 `_ready`
- L108-116 `_list_outbox`
- L120-135 `_next_file`
- L138-163 `_read_batches`
- L166-178 `_post_current`
- L183-190 `_archive`
- L194-198 `_fail_current`
- L201-205 `_finish`
- L217-235 `_on_request_completed`

Uses: JsonlFileSink, TelemetryConsent
Used by: GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

