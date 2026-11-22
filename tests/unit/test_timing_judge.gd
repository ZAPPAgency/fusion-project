extends GutTest

const R := TimingJudge.Result
const WINDOWS := {"perfect": 60, "good": 130, "parry": 80, "dodge": 160}


func test_attack_grades_by_distance_before_impact() -> void:
	var judge := TimingJudge.new(WINDOWS)
	assert_eq(judge.judge_attack(-50), R.PERFECT)
	assert_eq(judge.judge_attack(-100), R.GOOD)
	assert_eq(judge.judge_attack(-200), R.MISS)


func test_late_presses_get_half_the_window() -> void:
	var judge := TimingJudge.new(WINDOWS)
	assert_eq(judge.judge_attack(25), R.PERFECT)  # 25 ms en retard = 50 ms équivalents
	assert_eq(judge.judge_attack(40), R.GOOD)  # 80 équivalents
	assert_eq(judge.judge_attack(70), R.MISS)  # 140 équivalents


func test_parry_is_tighter_than_dodge() -> void:
	var judge := TimingJudge.new(WINDOWS)
	assert_eq(judge.judge_defense(&"parry", -70), R.PARRY)
	assert_eq(judge.judge_defense(&"parry", -120), R.HIT)
	assert_eq(judge.judge_defense(&"dodge", -120), R.DODGE)
	assert_eq(judge.judge_defense(&"dodge", -200), R.HIT)


func test_latency_offset_shifts_the_window() -> void:
	var judge := TimingJudge.new(WINDOWS, 50.0)  # le joueur appuie 50 ms en retard
	assert_eq(judge.judge_attack(50), R.PERFECT)
	assert_eq(judge.judge_attack(-60), R.GOOD)


func test_late_limit_uses_widest_window() -> void:
	var judge := TimingJudge.new(WINDOWS)
	assert_eq(judge.late_limit_ms(true), 65.0)
	assert_eq(judge.late_limit_ms(false), 80.0)


func test_success_results() -> void:
	assert_true(TimingJudge.is_success(R.PERFECT))
	assert_true(TimingJudge.is_success(R.DODGE))
	assert_false(TimingJudge.is_success(R.MISS))
	assert_false(TimingJudge.is_success(R.HIT))


func test_widened_windows_add_the_bonus_everywhere() -> void:
	var windows := TimingJudge.widened({"perfect": 60, "good": 130, "parry": 80, "dodge": 160}, 15.0)
	assert_eq(windows.perfect, 75.0)
	assert_eq(windows.dodge, 175.0)
