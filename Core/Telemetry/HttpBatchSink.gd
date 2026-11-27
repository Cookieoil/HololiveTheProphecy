class_name HttpBatchSink
extends JsonlFileSink
## Stage 2 telemetry sink: the same crash-safe, per-event spooling as
## JsonlFileSink, but the finished file is promoted into the upload outbox so
## Managers/TelemetryUploader.gd can drain it to the metric server.
##
## The promotion happens in `close()`, on purpose: while a battle is still running
## the file stays in the local spool like any other run. The uploader therefore
## can never list a half-written run, never upload a battle without its
## `run_ended`, and never try to rename a file that is still open (which fails on
## Windows with the write handle held).
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const OUTBOX_DIR: String = "user://telemetry/outbox"
#endregion

#region Public Variables
## False when the finished run could not be moved into the outbox (it stays in the
## spool instead of being lost). Diagnostics only; nothing depends on it.
var last_promotion_ok: bool = true
#endregion

#region Lifecycle Methods
func _init(run_id: String = "") -> void:
	super(DEFAULT_DIR, run_id)
#endregion

#region Public Methods
## Closes the run file and moves it to the outbox, so only complete runs are ever
## up for upload.
func close() -> void:
	var source: String = file_path
	super()
	last_promotion_ok = true
	if source.is_empty() or not FileAccess.file_exists(source):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTBOX_DIR))
	var target: String = OUTBOX_DIR + "/" + source.get_file()
	var error: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source),
		ProjectSettings.globalize_path(target)
	)
	if error != OK:
		# Leave it in the spool rather than losing the run: the spool keeps it
		# readable, and a later close can still promote it.
		last_promotion_ok = false
		return
	file_path = target
#endregion

