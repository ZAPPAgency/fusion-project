class_name TurnTimeline
extends RefCounted
## Frise des tours basée sur la vitesse.
## Chaque combattant a une « heure » de prochain tour. Après avoir joué, il avance
## de TURN_COST / vitesse : un combattant deux fois plus rapide joue deux fois plus souvent.
## En cas d'égalité, c'est l'ordre de la liste qui décide (héros d'abord).

const TURN_COST := 100.0

var _units: Array[BattleUnit] = []
var _next_time := {}  # BattleUnit -> heure du prochain tour


func _init(units: Array) -> void:
	for unit in units:
		_units.append(unit)
		_next_time[unit] = _turn_duration(unit)


## Renvoie le combattant qui joue maintenant et le replace plus loin dans la frise.
func next_unit() -> BattleUnit:
	var unit := _earliest(_next_time)
	_next_time[unit] += _turn_duration(unit)
	return unit


## Les `count` prochains tours, sans modifier la frise (pour l'affichage).
func preview(count: int) -> Array[BattleUnit]:
	var times := _next_time.duplicate()
	var result: Array[BattleUnit] = []
	for i in count:
		var unit := _earliest(times)
		if unit == null:
			break
		result.append(unit)
		times[unit] += _turn_duration(unit)
	return result


func _earliest(times: Dictionary) -> BattleUnit:
	var best: BattleUnit = null
	for unit in _units:
		if unit.is_alive() and (best == null or times[unit] < times[best]):
			best = unit
	return best


func _turn_duration(unit: BattleUnit) -> float:
	return TURN_COST / maxf(unit.speed, 1.0)
