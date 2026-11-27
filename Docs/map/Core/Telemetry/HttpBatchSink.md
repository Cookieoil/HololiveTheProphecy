<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/HttpBatchSink.gd` — `class_name HttpBatchSink` extends `JsonlFileSink`

`54` lines · [back to the map](../../../CODEBASE_MAP.md)

> Stage 2 telemetry sink: the same crash-safe, per-event spooling as JsonlFileSink, but the finished file is promoted into the upload outbox so Managers/Telemetry…

Sections: Constants · Public Variables · Lifecycle Methods · Public Methods

Constants:
- L17 `OUTBOX_DIR: String = "user://telemetry/outbox"`

State:
- L23 `last_promotion_ok: bool = true` — False when the finished run could not be moved into the outbox (it stays in the spool instead of being lost). Diagnostics only; nothing depends on it.

Public API:
- L34-51 `close() -> void` — Closes the run file and moves it to the outbox, so only complete runs are ever up for upload.

Private:
- L27-28 `_init`

Uses: JsonlFileSink
Used by: GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd
Loads: —

