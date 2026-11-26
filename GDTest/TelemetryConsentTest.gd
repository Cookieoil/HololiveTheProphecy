class_name TelemetryConsentTest
extends GdUnitTestSuite
## Locks the telemetry opt-in gate:
##   - an unanswered consent is UNDECIDED and needs the prompt
##   - "Agree" grants and persists; "Decline" persists and never grants
##   - a corrupt file falls back to UNDECIDED instead of granting
##   - the popup's two buttons write consent and emit the right answer
##   - a declined consent collects nothing at all
##
## @author TheGreatJellyfish
## @version 11/26/2026

const TEMP_ROOT: String = "user://telemetry_test"


## In-memory sink so a test never writes a spool file.
class MemorySink extends TelemetrySink:
	var events: Array = []
	var opened: bool = false

	func open(_run_id: String) -> void:
		opened = true

	func write_event(event: Dictionary) -> void:
		events.append(event)

	func is_open() -> bool:
		return opened

	func close() -> void:
		opened = false


var _temp_dir: String = ""
var _consent_path: String = ""
var _player_path: String = ""


func before() -> void:
	_temp_dir = "%s/%s" % [TEMP_ROOT, TelemetrySchema.new_id()]


func after() -> void:
	_remove_tree(_temp_dir)
	_remove_tree(TEMP_ROOT)


func before_test() -> void:
	var run: String = TelemetrySchema.new_id()
	_consent_path = "%s/consent_%s.json" % [_temp_dir, run]
	_player_path = "%s/player_%s.txt" % [_temp_dir, run]


func after_test() -> void:
	TelemetryManager.enabled_override = TelemetryManager.FORCE_ENGINE
	TelemetryManager.sink_override = null


## Deletes a directory tree under user:// (tests only).
func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)
		for sub_name: String in dir.get_directories():
			_remove_tree(path + "/" + sub_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_consent_file(version: int, status: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_temp_dir))
	var file: FileAccess = FileAccess.open(_consent_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": status, "consent_version": version}))
	file.close()


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	var data: UnitData = UnitData.new()
	data.unit_id = "ally"
	data.display_name = "Ally"
	data.max_hp = 20
	state.initialize_allies([data] as Array[UnitData])
	return state


#region Consent record
func test_undecided_by_default_and_needs_prompt() -> void:
	var consent: TelemetryConsent = TelemetryConsent.new(_consent_path)
	assert_int(consent.status).is_equal(TelemetryConsent.Status.UNDECIDED)
	assert_bool(consent.needs_prompt()).is_true()
	assert_bool(consent.is_decided()).is_false()
	assert_bool(consent.is_granted()).is_false()


func test_agree_grants_and_persists_across_a_reload() -> void:
	var consent: TelemetryConsent = TelemetryConsent.new(_consent_path)
	consent.decide(true)
	assert_bool(consent.is_granted()).is_true()
	assert_bool(consent.needs_prompt()).is_false()
	assert_bool(FileAccess.file_exists(_consent_path)).is_true()
	# A fresh read (a new session) must see the same answer.
	var reloaded: TelemetryConsent = TelemetryConsent.new(_consent_path)
	assert_bool(reloaded.is_granted()).is_true()
	assert_int(reloaded.consent_version).is_equal(TelemetryConsent.CONSENT_VERSION)


func test_decline_persists_and_never_grants() -> void:
	var consent: TelemetryConsent = TelemetryConsent.new(_consent_path)
	consent.decide(false)
	assert_bool(consent.is_granted()).is_false()
	assert_bool(consent.needs_prompt()).is_false()
	var reloaded: TelemetryConsent = TelemetryConsent.new(_consent_path)
	assert_bool(reloaded.is_granted()).is_false()
	assert_int(reloaded.status).is_equal(TelemetryConsent.Status.DECLINED)


func test_a_new_disclosure_version_re_asks_everyone() -> void:
	_write_consent_file(TelemetryConsent.CONSENT_VERSION - 1, TelemetryConsent.STATUS_GRANTED)
	var consent: TelemetryConsent = TelemetryConsent.new(_consent_path)
	assert_bool(consent.needs_prompt()).is_true()
	assert_bool(consent.is_granted()).is_false()


func test_a_corrupt_file_needs_the_prompt_and_never_grants() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_temp_dir))
	var file: FileAccess = FileAccess.open(_consent_path, FileAccess.WRITE)
	file.store_string("this is not json")
	file.close()
	var consent: TelemetryConsent = TelemetryConsent.new(_consent_path)
	assert_bool(consent.needs_prompt()).is_true()
	assert_bool(consent.is_granted()).is_false()
#endregion


#region Consent popup
func _make_popup() -> TelemetryConsentPopup:
	var popup: TelemetryConsentPopup = TelemetryConsentPopup.new()
	popup.consent = TelemetryConsent.new(_consent_path)
	add_child(popup)
	auto_free(popup)
	return popup


func test_popup_agree_writes_consent_and_emits_true() -> void:
	var popup: TelemetryConsentPopup = _make_popup()
	var answers: Array[bool] = []
	popup.decided.connect(func(agreed: bool) -> void: answers.append(agreed))
	popup.open()
	assert_bool(popup.is_open()).is_true()
	assert_bool(popup.agree_button != null).is_true()
	assert_bool(popup.decline_button != null).is_true()

	popup.agree_button.pressed.emit()

	assert_int(answers.size()).is_equal(1)
	assert_bool(answers[0]).is_true()
	assert_bool(popup.is_open()).is_false()
	# Persisted: the next session sees the granted answer.
	assert_bool(TelemetryConsent.new(_consent_path).is_granted()).is_true()


func test_popup_decline_writes_consent_and_emits_false() -> void:
	var popup: TelemetryConsentPopup = _make_popup()
	var answers: Array[bool] = []
	popup.decided.connect(func(agreed: bool) -> void: answers.append(agreed))
	popup.open()

	popup.decline_button.pressed.emit()

	assert_int(answers.size()).is_equal(1)
	assert_bool(answers[0]).is_false()
	assert_bool(TelemetryConsent.new(_consent_path).is_granted()).is_false()
#endregion


#region No collection without consent
func test_declined_consent_records_nothing() -> void:
	TelemetryManager.enabled_override = TelemetryManager.FORCE_ON
	var sink: MemorySink = MemorySink.new()
	TelemetryManager.sink_override = sink
	var manager: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path)
	var state: GameState = _make_state()

	manager.start_run(state)

	assert_bool(manager.enabled).is_false()
	assert_bool(manager.run_id.is_empty()).is_true()
	assert_int(sink.events.size()).is_equal(0)
	# Every hook must stay a no-op.
	manager.begin_decision(state, [] as Array[EnemyIntent])
	manager.end_decision({"type": "end_turn"}, state)
	manager.record_turn_started(state, [] as Array[EnemyIntent], 6)
	manager.record_turn_ended(state)
	manager.end_run(true, TelemetryManager.REASON_FINAL_WAVE, state)
	assert_int(sink.events.size()).is_equal(0)
	assert_bool(FileAccess.file_exists(_player_path)).is_false()


func test_granted_consent_opens_a_run_and_writes_events() -> void:
	TelemetryConsent.new(_consent_path).decide(true)
	TelemetryManager.enabled_override = TelemetryManager.FORCE_ON
	var sink: MemorySink = MemorySink.new()
	TelemetryManager.sink_override = sink
	var manager: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path)
	var state: GameState = _make_state()

	manager.start_run(state)

	assert_bool(manager.enabled).is_true()
	assert_bool(manager.run_id.is_empty()).is_false()
	assert_int(manager.player_anon_id.length()).is_equal(36)
	assert_int(manager.balance_hash.length()).is_equal(64)
	assert_int(sink.events.size()).is_equal(1)
	var first_event: Dictionary = sink.events[0]
	assert_str(str(first_event.get("type", ""))).is_equal("run_started")
	manager.shutdown()
#endregion
