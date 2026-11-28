<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetrySink.gd` — `class_name TelemetrySink` extends `RefCounted`

`33` lines · [back to the map](../../../CODEBASE_MAP.md)

> Abstract destination for telemetry events. The recorder never cares where an event goes: Stage 1 writes newline-delimited JSON to the local spool, Stage 2 adds…

Public API:
- L13-14 `write_event(_event: Dictionary) -> void` — Persists one already-serialised event. Implementations must never throw and must never block for long, because this runs inside the turn loop.
- L18-19 `flush() -> void` — Pushes any buffered bytes to their destination.
- L22-23 `open(_run_id: String) -> void` — Prepares the destination for one run id. Base implementation does nothing.
- L26-27 `close() -> void` — Releases the destination (closes the file handle, ends a batch, ...).
- L31-32 `is_open() -> bool` — True once the destination is ready to accept events.

Uses: —
Used by: Core/Telemetry/JsonlFileSink.gd, GDTest/SkillContextFactoryTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, GDTest/TurnLoopTest.gd, Managers/TelemetryManager.gd
Loads: —

