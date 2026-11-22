class_name HeroProgress
extends RefCounted
## Progression d'un héros pendant la partie : niveau, XP, PV actuels, équipement.
## Les stats finales = stats de base + croissance par niveau + bonus d'équipement.

const MAX_LEVEL := 10

var data: CombatantData
var level := 1
var xp := 0  ## XP accumulée dans le niveau actuel
var hp := 0
var equipment := {}  # EquipmentData.Slot -> EquipmentData


func _init(hero_data: CombatantData) -> void:
	data = hero_data
	hp = max_hp()


## XP nécessaire pour passer du niveau `from_level` au suivant.
static func xp_to_next(from_level: int) -> int:
	return 20 + 15 * from_level


# --- Stats ---------------------------------------------------------------------

func max_hp() -> int:
	return data.max_hp + _growth(data.hp_growth) + _equipment_bonus("max_hp")


func attack() -> int:
	return data.attack + _growth(data.attack_growth) + _equipment_bonus("attack")


func defense() -> int:
	return data.defense + _growth(data.defense_growth) + _equipment_bonus("defense")


func speed() -> int:
	return data.speed + _growth(data.speed_growth) + _equipment_bonus("speed")


func _growth(per_level: float) -> int:
	return floori(per_level * (level - 1))


func _equipment_bonus(stat: String) -> int:
	var total := 0
	for item: EquipmentData in equipment.values():
		total += item.get(stat)
	return total


# --- Niveaux et compétences -----------------------------------------------------

## Ajoute de l'XP. Renvoie la liste des niveaux atteints (vide si aucun).
## Chaque niveau gagné augmente aussi les PV actuels du gain de PV max.
func add_xp(amount: int) -> Array[int]:
	var reached: Array[int] = []
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		var old_max := max_hp()
		level += 1
		hp += max_hp() - old_max
		reached.append(level)
	if level == MAX_LEVEL:
		xp = 0
	return reached


## Compétences connues au niveau actuel.
func skills() -> Array[SkillData]:
	var known: Array[SkillData] = []
	for skill in data.skills:
		if skill.unlock_level <= level:
			known.append(skill)
	return known


## Compétences apprises exactement au niveau `at_level`.
func skills_learned_at(at_level: int) -> Array[SkillData]:
	var learned: Array[SkillData] = []
	for skill in data.skills:
		if skill.unlock_level == at_level:
			learned.append(skill)
	return learned


# --- Équipement -------------------------------------------------------------------

## Équipe `item` (null = retirer). Renvoie l'objet qui était équipé (ou null).
## Les PV actuels ne dépassent jamais le nouveau maximum.
func equip(slot: EquipmentData.Slot, item: EquipmentData) -> EquipmentData:
	var previous: EquipmentData = equipment.get(slot)
	if item == null:
		equipment.erase(slot)
	else:
		equipment[slot] = item
	hp = mini(hp, max_hp())
	return previous


func equipped(slot: EquipmentData.Slot) -> EquipmentData:
	return equipment.get(slot)


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var equipped_ids := {}
	for slot in equipment:
		equipped_ids[str(slot)] = String(equipment[slot].id)
	return {"level": level, "xp": xp, "hp": hp, "equipment": equipped_ids}


func load_dict(saved: Dictionary) -> void:
	level = int(saved.get("level", 1))
	xp = int(saved.get("xp", 0))
	equipment.clear()
	var equipped_ids: Dictionary = saved.get("equipment", {})
	for slot in equipped_ids:
		equipment[int(slot)] = load("res://data/equipment/%s.tres" % equipped_ids[slot])
	hp = clampi(int(saved.get("hp", max_hp())), 0, max_hp())
