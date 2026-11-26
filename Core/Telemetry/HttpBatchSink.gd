class_name HttpBatchSink
extends JsonlFileSink
## Stage 2 telemetry sink: the same crash-safe, per-event spooling as
## JsonlFileSink, but written into the upload outbox instead of the local spool, so
## Core/Telemetry/TelemetryUploader.gd can drain it to the metric server in the
## background.
##
## Spooling to disk first is deliberate: a dropped connection, a quit or a crash
## never loses a decision, because the file only leaves the outbox once the server
## has confirmed the batch.
##
## @author TheGreatJellyfish
## @version 11/26/2026

#region Constants
const OUTBOX_DIR: String = "user://telemetry/outbox"
#endregion

#region Lifecycle Methods
func _init(run_id: String = "") -> void:
	super(OUTBOX_DIR, run_id)
#endregion
