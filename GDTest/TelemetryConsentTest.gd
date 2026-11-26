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
	# Launch flags are process-wide, so they are cleared between suites.
	TelemetryConsent.reset_launch_flag()
	TelemetryConsentPopup.reset_launch_flag()
	_remove_tree(_temp_dir)
	_remove_tree(TEMP_ROOT)


func before_test() -> void:
	var run: String = TelemetrySchema.new_id()
	_consent_path = "%s/consent_%s.json" % [_temp_dir, run]
	_player_path = "%s/player_%s.txt" % [_temp_dir, run]


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


## Locks the disclosure wording and the button order the mock-up asks for.
func test_popup_shows_the_required_wording_and_button_order() -> void:
	var popup: TelemetryConsentPopup = _make_popup()
	assert_bool(popup.header_label != null).is_true()
	assert_str(popup.header_label.text).is_equal("Data Consent")
	assert_bool(popup.main_label != null).is_true()
	assert_str(popup.main_label.text).is_equal("I need your consent to collect anonymous gameplay data.")
	assert_bool(popup.sub_label != null).is_true()
	assert_str(popup.sub_label.text).is_equal(
		"Your data will only be used to help improve the game design and balance. "
		+ "None of your personal data will be recorded.")
	# Allow is the left button, Decline the right one.
	assert_str(popup.agree_button.text).is_equal("Allow")
	assert_str(popup.decline_button.text).is_equal("Decline")
	assert_bool(popup.buttons_row != null).is_true()
	assert_int(popup.buttons_row.get_child_count()).is_equal(2)
	assert_str(str(popup.buttons_row.get_child(0).name)).is_equal("AllowButton")
	assert_str(str(popup.buttons_row.get_child(1).name)).is_equal("DeclineButton")
	# The header plate carries the thicker frame.
	assert_bool(TelemetryConsentPopup.HEADER_BORDER > TelemetryConsentPopup.FRAME_BORDER).is_true()


## BattleScene mounts the popup on a CanvasLayer. A top-level Control gets no parent
## rect from a CanvasLayer, so a FULL_RECT preset used to collapse to zero and left
## the window stuck at the top-left corner. This locks the window to the screen and
## the frame to the middle of it.
func test_popup_fills_and_centres_on_a_canvas_layer() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TestConsentLayer"
	layer.layer = 35
	add_child(layer)
	auto_free(layer)

	var popup: TelemetryConsentPopup = TelemetryConsentPopup.new()
	popup.name = "TestConsentPopup"
	popup.consent = TelemetryConsent.new(_consent_path)
	layer.add_child(popup)
	auto_free(popup)
	popup.open()
	# Two frames: one for the containers to lay out, one for the frame to settle.
	await get_tree().process_frame
	await get_tree().process_frame

	var screen: Vector2 = popup.get_viewport_rect().size
	# Guard against a vacuous pass: a 0-sized viewport would satisfy the comparisons
	# below no matter how broken the layout is.
	assert_bool(screen.x > 0.0 and screen.y > 0.0).is_true()
	assert_bool(popup.position.is_equal_approx(Vector2.ZERO)).is_true()
	assert_bool(popup.size.is_equal_approx(screen)).is_true()
	assert_bool(popup.is_open()).is_true()

	var frame: Control = popup.get_node_or_null("Center/Frame")
	assert_bool(frame != null).is_true()
	var frame_center: Vector2 = frame.position + frame.size * 0.5
	var screen_center: Vector2 = screen * 0.5
	assert_bool(absf(frame_center.x - screen_center.x) < 2.0).is_true()
	assert_bool(absf(frame_center.y - screen_center.y) < 2.0).is_true()


## The disclosure is asked once per *launch*, not once ever: a stored "Allow" from a
## previous session must not silence it, while the reload behind "Play Again" (same
## launch) must not ask again.
func test_the_prompt_comes_back_on_a_new_launch() -> void:
	TelemetryConsentPopup.reset_launch_flag()
	TelemetryConsent.new(_consent_path).decide(true) # answered in an earlier session
	assert_bool(TelemetryConsentPopup.should_prompt_this_launch()).is_true()

	var popup: TelemetryConsentPopup = _make_popup()
	popup.open()
	assert_bool(TelemetryConsentPopup.should_prompt_this_launch()).is_false()

	TelemetryConsentPopup.reset_launch_flag()
	assert_bool(TelemetryConsentPopup.should_prompt_this_launch()).is_true()


## A battle starts after the disclosure is answered, so the recorder must use the
## answer given this launch, not the one it loaded when it was constructed.
func test_a_battle_started_after_the_answer_uses_it() -> void:
	# Constructed while the stored answer is still "declined".
	TelemetryConsent.new(_consent_path).decide(false)
	var sink: MemorySink = MemorySink.new()
	var recorder: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path, sink)
	assert_bool(recorder.consent.is_granted()).is_false()

	# The player then allows it, which is what the popup writes.
	TelemetryConsent.new(_consent_path).decide(true)

	recorder.start_run(_make_state())
	assert_bool(recorder.enabled).is_true()
	assert_int(sink.events.size()).is_equal(1)
	recorder.shutdown()


## A stored "granted" left over from an earlier launch must not authorise collection
## on its own: the player has to be asked in the session that is running.
func test_a_stale_granted_file_cannot_start_collection() -> void:
	TelemetryConsent.new(_consent_path).decide(true)
	assert_bool(TelemetryConsent.answered_this_launch()).is_true()
	# The next launch starts with no answer yet, even though the file says granted.
	TelemetryConsent.reset_launch_flag()

	var sink: MemorySink = MemorySink.new()
	var recorder: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path, sink)
	var state: GameState = _make_state()
	recorder.start_run(state)

	assert_bool(recorder.consent.is_granted()).is_true()
	assert_bool(TelemetryConsent.answered_this_launch()).is_false()
	assert_bool(recorder.enabled).is_false()
	assert_int(sink.events.size()).is_equal(0)
	assert_bool(FileAccess.file_exists(_player_path)).is_false()
	recorder.shutdown()


## The stage must stay translucent enough to see the battle, and the header plate
## must be lifted so its border sits centred on the window's top edge.
func test_dim_is_translucent_and_the_header_is_lifted() -> void:
	assert_bool(TelemetryConsentPopup.DIM_COLOR.a < 0.75).is_true()

	var popup: TelemetryConsentPopup = _make_popup()
	popup.open()
	await get_tree().process_frame
	await get_tree().process_frame

	var slot: Control = popup.get_node_or_null("Center/Frame/Column/HeaderSlot")
	var plate: Control = popup.get_node_or_null("Center/Frame/Column/HeaderSlot/HeaderRow/Header")
	assert_bool(slot != null).is_true()
	assert_bool(plate != null).is_true()
	assert_bool(plate.size.y > 0.0).is_true()
	var expected: int = -int(roundf(plate.size.y * 0.5))
	assert_bool(expected < 0).is_true()
	assert_int(slot.get_theme_constant("margin_top")).is_equal(expected)


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
	var sink: MemorySink = MemorySink.new()
	var manager: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path, sink)
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
	var sink: MemorySink = MemorySink.new()
	var manager: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path, sink)
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


## Regression lock: a recorder with no test sink must never collect in a headless
## run, even when the player has agreed - that is what keeps the CI gates, the
## validator and every test run from writing a spool file.
func test_a_default_recorder_never_collects_headless() -> void:
	TelemetryConsent.new(_consent_path).decide(true)
	var manager: TelemetryManager = TelemetryManager.new(_consent_path, _temp_dir, _player_path)
	assert_bool(manager.sink_override == null).is_true()
	assert_bool(manager.may_collect()).is_false()
	var state: GameState = _make_state()
	manager.start_run(state)
	assert_bool(manager.enabled).is_false()
	assert_bool(manager.run_id.is_empty()).is_true()
	assert_bool(FileAccess.file_exists(_player_path)).is_false()
#endregion
