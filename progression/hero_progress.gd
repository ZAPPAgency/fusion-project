class_name HeroProgress
extends RefCounted
## Progression d'un héros pendant la partie : niveau, XP, PV actuels, stade d'évolution, cartes.
## Les stats finales = stats de base + croissance par niveau + bonus du stade + bonus des cartes.

const MAX_LEVEL := 10
## Niveau nécessaire pour chaque emplacement de carte : 2 au départ, puis aux niveaux 3, 6 et 9.
const SLOT_UNLOCK_LEVELS := [1, 1, 3, 6, 9]

var data: CombatantData
var level := 1
var xp := 0  ## XP accumulée dans le niveau actuel
var hp := 0
var stage := 0  ## Stade d'évolution (indice dans data.stages ; 0 = forme de départ)
## Carte équipée dans chaque emplacement (null = vide). Les cartes viennent de GameState.cards.
var slots: Array[CardInstance] = []


func _init(hero_data: CombatantData) -> void:
	data = hero_data
	slots.resize(SLOT_UNLOCK_LEVELS.size())
	hp = max_hp()


## XP nécessaire pour passer du niveau `from_level` au suivant.
static func xp_to_next(from_level: int) -> int:
	return 20 + 15 * from_level


# --- Stats ---------------------------------------------------------------------

func max_hp() -> int:
	return data.max_hp + _growth(data.hp_growth) + _stage_bonus("max_hp") + _card_bonus("max_hp")


func attack() -> int:
	return data.attack + _growth(data.attack_growth) + _stage_bonus("attack") + _card_bonus("attack")


func defense() -> int:
	return data.defense + _growth(data.defense_growth) + _stage_bonus("defense") + _card_bonus("defense")


func speed() -> int:
	return data.speed + _growth(data.speed_growth) + _stage_bonus("speed") + _card_bonus("speed")


func _growth(per_level: float) -> int:
	return floori(per_level * (level - 1))


func _stage_bonus(stat: String) -> int:
	var current := stage_data()
	return current.get(stat) if current else 0


func _card_bonus(stat: String) -> int:
	var total := 0
	for card in equipped_cards():
		total += card.stat(stat)
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


## Compétences connues au niveau actuel, plus celles des stades atteints et des cartes équipées.
func skills() -> Array[SkillData]:
	var known: Array[SkillData] = []
	for skill in data.skills:
		if skill.unlock_level <= level:
			known.append(skill)
	for i in range(1, stage + 1):
		if data.stages[i].skill:
			known.append(data.stages[i].skill)
	for card in equipped_cards():
		if card.data.skill and card.data.skill not in known:
			known.append(card.data.skill)
	return known


## Compétences apprises exactement au niveau `at_level`.
func skills_learned_at(at_level: int) -> Array[SkillData]:
	var learned: Array[SkillData] = []
	for skill in data.skills:
		if skill.unlock_level == at_level:
			learned.append(skill)
	return learned


# --- Évolution -----------------------------------------------------------------------

## Stade actuel (null si le héros n'a pas de stades).
func stage_data() -> HeroStage:
	return data.stages[stage] if stage < data.stages.size() else null


## Stade suivant (null si le héros est déjà au maximum).
func next_stage_data() -> HeroStage:
	return data.stages[stage + 1] if stage + 1 < data.stages.size() else null


## Nom du héros avec son titre, ex. « Aldric, Paladin de cendre ».
func full_title() -> String:
	var current := stage_data()
	if current == null or current.title == "":
		return tr(data.display_name)
	return "%s, %s" % [tr(data.display_name), tr(current.title)]


## Passe au stade suivant (sans vérifier les conditions : voir Forge.evolve_hero).
## Les PV actuels montent du gain de PV max.
func evolve() -> void:
	var old_max := max_hp()
	stage += 1
	hp += max_hp() - old_max


# --- Cartes ----------------------------------------------------------------------

## Nombre d'emplacements de cartes débloqués au niveau actuel.
func card_slots() -> int:
	return SLOT_UNLOCK_LEVELS.filter(func(unlock: int) -> bool: return unlock <= level).size()


func equipped_cards() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for card in slots:
		if card:
			cards.append(card)
	return cards


## Vrai si la carte peut aller dans cet emplacement : emplacement débloqué, carte permise
## pour ce héros, et pas déjà un autre exemplaire de la même carte sur lui.
func can_equip(slot: int, card: CardInstance) -> bool:
	if slot >= card_slots() or not card.data.can_be_used_by(data.id):
		return false
	for i in slots.size():
		if i != slot and slots[i] and slots[i].data.id == card.data.id:
			return false
	return true


## Met `card` dans l'emplacement (null = le vider). Renvoie la carte qui y était (ou null).
## Les PV actuels ne dépassent jamais le nouveau maximum.
func equip(slot: int, card: CardInstance) -> CardInstance:
	var previous := slots[slot]
	slots[slot] = card
	hp = mini(hp, max_hp())
	return previous


func slot_of(card: CardInstance) -> int:
	return slots.find(card)


## Somme d'un effet passif sur toutes les cartes équipées (voir CardData.Passive).
func passive(kind: CardData.Passive) -> float:
	var total := 0.0
	for card in equipped_cards():
		if card.data.passive == kind:
			total += card.data.passive_value
	return total


func timing_bonus_ms() -> float:
	var total := 0.0
	for card in equipped_cards():
		total += card.timing_bonus_ms()
	return total


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var slot_uids := []
	for card in slots:
		slot_uids.append(card.uid if card else -1)
	return {"level": level, "xp": xp, "hp": hp, "stage": stage, "slots": slot_uids}


## `cards_by_uid` : toutes les cartes du joueur (uid -> CardInstance), pour retrouver celles équipées.
func load_dict(saved: Dictionary, cards_by_uid := {}) -> void:
	level = int(saved.get("level", 1))
	xp = int(saved.get("xp", 0))
	stage = clampi(int(saved.get("stage", 0)), 0, maxi(data.stages.size() - 1, 0))
	if saved.has("slots"):  # les anciennes sauvegardes n'en ont pas : on garde les cartes actuelles
		slots.fill(null)
		var slot_uids: Array = saved.slots
		for i in mini(slot_uids.size(), slots.size()):
			slots[i] = cards_by_uid.get(int(slot_uids[i]))
	hp = clampi(int(saved.get("hp", max_hp())), 0, max_hp())
