extends Control
## Calibration de la latence : le joueur appuie sur « confirm » à chaque flash + bip.
## On mesure le décalage médian entre ses appuis et les bips, puis on l'enregistre
## dans Settings.latency_offset_ms (utilisé par TimingJudge).

const BEAT_MS := 750.0
const FIRST_BEAT_MS := 1500.0
const PRESSES_NEEDED := 10

var _start_usec := 0
var _last_beat := -1
var _offsets: Array[float] = []
var _pulse: ColorRect
var _info: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("161a2b")
	background.size = Vector2(640, 360)
	add_child(background)

	_pulse = ColorRect.new()
	_pulse.color = Color(1.0, 0.85, 0.3)
	_pulse.size = Vector2(32, 32)
	_pulse.position = Vector2(304, 120)
	_pulse.modulate.a = 0.15
	add_child(_pulse)

	_info = Label.new()
	_info.size = Vector2(640, 120)
	_info.position = Vector2(0, 190)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 10)
	add_child(_info)

	_start_usec = Time.get_ticks_usec()
	_update_text()


func _process(_delta: float) -> void:
	var now := _now_ms() - FIRST_BEAT_MS
	if now < 0:
		return
	var beat := int(now / BEAT_MS)
	if beat != _last_beat:
		_last_beat = beat
		AudioManager.play_cue()
		_pulse.modulate.a = 1.0
		create_tween().tween_property(_pulse, "modulate:a", 0.15, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		GameState.new_game()
		SceneRouter.go_to("res://combat/battle_scene.tscn")
	elif event.is_action_pressed("confirm") and _offsets.size() < PRESSES_NEEDED:
		var now := _now_ms() - FIRST_BEAT_MS
		if now < -BEAT_MS / 2:
			return
		var nearest_beat := roundf(now / BEAT_MS) * BEAT_MS
		_offsets.append(now - nearest_beat)
		if _offsets.size() == PRESSES_NEEDED:
			Settings.latency_offset_ms = roundi(_median(_offsets))
			Settings.save_settings()
		_update_text()


func _update_text() -> void:
	var lines := [
		tr("CALIB_TITLE"),
		"",
		tr("CALIB_INSTRUCTIONS").format({"key": Controls.prompt("confirm")}),
		"%d / %d" % [_offsets.size(), PRESSES_NEEDED],
	]
	if _offsets.size() == PRESSES_NEEDED:
		lines.append("")
		lines.append(tr("CALIB_RESULT").format({"ms": Settings.latency_offset_ms}))
	lines.append("")
	lines.append(tr("CALIB_BACK").format({"key": Controls.prompt("cancel")}))
	_info.text = "\n".join(lines)


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _now_ms() -> float:
	return (Time.get_ticks_usec() - _start_usec) / 1000.0
