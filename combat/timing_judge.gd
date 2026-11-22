class_name TimingJudge
extends RefCounted
## Juge un appui par rapport à l'instant d'impact d'un coup.
## Avant l'impact, la fenêtre a sa largeur complète. Après l'impact, elle est réduite
## (LATE_RATIO) pour que le résultat s'affiche presque au moment du coup.

enum Result { PERFECT, GOOD, MISS, PARRY, DODGE, HIT }

const LATE_RATIO := 0.5

var _windows: Dictionary
var _latency_ms: float


## `windows` : voir Settings.TIMING_WINDOWS. `latency_ms` : calibration du joueur.
func _init(windows: Dictionary, latency_ms := 0.0) -> void:
	_windows = windows
	_latency_ms = latency_ms


## `offset_ms` = instant de l'appui − instant de l'impact (négatif = en avance).
func judge_attack(offset_ms: float) -> Result:
	var distance := _distance(offset_ms)
	if distance <= _windows.perfect:
		return Result.PERFECT
	if distance <= _windows.good:
		return Result.GOOD
	return Result.MISS


## `action` : &"parry" (fenêtre serrée) ou &"dodge" (fenêtre large).
func judge_defense(action: StringName, offset_ms: float) -> Result:
	var distance := _distance(offset_ms)
	if action == &"parry":
		return Result.PARRY if distance <= _windows.parry else Result.HIT
	return Result.DODGE if distance <= _windows.dodge else Result.HIT


## Temps maximum à attendre après l'impact avant de déclarer le coup raté.
func late_limit_ms(is_attack: bool) -> float:
	var widest: float = _windows.good if is_attack else maxf(_windows.parry, _windows.dodge)
	return maxf(widest * LATE_RATIO + _latency_ms, 0.0)


static func is_success(result: Result) -> bool:
	return result in [Result.PERFECT, Result.GOOD, Result.PARRY, Result.DODGE]


## Distance à l'impact, en « ms d'avance équivalentes » (le retard compte double).
func _distance(offset_ms: float) -> float:
	var corrected := offset_ms - _latency_ms
	if corrected < 0:
		return -corrected
	return corrected / LATE_RATIO
