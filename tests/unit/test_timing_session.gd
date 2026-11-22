extends GutTest
## Teste la séquence de timing avec une horloge simulée (fake_now_ms).

const R := TimingJudge.Result

var _session: TimingSession
var _results: Array = []
var _saved_difficulty: int
var _saved_latency: int


func before_each() -> void:
	_saved_difficulty = Settings.difficulty
	_saved_latency = Settings.latency_offset_ms
	Settings.difficulty = Settings.Difficulty.NORMAL  # perfect 60, good 130, parry 80, dodge 160
	Settings.latency_offset_ms = 0
	_results = []
	_session = TimingSession.new()
	add_child_autofree(_session)


func after_each() -> void:
	Settings.difficulty = _saved_difficulty
	Settings.latency_offset_ms = _saved_latency


func _start(mode: TimingSession.Mode, impacts: Array) -> void:
	var skill := SkillData.new()
	skill.impact_times = PackedFloat32Array(impacts)
	_session.start(mode, skill, null, func(_i: int, result: int) -> void: _results.append(result))


func _at(ms: float) -> void:
	_session.fake_now_ms = ms
	_session._process(0.0)


func test_early_good_press_is_shown_at_impact() -> void:
	_start(TimingSession.Mode.ATTACK, [0.5])
	_at(470)
	_session.press(&"confirm")
	_at(490)
	assert_eq(_results, [], "pas encore l'impact")
	_at(500)
	assert_eq(_results, [R.PERFECT])


func test_too_early_press_wastes_the_attempt() -> void:
	_start(TimingSession.Mode.ATTACK, [0.5])
	_at(300)
	_session.press(&"confirm")  # 200 ms trop tôt : raté
	_at(495)
	_session.press(&"confirm")  # parfait, mais l'essai est déjà utilisé
	_at(500)
	assert_eq(_results, [R.MISS])


func test_very_early_press_is_ignored() -> void:
	_start(TimingSession.Mode.ATTACK, [0.5])
	_at(50)
	_session.press(&"confirm")  # 450 ms avant : ignoré, pas pénalisé
	_at(480)
	_session.press(&"confirm")
	_at(500)
	assert_eq(_results, [R.PERFECT])


func test_no_press_misses_after_the_late_window() -> void:
	_start(TimingSession.Mode.ATTACK, [0.5])
	_at(550)
	assert_eq(_results, [], "on attend encore un appui en retard")
	_at(570)
	assert_eq(_results, [R.MISS])


func test_slightly_late_parry_resolves_immediately() -> void:
	_start(TimingSession.Mode.DEFENSE, [0.5])
	_at(520)
	_session.press(&"parry")
	assert_eq(_results, [R.PARRY])


func test_combo_hits_are_judged_one_by_one() -> void:
	_start(TimingSession.Mode.DEFENSE, [0.4, 0.8])
	_at(380)
	_session.press(&"dodge")
	_at(400)
	_at(780)
	_session.press(&"parry")
	_at(800)
	assert_eq(_results, [R.DODGE, R.PARRY])
