class_name TelemetrySink
extends RefCounted
## Abstract destination for telemetry events. The recorder never cares where an
## event goes: Stage 1 writes newline-delimited JSON to the local spool, Stage 2
## adds an HTTP batch uploader with the same interface.
##
## @author TheGreatJellyfish
## @version 11/26/2026


## Persists one already-serialised event. Implementations must never throw and
## must never block for long, because this runs inside the turn loop.
func write_event(_event: Dictionary) -> void:
	pass


## Pushes any buffered bytes to their destination.
func flush() -> void:
	pass

## Prepares the destination for one run id. Base implementation does nothing.
func open(_run_id: String) -> void:
	pass

## Releases the destination (closes the file handle, ends a batch, ...).
func close() -> void:
	pass


## True once the destination is ready to accept events.
func is_open() -> bool:
	return false
