<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/HttpBatchSink.gd` — `class_name HttpBatchSink` extends `JsonlFileSink`

`23` lines · [back to the map](../../../CODEBASE_MAP.md)

> Stage 2 telemetry sink: the same crash-safe, per-event spooling as JsonlFileSink, but written into the upload outbox instead of the local spool, so Core/Telemet…

Sections: Constants · Lifecycle Methods

Constants:
- L16 `OUTBOX_DIR: String = "user://telemetry/outbox"`

Private:
- L20-21 `_init`

Uses: JsonlFileSink
Used by: GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd
Loads: —

