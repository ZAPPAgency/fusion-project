class_name BattleUnit
extends RefCounted
## État d'un combattant pendant un combat (PV, PA, stats). Aucun affichage ici.
## Ennemis : stats de leur fiche. Héros : stats de leur progression (niveau + équipement).

signal hp_changed(hp: int, max_hp: int)
signal ap_changed(ap: int)
signal died

const MAX_AP := 10
const START_AP := 2

var data: CombatantData
var hp: int
var ap: int
var max_hp: int
var attack: int
var defense: int
var speed: int
var level := 1
var skills: Array[SkillData] = []  ## Compétences utilisables (hors attaque de base)
var display_name: String  ## Nom traduit, avec une lettre si plusieurs ennemis identiques
var short_name: String  ## Initiale(s) affichée(s) dans la frise des tours

var is_enemy: bool:
	get:
		return data.is_enemy


func _init(combatant_data: CombatantData) -> void:
	data = combatant_data
	max_hp = data.max_hp
	attack = data.attack
	defense = data.defense
	speed = data.speed
	skills = data.skills.duplicate()
	hp = max_hp
	ap = START_AP
	display_name = tr(data.display_name)
	short_name = display_name.left(1)


## Héros : reprend les stats, les PV et les compétences de sa progression.
func apply_progress(progress: HeroProgress) -> void:
	level = progress.level
	max_hp = progress.max_hp()
	attack = progress.attack()
	defense = progress.defense()
	speed = progress.speed()
	skills = progress.skills()
	hp = progress.hp


## Distingue deux ennemis identiques : "Squelette A", "Squelette B".
func add_suffix(letter: String) -> void:
	display_name += " " + letter
	short_name += letter


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()


func heal(amount: int) -> void:
	if not is_alive():
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func can_pay(cost: int) -> bool:
	return ap >= cost


func spend_ap(cost: int) -> void:
	gain_ap(-cost)


func gain_ap(amount: int) -> void:
	ap = clampi(ap + amount, 0, MAX_AP)
	ap_changed.emit(ap)
