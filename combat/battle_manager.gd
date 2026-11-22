extends Node2D
## Chef d'orchestre du combat : ordre des tours, choix des actions, résolution, fin du combat.
## Lancer le jeu avec `-- --autobattle` fait jouer les héros automatiquement (tests).

## Positions des pieds des combattants (héros à gauche, ennemis à droite).
const HERO_SLOTS := [Vector2(215, 212), Vector2(130, 236), Vector2(195, 272)]
const ENEMY_SLOTS := [Vector2(425, 212), Vector2(510, 236), Vector2(445, 272)]
const TIMELINE_PREVIEW := 7

## Intensité des effets d'impact (particules, tremblement, arrêt sur image) selon le résultat.
const IMPACT_STRENGTH := {
	TimingJudge.Result.PERFECT: 1.5,
	TimingJudge.Result.GOOD: 1.15,
	TimingJudge.Result.MISS: 0.8,
	TimingJudge.Result.HIT: 1.1,
}

## Bonus de dégâts selon la précision de l'appui en attaque.
const ATTACK_MULTIPLIERS := {
	TimingJudge.Result.PERFECT: 1.5,
	TimingJudge.Result.GOOD: 1.2,
	TimingJudge.Result.MISS: 1.0,
	TimingJudge.Result.HIT: 1.0,
}
## Valeurs de base ; les effets passifs des cartes s'y ajoutent (voir CardData.Passive).
const PARRY_AP_GAIN := 1  ## PA gagnés par parade réussie
const PERFECT_COMBO_AP_GAIN := 1  ## PA bonus si tous les coups d'une attaque sont parfaits
const COUNTER_MULTIPLIER := 1.5  ## Puissance de la contre-attaque (sur l'attaque de base)

const GOLD := Color(1.0, 0.85, 0.3)
const DODGE_BLUE := Color(0.55, 0.8, 1.0)

@onready var _units_root: Node2D = $Units
@onready var _hud: BattleHud = $Hud
@onready var _target_selector: TargetSelector = $TargetSelector
@onready var _timing: TimingSession = $TimingSession
@onready var _fx: BattleFx = $Fx
@onready var _camera: BattleCamera = $Camera

var _heroes: Array[BattleUnit] = []
var _enemies: Array[BattleUnit] = []
var _views := {}  # BattleUnit -> UnitView
var _timeline: TurnTimeline
var _rng := RandomNumberGenerator.new()
var _battle_over := false
## `--autobattle` : les héros jouent seuls et le jeu quitte à la fin (tests).
## `--autoplay` : démo complète, les héros jouent seuls et on retourne sur la carte.
var _autobattle := "--autobattle" in OS.get_cmdline_user_args() or "--autoplay" in OS.get_cmdline_user_args()
var _victory := false


func _ready() -> void:
	_spawn(GameState.party, HERO_SLOTS, _heroes)
	_spawn(GameState.next_encounter, ENEMY_SLOTS, _enemies)
	_timeline = TurnTimeline.new(_heroes + _enemies)
	_hud.setup(_heroes)
	_run_battle()


func _spawn(datas: Array[CombatantData], slots: Array, into: Array[BattleUnit]) -> void:
	var total_by_id := {}
	for data in datas:
		total_by_id[data.id] = total_by_id.get(data.id, 0) + 1
	var seen_by_id := {}

	for i in datas.size():
		var data := datas[i]
		var unit := BattleUnit.new(data)
		if not data.is_enemy:
			unit.apply_progress(GameState.progress_of(data))  # niveau, cartes, PV conservés
		if total_by_id[data.id] > 1:
			seen_by_id[data.id] = seen_by_id.get(data.id, 0) + 1
			unit.add_suffix(char(64 + seen_by_id[data.id]))  # 65 = "A"
		var view := UnitView.new()
		_units_root.add_child(view)
		view.setup(unit, slots[i])
		_views[unit] = view
		into.append(unit)


# --- Boucle principale -------------------------------------------------------

func _run_battle() -> void:
	await _wait(0.5)
	while true:
		var unit := _timeline.next_unit()
		_hud.show_timeline(unit, _timeline.preview(TIMELINE_PREVIEW))
		_hud.set_active(unit)
		await Tutorial.show_tip(&"battle")  # premier combat (frise affichée) : tours, PA, réglages
		if unit.is_enemy:
			await _enemy_turn(unit)
		else:
			await _hero_turn(unit)

		if _alive(_enemies).is_empty():
			_end_battle(true)
			return
		if _alive(_heroes).is_empty():
			_end_battle(false)
			return


func _hero_turn(hero: BattleUnit) -> void:
	# On boucle tant que le joueur annule le choix de cible.
	while true:
		var action: Dictionary = await _ask_action(hero)
		var targets: Array[BattleUnit] = await _ask_targets(hero, action)
		if not targets.is_empty():
			await _perform(hero, action, targets)
			return


func _enemy_turn(enemy: BattleUnit) -> void:
	await _wait(0.4)
	var action := {"kind": "skill", "skill": EnemyAI.choose_skill(enemy, _rng)}
	var targets: Array[BattleUnit] = await _ask_targets(enemy, action)
	await _perform(enemy, action, targets)


# --- Choix de l'action et des cibles -----------------------------------------

func _ask_action(hero: BattleUnit) -> Dictionary:
	if _autobattle:
		await _wait(0.3)
		for skill in hero.skills:
			if hero.can_pay(skill.ap_cost) and _rng.randf() < 0.5:
				return {"kind": "skill", "skill": skill}
		return {"kind": "skill", "skill": hero.data.basic_attack}
	_hud.action_menu.open(hero)
	return await _hud.action_menu.action_chosen


## Renvoie les cibles de l'action, ou une liste vide si le joueur a annulé.
func _ask_targets(user: BattleUnit, action: Dictionary) -> Array[BattleUnit]:
	var target_type := SkillData.Target.ONE_ALLY
	if action.kind == "skill":
		target_type = action.skill.target
	var foes := _alive(_heroes if user.is_enemy else _enemies)
	var allies := _alive(_enemies if user.is_enemy else _heroes)

	match target_type:
		SkillData.Target.ALL_FOES:
			return foes
		SkillData.Target.ALL_ALLIES:
			return allies
		SkillData.Target.SELF:
			return [user]
		SkillData.Target.ONE_FOE:
			return await _pick_one(user, foes)
		_:
			return await _pick_one(user, allies)


func _pick_one(user: BattleUnit, candidates: Array[BattleUnit]) -> Array[BattleUnit]:
	if user.is_enemy or _autobattle:
		return [EnemyAI.choose_target(candidates, _rng)]

	var views: Array[UnitView] = []
	for unit in candidates:
		views.append(_views[unit])
	_target_selector.choose(views)
	var target: BattleUnit = await _target_selector.finished
	if target == null:
		return []
	return [target]


# --- Résolution ---------------------------------------------------------------

func _perform(user: BattleUnit, action: Dictionary, targets: Array[BattleUnit]) -> void:
	if action.kind == "item":
		await _use_item(user, action.item, targets[0])
		return

	var skill: SkillData = action.skill
	if not user.is_enemy:
		user.spend_ap(skill.ap_cost)
	_hud.show_message(tr("MSG_USES").format({"user": user.display_name, "skill": tr(skill.display_name)}))

	# Les compétences (pas l'attaque de base) ont droit à un léger zoom de caméra.
	var is_special := skill != user.data.basic_attack
	if is_special:
		_camera.focus(_views[user].center())
	if skill.effect == SkillData.Effect.HEAL:
		await _views[user].play_cast(func() -> void: _apply_heal(user, skill, targets))
	else:
		await _perform_attack(user, skill, targets)
	if is_special:
		_camera.reset_focus()

	user.gain_ap(skill.ap_gain)
	_hud.show_message("")
	await _wait(0.2)


## Attaque avec QTE : le héros attaque (bonus de dégâts) ou se défend (parade / esquive).
func _perform_attack(user: BattleUnit, skill: SkillData, targets: Array[BattleUnit]) -> void:
	# Première attaque d'un héros / d'un ennemi : explication du timing avant le coup.
	await Tutorial.show_tip(&"defense" if user.is_enemy else &"attack")
	var view: UnitView = _views[user]
	var single_target := targets.size() == 1
	var runs_to_target := single_target and skill.melee
	if runs_to_target:
		await view.play_approach(_views[targets[0]])

	var mode := TimingSession.Mode.DEFENSE if user.is_enemy else TimingSession.Mode.ATTACK
	if user.is_enemy:
		_hud.show_hint(tr("HINT_DEFENSE").format({"parry": Controls.prompt("parry"), "dodge": Controls.prompt("dodge")}))
	else:
		_hud.show_hint(tr("HINT_ATTACK").format({"key": Controls.prompt("confirm")}))

	var on_hit := func(_index: int, result: int) -> void: _resolve_hit(user, skill, targets, result)
	var auto_rng: RandomNumberGenerator = _rng if _autobattle else null
	var on_release := func(_index: int) -> void:
		for target in targets:
			if target.is_alive():
				_fx.projectile(skill.projectile, view.weapon_position(), _views[target].center(), skill.projectile_travel)
	_timing.window_bonus_ms = _window_bonus(user, targets)
	var results: Array[int] = await _timing.run(mode, skill, view, on_hit, auto_rng, on_release)
	_hud.show_hint("")

	if runs_to_target:
		await view.play_return()
	if user.is_enemy:
		await _counter_if_all_parried(user, targets, results)
	elif results.all(func(result: int) -> bool: return result == TimingJudge.Result.PERFECT):
		var gain := PERFECT_COMBO_AP_GAIN + user.passive_ap(CardData.Passive.PERFECT_AP)
		user.gain_ap(gain)
		view.show_text("+%d %s" % [gain, tr("AP_SHORT")], GOLD)


## Aide au timing des cartes : celle de l'attaquant (héros), ou en défense
## la plus petite parmi les héros visés (un seul appui vaut pour tous).
func _window_bonus(user: BattleUnit, targets: Array[BattleUnit]) -> float:
	if not user.is_enemy:
		return user.timing_bonus_ms
	var bonus := INF
	for target in targets:
		bonus = minf(bonus, target.timing_bonus_ms)
	return 0.0 if bonus == INF else bonus


## Applique un coup d'une séquence à toutes les cibles encore en vie.
func _resolve_hit(user: BattleUnit, skill: SkillData, targets: Array[BattleUnit], result: int) -> void:
	for target in targets:
		if not target.is_alive():
			continue
		var target_view: UnitView = _views[target]
		match result:
			TimingJudge.Result.PARRY:
				target.gain_ap(PARRY_AP_GAIN + target.passive_ap(CardData.Passive.PARRY_AP))
				target_view.play_parry()
				target_view.show_text(tr("QTE_PARRY"), GOLD)
				_fx.parry(target_view.center(), _views[user].center())
				AudioManager.play_parry()
			TimingJudge.Result.DODGE:
				target_view.play_dodge()
				target_view.show_text(tr("QTE_DODGE"), DODGE_BLUE)
				AudioManager.play_dodge()
			_:
				_fx.impact(target_view.center(), skill.impact_fx, IMPACT_STRENGTH[result])
				if target.is_enemy == false:
					_fx.hero_hurt()
				# Les dégâts de la compétence sont répartis entre les coups du combo.
				var multiplier: float = ATTACK_MULTIPLIERS[result]
				if result == TimingJudge.Result.PERFECT:
					multiplier += user.passive(CardData.Passive.PERFECT_POWER)
				multiplier /= skill.impact_times.size()
				var amount := DamageCalculator.damage(user, target, skill, multiplier)
				target.take_damage(amount)
				target_view.show_hit(amount, FxLibrary.tint(skill.impact_fx))
				AudioManager.play_hit()
				if result == TimingJudge.Result.PERFECT:
					target_view.show_text(tr("QTE_PERFECT"), GOLD, 14)
					_fx.big_hit(target_view.center())
					AudioManager.play_perfect()
				elif result == TimingJudge.Result.GOOD:
					target_view.show_text(tr("QTE_GOOD"), Color.WHITE, 14)


## Si le héros a paré tous les coups, il riposte immédiatement.
func _counter_if_all_parried(enemy: BattleUnit, heroes: Array[BattleUnit], results: Array[int]) -> void:
	if results.is_empty() or not results.all(func(result: int) -> bool: return result == TimingJudge.Result.PARRY):
		return
	for hero in heroes:
		if not hero.is_alive() or not enemy.is_alive():
			continue
		var hero_view: UnitView = _views[hero]
		var enemy_view: UnitView = _views[enemy]
		hero_view.show_text(tr("QTE_COUNTER"), GOLD, 14)
		_camera.focus(enemy_view.center(), 1.18, 0.2)
		await hero_view.play_melee(enemy_view, func() -> void:
			var power := COUNTER_MULTIPLIER + hero.passive(CardData.Passive.COUNTER_POWER)
			var amount := DamageCalculator.damage(hero, enemy, hero.data.basic_attack, power)
			enemy.take_damage(amount)
			enemy_view.show_hit(amount)
			_fx.impact(enemy_view.center(), hero.data.basic_attack.impact_fx, 1.6)
			_fx.big_hit(enemy_view.center())
			AudioManager.play_hit()
		)
		_camera.reset_focus()


func _apply_heal(user: BattleUnit, skill: SkillData, targets: Array[BattleUnit]) -> void:
	for target in targets:
		var amount := DamageCalculator.heal(user, skill)
		target.heal(amount)
		_views[target].show_heal(amount)


func _use_item(user: BattleUnit, item: ItemData, target: BattleUnit) -> void:
	GameState.remove_item(item.id)
	_hud.show_message(tr("MSG_USES").format({"user": user.display_name, "skill": tr(item.display_name)}))
	var target_view: UnitView = _views[target]
	await _views[user].play_cast(func() -> void:
		if item.heal_amount > 0:
			target.heal(item.heal_amount)
			target_view.show_heal(item.heal_amount)
		if item.ap_amount > 0:
			FxLibrary.burst(_fx, target_view.center(), &"arcane")
			target.gain_ap(item.ap_amount)
			target_view.show_text("+%d %s" % [item.ap_amount, tr("AP_SHORT")], Color(0.5, 0.75, 1.0))
	)
	_hud.show_message("")
	await _wait(0.2)


# --- Fin du combat ------------------------------------------------------------

func _end_battle(victory: bool) -> void:
	_battle_over = true
	_victory = victory
	_hud.set_active(null)
	var from_map := GameState.battle_started_from_map()
	var lines: Array[String] = []
	if victory:
		var heroes_hp := {}
		for hero in _heroes:
			heroes_hp[hero.data.id] = hero.hp
		lines = GameState.win_battle(heroes_hp, GameState.next_encounter)
		AudioManager.play_perfect()
	lines.append("")
	lines.append(tr("BATTLE_CONTINUE") if from_map else tr("BATTLE_RESTART"))
	_hud.show_banner(tr("BATTLE_VICTORY") if victory else tr("BATTLE_DEFEAT"), "\n".join(lines))
	await _wait(0.6)
	await Tutorial.show_tip(&"victory" if victory else &"defeat")
	if _autobattle:
		await _wait(1.5)
		if from_map:
			_leave_battle()
		else:
			get_tree().quit()


func _leave_battle() -> void:
	if not GameState.battle_started_from_map():
		GameState.new_game()
		get_tree().reload_current_scene()
		return
	GameState.leave_battle(_victory)


func _unhandled_input(event: InputEvent) -> void:
	if _battle_over and event.is_action_pressed("ui_accept") and not SceneRouter.is_busy():
		_leave_battle()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Raccourcis provisoires, en attendant le menu d'options (étape 8).
		if event.physical_keycode == KEY_F1:
			Settings.cycle_difficulty()
			_hud.show_difficulty()
		elif event.physical_keycode == KEY_F2:
			SceneRouter.go_to("res://ui/calibration.tscn")


# --- Utilitaires --------------------------------------------------------------

func _alive(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in units:
		if unit.is_alive():
			result.append(unit)
	return result


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
