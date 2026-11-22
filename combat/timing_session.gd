class_name TimingSession
extends Node
## Joue une séquence de coups en temps réel et juge les appuis du joueur.
## - Mode ATTACK : appuyer sur « confirm » au moment de chaque impact pour un bonus de dégâts.
## - Mode DEFENSE : « parry » ou « dodge » au moment de chaque impact ennemi.
## Un seul essai par coup : appuyer trop tôt grille l'essai (impossible de marteler la touche).
## L'animation (recul puis élan) est calculée à partir de la même horloge que le jugement,
## pour que ce qu'on voit corresponde exactement au timing attendu. Cette horloge est le temps
## du jeu (somme des delta) : elle suit les ralentis et arrêts sur image (hit-stop).

signal _finished

enum Mode { ATTACK, DEFENSE }

const NO_RESULT := -1
const IGNORE_BEFORE_MS := 400.0  ## Appui plus de 400 ms avant l'impact : ignoré, pas pénalisé
const LUNGE_MS := 70.0  ## Durée de l'élan final vers l'impact
const WINDUP_DISTANCE := 10.0  ## Recul en pixels pendant la préparation du coup
const LUNGE_DISTANCE := 6.0  ## Avancée en pixels au moment de l'impact
const RECOVER_MS := 300.0  ## Retour au repos après le dernier coup

## Pour les tests : si >= 0, remplace l'horloge réelle.
var fake_now_ms := -1.0
## Élargit les fenêtres de timing de la prochaine séquence (cartes du héros concerné).
var window_bonus_ms := 0.0

var _mode := Mode.ATTACK
var _judge: TimingJudge
var _view: UnitView
var _on_hit: Callable
var _impacts_ms: Array[float] = []
var _results: Array[int] = []
var _early_results: Array[int] = []  # résultat d'un bon appui fait juste avant l'impact
var _attempt_used: Array[bool] = []
var _cue_shown: Array[bool] = []
var _auto_presses: Array[Dictionary] = []  # appuis simulés (mode --autobattle)
var _animations: Array[StringName] = []  # animation de chaque coup (vide = pas de sprite)
var _animation_starts_ms: Array[float] = []
var _next_animation := 0
var _on_release: Callable
var _releases_ms: Array[float] = []
var _next_release := 0
var _current := 0  # premier coup pas encore résolu
var _elapsed_ms := 0.0
var _running := false


func _ready() -> void:
	set_process(false)


## Joue les coups de `skill` et renvoie le résultat de chaque coup (TimingJudge.Result).
## `on_hit(index, result)` est appelé au moment où chaque coup est résolu.
## `auto_rng` (facultatif) simule les appuis du joueur.
## `on_release(index)` (facultatif) est appelé quand un projectile doit partir.
func run(mode: Mode, skill: SkillData, view: UnitView, on_hit: Callable,
		auto_rng: RandomNumberGenerator = null, on_release := Callable()) -> Array[int]:
	start(mode, skill, view, on_hit, auto_rng, on_release)
	await _finished
	return _results


func start(mode: Mode, skill: SkillData, view: UnitView, on_hit: Callable,
		auto_rng: RandomNumberGenerator = null, on_release := Callable()) -> void:
	_mode = mode
	_view = view
	_on_hit = on_hit
	_on_release = on_release
	_judge = TimingJudge.new(TimingJudge.widened(Settings.current_windows(), window_bonus_ms), Settings.latency_offset_ms)
	_impacts_ms.clear()
	_results.clear()
	_early_results.clear()
	_attempt_used.clear()
	_cue_shown.clear()
	_auto_presses.clear()
	_animations.clear()
	_animation_starts_ms.clear()
	_releases_ms.clear()
	# Avec un projectile, l'image d'impact de l'animation = le tir ; le coup touche après le vol.
	var travel_ms := skill.projectile_travel * 1000.0 if skill.projectile else 0.0

	# Chaque animation démarre en avance pour que son image d'impact tombe sur l'instant d'impact.
	# Si une animation est plus longue que le délai prévu, toute la séquence est décalée.
	var leads: Array[float] = []
	var delay_ms := 0.0
	for index in skill.impact_times.size():
		var anim := view.attack_anim(skill.hit_animation(index)) if view else &""
		var lead := (view.impact_lead_ms(anim) if view else 0.0) + travel_ms
		_animations.append(anim)
		leads.append(lead)
		delay_ms = maxf(delay_ms, lead - roundf(skill.impact_times[index] * 1000.0))

	for index in range(1, skill.impact_times.size()):
		var previous_impact := skill.impact_times[index - 1] * 1000.0 - travel_ms  # tir précédent
		if leads[index] > 0.0 and skill.impact_times[index] * 1000.0 - leads[index] < previous_impact:
			push_warning("%s : le coup %d démarre avant l'impact du coup %d, espace les impact_times." % [skill.id, index + 1, index])

	for index in skill.impact_times.size():
		# Arrondi : 0.4 en float32 ne vaut pas 400 ms pile.
		var impact_ms := roundf(skill.impact_times[index] * 1000.0) + delay_ms
		_impacts_ms.append(impact_ms)
		_animation_starts_ms.append(impact_ms - leads[index])
		if travel_ms > 0.0:
			_releases_ms.append(impact_ms - travel_ms)
		_results.append(NO_RESULT)
		_early_results.append(NO_RESULT)
		_attempt_used.append(false)
		_cue_shown.append(false)
		if auto_rng:
			_auto_presses.append({"time": impact_ms + auto_rng.randf_range(-150.0, 60.0), "action": _random_action(auto_rng)})
	_current = 0
	_next_animation = 0
	_next_release = 0
	_elapsed_ms = 0.0
	_running = true
	set_process(true)


## Appui du joueur (appelé par _input, ou directement par les tests).
func press(action: StringName) -> void:
	if not _running or _current >= _impacts_ms.size():
		return
	var index := _current
	if _attempt_used[index]:
		return
	var now := _now_ms()
	var offset := now - _impacts_ms[index]
	if offset < -IGNORE_BEFORE_MS:
		return
	_attempt_used[index] = true

	var result := _judge_press(action, offset)
	if not TimingJudge.is_success(result):
		return  # essai grillé : le coup sera compté raté au moment de l'impact
	if offset < 0:
		_early_results[index] = result  # affiché pile au moment de l'impact
	else:
		_resolve(index, result)


## _input (et pas _unhandled_input) : un clic de souris compte même s'il tombe
## sur un panneau de l'interface.
func _input(event: InputEvent) -> void:
	if not _running:
		return
	var action := &""
	if _mode == Mode.ATTACK and event.is_action_pressed("confirm"):
		action = &"confirm"
	elif _mode == Mode.DEFENSE and event.is_action_pressed("parry"):
		action = &"parry"
	elif _mode == Mode.DEFENSE and event.is_action_pressed("dodge"):
		action = &"dodge"
	else:
		return
	get_viewport().set_input_as_handled()
	press(action)


func _process(delta: float) -> void:
	_elapsed_ms += delta * 1000.0
	var now := _now_ms()
	_play_auto_presses(now)
	_start_animations(now)
	_release_projectiles(now)
	_show_cues(now)
	if _view:
		_view.set_strike_pose(_pose_offset(now))
	_resolve_due_hits(now)

	if _current >= _impacts_ms.size() and now >= _impacts_ms.back() + RECOVER_MS:
		_running = false
		set_process(false)
		if _view:
			_view.set_strike_pose(0.0)
		_finished.emit()


func _resolve_due_hits(now: float) -> void:
	while _current < _impacts_ms.size() and now >= _impacts_ms[_current]:
		var index := _current
		if _early_results[index] != NO_RESULT:
			_resolve(index, _early_results[index])
		elif _attempt_used[index] or now >= _impacts_ms[index] + _judge.late_limit_ms(_mode == Mode.ATTACK):
			_resolve(index, _failure())
		else:
			return  # on laisse encore une chance à un appui légèrement en retard


func _resolve(index: int, result: int) -> void:
	_results[index] = result
	_current = index + 1
	_on_hit.call(index, result)


func _start_animations(now: float) -> void:
	while _next_animation < _animations.size() and now >= _animation_starts_ms[_next_animation]:
		if _view and _animations[_next_animation] != &"":
			_view.play_anim(_animations[_next_animation])
		_next_animation += 1


func _release_projectiles(now: float) -> void:
	while _next_release < _releases_ms.size() and now >= _releases_ms[_next_release]:
		if _on_release.is_valid():
			_on_release.call(_next_release)
		_next_release += 1


func _show_cues(now: float) -> void:
	for index in _impacts_ms.size():
		if not _cue_shown[index] and now >= _impacts_ms[index] - Settings.cue_lead_ms():
			_cue_shown[index] = true
			if _view:
				_view.show_cue(Settings.cue_size())
				AudioManager.play_cue()


## Décalage horizontal du corps : recul pendant la préparation, puis élan au moment de l'impact.
func _pose_offset(now: float) -> float:
	var previous := 0.0
	var start_offset := 0.0
	for impact in _impacts_ms:
		if now <= impact:
			var lunge_start := impact - LUNGE_MS
			if now < lunge_start:
				var progress := clampf((now - previous) / maxf(lunge_start - previous, 1.0), 0.0, 1.0)
				return lerpf(start_offset, -WINDUP_DISTANCE, smoothstep(0.0, 1.0, progress))
			return lerpf(-WINDUP_DISTANCE, LUNGE_DISTANCE, (now - lunge_start) / LUNGE_MS)
		previous = impact
		start_offset = LUNGE_DISTANCE
	var recover := clampf((now - previous) / RECOVER_MS, 0.0, 1.0)
	return lerpf(LUNGE_DISTANCE, 0.0, recover)


func _play_auto_presses(now: float) -> void:
	while not _auto_presses.is_empty() and now >= _auto_presses[0].time:
		press(_auto_presses.pop_front().action)


func _judge_press(action: StringName, offset: float) -> int:
	if _mode == Mode.ATTACK:
		return _judge.judge_attack(offset)
	return _judge.judge_defense(action, offset)


func _failure() -> int:
	return TimingJudge.Result.MISS if _mode == Mode.ATTACK else TimingJudge.Result.HIT


func _random_action(rng: RandomNumberGenerator) -> StringName:
	if _mode == Mode.ATTACK:
		return &"confirm"
	return &"parry" if rng.randf() < 0.5 else &"dodge"


func _now_ms() -> float:
	if fake_now_ms >= 0.0:
		return fake_now_ms
	return _elapsed_ms
