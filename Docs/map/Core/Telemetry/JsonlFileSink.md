<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/JsonlFileSink.gd` — `class_name JsonlFileSink` extends `TelemetrySink`

`94` lines · [back to the map](../../../CODEBASE_MAP.md)

> Stage 1 telemetry sink: appends one JSON object per line to a per-run file under user://telemetry/spool/. Every line is flushed as it is written, so a crash or…

Sections: Constants · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L14 `DEFAULT_DIR: String = "user://telemetry/spool"`
- L15 `FILE_PREFIX: String = "run_"`
- L16 `FILE_SUFFIX: String = ".jsonl"`

State:
- L20 `dir_path: String = DEFAULT_DIR`
- L21 `file_path: String = ""`
- L22 `event_count: int = 0`
- L26 `_file: FileAccess = null`

Public API:
- L38-43 `open(run_id: String) -> void` — Truncates (or creates) the spool file for one run id.
- L46-51 `write_event(event: Dictionary) -> void`
- L54-56 `flush() -> void`
- L59-62 `close() -> void`
- L65-66 `is_open() -> bool`
- L70-85 `read_all() -> Array` — Reads every event back (used by the analyser and by tests).

Private:
- L30-33 `_init`
- L89-92 `_ensure_dir`

Uses: TelemetrySink
Used by: Core/Telemetry/HttpBatchSink.gd, GDTest/TelemetryTest.gd, GDTest/TelemetryUploaderTest.gd, Managers/TelemetryManager.gd, Managers/TelemetryUploader.gd
Loads: —

