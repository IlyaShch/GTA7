extends Node

signal qte_succeeded
# A single round failed; do NOT connect this directly to Game Over.
signal qte_failed
# escaped=false is emitted only after two cumulative failures.
signal sequence_finished(escaped: bool)

@export var qte_music: AudioStream
@export var chase_music: AudioStreamPlayer
@export_range(0.5, 30.0, 0.5) var duration: float = 5.0
@export_range(0.1, 30.0, 0.1) var first_delay: float = 3.0
@export_range(0.1, 30.0, 0.1) var between_rounds: float = 3.0
@export_range(0.1, 5.0, 0.1) var feedback_duration: float = 1.0
@export var music_volume_db: float = -10.0
@export var auto_start: bool = true

const ROUNDS: Array[Dictionary] = [
	{"king": "Do you know who I am?", "reply": "my retirement fund"},
	{"king": "I need a drink.", "reply": "stay alive until payday"},
	{"king": "If you're kidnapping me, at least give me a smoke.", "reply": "one last cigarette"},
	{"king": "My guards will hang you for this.", "reply": "they helped me plan it"},
	{"king": "How much did they pay you?", "reply": "less than your taxes"},
	{"king": "I demand a royal funeral.", "reply": "best i can do is a ditch"},
]

enum Phase { IDLE, WAITING, INPUT, FEEDBACK, DONE }
const MAX_FAILURES: int = 2
var phase: int = Phase.IDLE
var round_index: int = 0
var failure_count: int = 0
var qte_active: bool = false
var _music_session: bool = false
var _resume_chase: bool = false
var _timer: Timer
var _music: AudioStreamPlayer
var _canvas: CanvasLayer
var _panel: PanelContainer
var _heading: Label
var _dialogue: Label
var _target: Label
var _entry: LineEdit
var _clock: Label
var _bar: ProgressBar
var _status: Label


func _ready() -> void:
	_build_ui()
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	if chase_music == null:
		chase_music = get_node_or_null("../Music") as AudioStreamPlayer
	if qte_music != null:
		_music.stream = _one_shot_copy(qte_music)
	if auto_start:
		call_deferred("start_sequence")


func _process(_delta: float) -> void:
	if phase == Phase.INPUT:
		_bar.value = _timer.time_left
		_clock.text = "Time left: %.1f s" % _timer.time_left


func start_sequence() -> void:
	# Public entry point for a corridor trigger; safe against double starts.
	if phase != Phase.IDLE and phase != Phase.DONE:
		return
	if _music.stream == null:
		_panel.show()
		_heading.text = "QTE setup needed"
		_dialogue.text = "Assign the QTE music file to KingQTE > Qte Music in Inspector."
		_entry.hide()
		_bar.hide()
		push_error("KingQTE: qte_music is not assigned; sequence has not started.")
		return
	_panel.hide()
	round_index = 0
	failure_count = 0
	phase = Phase.WAITING
	_timer.start(first_delay)


func start_qte() -> void:
	# Starts the current round. During normal play the sequence calls this.
	if phase == Phase.INPUT or phase == Phase.FEEDBACK:
		return
	if round_index >= ROUNDS.size() or _music.stream == null:
		return
	_begin_music()
	phase = Phase.INPUT
	qte_active = true
	_panel.show()
	_heading.text = "THE KING  |  %d / %d  |  Failures: %d / %d" % [round_index + 1, ROUNDS.size(), failure_count, MAX_FAILURES]
	_dialogue.text = str(ROUNDS[round_index]["king"])
	_target.text = "Type: " + str(ROUNDS[round_index]["reply"])
	_status.text = "Type the reply, then press Enter."
	_status.modulate = Color.WHITE
	_entry.show()
	_entry.editable = true
	_entry.clear()
	_entry.grab_focus()
	_bar.show()
	_bar.max_value = duration
	_bar.value = duration
	_clock.text = "Time left: %.1f s" % duration
	_timer.start(duration)


func _on_submitted(answer: String) -> void:
	if phase != Phase.INPUT:
		return
	if _timer.time_left <= 0.0:
		_resolve(false)
	elif _normalize(answer) == _normalize(str(ROUNDS[round_index]["reply"])):
		complete_qte()
	else:
		_status.text = "Not quite. Keep editing and press Enter again!"
		_status.modulate = Color(1.0, 0.65, 0.3)
		_entry.grab_focus()


func complete_qte() -> void:
	# Same public method as the previous timer mechanic.
	if phase == Phase.INPUT:
		_resolve(_timer.time_left > 0.0)


func cancel_qte() -> void:
	phase = Phase.IDLE
	qte_active = false
	_timer.stop()
	_entry.release_focus()
	_panel.hide()
	_end_music()


func _resolve(success: bool) -> void:
	if phase != Phase.INPUT:
		return
	_timer.stop()
	phase = Phase.FEEDBACK
	qte_active = false
	# End the QTE track immediately on answer/timeout, even if it is mid-song.
	# If it finishes early, it stays silent until the QTE resolves.
	_end_music()
	_entry.editable = false
	_entry.release_focus()
	if success:
		_status.text = "The king falls silent..."
	else:
		failure_count += 1
		_status.text = "GUARDS!  The guards are getting closer! (1 / 2)"
		if failure_count >= MAX_FAILURES:
			_status.text = "GUARDS!  You have been caught. (2 / 2)"
	_heading.text = "THE KING  |  %d / %d  |  Failures: %d / %d" % [round_index + 1, ROUNDS.size(), failure_count, MAX_FAILURES]
	_status.modulate = Color(0.45, 1.0, 0.55) if success else Color(1.0, 0.35, 0.35)
	if not success:
		_bar.value = 0.0
		_clock.text = "Time left: 0.0 s"
	_timer.start(feedback_duration)
	# Emit last: handlers can cancel or remove the scene safely.
	if success:
		qte_succeeded.emit()
	else:
		qte_failed.emit()


func _on_timeout() -> void:
	match phase:
		Phase.WAITING:
			start_qte()
		Phase.INPUT:
			_resolve(false)
		Phase.FEEDBACK:
			if failure_count >= MAX_FAILURES:
				_finish_sequence(false)
				return
			round_index += 1
			if round_index >= ROUNDS.size():
				_finish_sequence(true)
			else:
				_panel.hide()
				phase = Phase.WAITING
				_timer.start(between_rounds)


func _finish_sequence(escaped: bool) -> void:
	phase = Phase.DONE
	qte_active = false
	_timer.stop()
	_end_music()
	_panel.show()
	_heading.text = "ESCAPED!" if escaped else "CAUGHT!"
	_dialogue.text = "The king is your problem now." if escaped else "The royal guards have caught up."
	_target.text = ""
	_entry.hide()
	_bar.hide()
	_clock.text = ""
	_status.text = ""
	# Connect this to Chase/Main to switch to your own ending scene.
	sequence_finished.emit(escaped)


func _begin_music() -> void:
	if _music_session:
		return
	_music_session = true
	_resume_chase = false
	if is_instance_valid(chase_music):
		_resume_chase = chase_music.playing and not chase_music.stream_paused
		if _resume_chase:
			chase_music.stream_paused = true
	_music.play()


func _end_music() -> void:
	_music_session = false
	if is_instance_valid(_music):
		_music.stop()
	if _resume_chase and is_instance_valid(chase_music):
		chase_music.stream_paused = false
	_resume_chase = false


func _one_shot_copy(source: AudioStream) -> AudioStream:
	# Do not change shared imported resources used by other scenes.
	# Explicitly disable looping, even if enabled in the import settings.
	# Use a WAV, OGG or MP3 audio file for qte_music.
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = false
	elif stream is AudioStreamMP3:
		stream.loop = false
	return stream


func _normalize(value: String) -> String:
	var result: String = ""
	for character in value.to_lower():
		if "abcdefghijklmnopqrstuvwxyz0123456789".contains(character):
			result += character
	return result


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 50
	add_child(_canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)
	_panel = PanelContainer.new()
	root.add_child(_panel)
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.04
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.08, 0.96)
	style.border_color = Color(0.7, 0.48, 0.18)
	style.set_border_width_all(3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_heading = _new_label(column, 20)
	_dialogue = _new_label(column, 24)
	_target = _new_label(column, 22)
	_target.modulate = Color(1.0, 0.82, 0.35)
	_entry = LineEdit.new()
	_entry.placeholder_text = "Type your reply here..."
	_entry.add_theme_font_size_override("font_size", 22)
	_entry.custom_minimum_size.y = 42
	column.add_child(_entry)
	_entry.text_submitted.connect(_on_submitted)
	_clock = _new_label(column, 18)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 18
	_bar.show_percentage = false
	column.add_child(_bar)
	_status = _new_label(column, 18)
	_panel.hide()


func _new_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _exit_tree() -> void:
	_end_music()
