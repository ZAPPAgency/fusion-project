extends Node
## État de la partie en cours : équipe (niveaux, PV, cartes), or, objets, collection de cartes,
## carte actuelle, ennemis vaincus, coffres ouverts, combat en cours.

const PARTY_PATHS := [
	"res://data/characters/aldric.tres",
	"res://data/characters/ysolde.tres",
	"res://data/characters/fenn.tres",
]

const START_MAP := "res://world/maps/village.tscn"
const START_SPAWN := "start"
const START_GOLD := 30
## Carte de départ de chaque héros, déjà équipée.
const STARTER_CARDS := {&"aldric": &"seve_vitale", &"ysolde": &"croc_squelette", &"fenn": &"plume_vent"}

## Combat lancé directement depuis la scène de combat (tests, sans carte).
const TEST_ENCOUNTER_PATHS := [
	"res://data/enemies/squelette.tres",
	"res://data/enemies/gobelin_lancier.tres",
	"res://data/enemies/oeil_spectral.tres",
]

## Temps (s) pendant lequel les ennemis de la carte ignorent le joueur après un combat.
const ENCOUNTER_GRACE := 2.0

## Partie de test : rangs des exemplaires donnés pour chaque carte, matériaux, or.
const TEST_CARD_RANKS := [1, 1, 1, 3, 5]
const TEST_MATERIALS := 99
const TEST_GOLD := 99999
const TEST_SPAWN := "forge"

## Version du format de sauvegarde (2 = cartes à la place de l'équipement).
const SAVE_VERSION := 2

var party: Array[CombatantData] = []  ## Fiches de base des héros (dans l'ordre de l'équipe)
var heroes: Array[HeroProgress] = []  ## Progression de chaque héros (même ordre)
var leader_index := 0  ## Héros avec lequel on marche sur la carte
var gold := 0
var inventory := {}  # id d'objet consommable (StringName) -> quantité
var cards: Array[CardInstance] = []  ## Toutes les cartes du joueur, équipées ou non
var next_card_uid := 1
var materials := {}  # id de matériau (StringName) -> quantité
var test_mode := false  ## Partie de test : tout débloqué, sauvegarde à part

# --- Exploration ---
var current_map := ""
var spawn_name := START_SPAWN  ## Point d'arrivée sur la prochaine carte chargée
var player_position = null  ## Position à restaurer (retour de combat, chargement) ; null = spawn_name
var defeated_encounters := {}  # id -> true
var opened_chests := {}  # id -> true
var grace_until_ms := 0
var autoplay_step := 0  ## Démo `--autoplay` : nombre de points de passage déjà atteints

# --- Combat ---
var next_encounter: Array[CombatantData] = []
var _battle_encounter_id := ""
var _battle_from_map := false


func _ready() -> void:
	new_game()


func new_game() -> void:
	party.clear()
	heroes.clear()
	for path in PARTY_PATHS:
		var data: CombatantData = load(path)
		party.append(data)
		heroes.append(HeroProgress.new(data))
	gold = START_GOLD
	leader_index = 0
	inventory = {&"potion": 3, &"ether": 1}
	cards.clear()
	next_card_uid = 1
	materials = {}
	test_mode = false
	for progress in heroes:
		progress.equip(0, add_card(STARTER_CARDS[progress.data.id]))
	heal_party()  # les PV max comptent maintenant les cartes de départ
	current_map = START_MAP
	spawn_name = START_SPAWN
	autoplay_step = 0
	player_position = null
	defeated_encounters.clear()
	opened_chests.clear()
	next_encounter.clear()
	for path in _encounter_paths():
		next_encounter.append(load(path))
	_battle_from_map = false


## Partie de test (écran titre) : toutes les cartes en plusieurs exemplaires et rangs,
## beaucoup de matériaux et d'or, héros au niveau maximum, départ à côté de la forge.
## Elle est sauvegardée à part (voir SaveSystem) : la vraie partie n'est pas touchée.
func new_test_game() -> void:
	new_game()
	test_mode = true
	gold = TEST_GOLD
	inventory = {&"potion": 20, &"grande_potion": 10, &"ether": 10}
	for card_id in all_card_ids():
		for rank in TEST_CARD_RANKS:
			add_card(card_id, rank)
	for file in ResourceLoader.list_directory("res://data/materials"):
		add_material(StringName(file.get_basename()), TEST_MATERIALS)
	for progress in heroes:
		progress.add_xp(100000)
	heal_party()
	spawn_name = TEST_SPAWN


## Identifiants de toutes les cartes du jeu (fichiers de data/cards).
func all_card_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for file in ResourceLoader.list_directory("res://data/cards"):
		ids.append(StringName(file.get_basename()))
	return ids


func progress_of(hero: CombatantData) -> HeroProgress:
	for progress in heroes:
		if progress.data.id == hero.id:
			return progress
	return null


## Héros affiché sur la carte.
func leader() -> HeroProgress:
	return heroes[leader_index]


## Le héros suivant prend la tête (touche R / bouton Y sur la carte).
func cycle_leader() -> void:
	leader_index = (leader_index + 1) % heroes.size()


func heal_party() -> void:
	for progress in heroes:
		progress.hp = progress.max_hp()


# --- Exploration ---

func arrive_at(map_path: String, spawn: String) -> void:
	if OS.is_debug_build() and "--autoplay" in OS.get_cmdline_user_args():
		print("[démo] carte : ", map_path.get_file(), " (", spawn, ")")
	current_map = map_path
	spawn_name = spawn
	player_position = null
	autoplay_step = 0


func encounters_paused() -> bool:
	return Time.get_ticks_msec() < grace_until_ms


## Un ennemi de la carte touche le joueur : on mémorise tout, puis on part au combat.
func start_battle(enemies: Array[CombatantData], encounter_id: String, from_position: Vector2) -> void:
	if OS.is_debug_build() and "--autoplay" in OS.get_cmdline_user_args():
		print("[démo] combat : ", encounter_id)
	next_encounter = enemies.duplicate()
	_battle_encounter_id = encounter_id
	_battle_from_map = true
	player_position = from_position
	SceneRouter.transition_to("res://combat/battle_scene.tscn", true)


func battle_started_from_map() -> bool:
	return _battle_from_map


## Victoire : PV gardés (les K.O. se relèvent avec 1 PV), XP et or pour toute l'équipe.
## Renvoie les lignes du bilan à afficher (gains, niveaux, nouvelles compétences).
func win_battle(heroes_hp: Dictionary, enemies: Array[CombatantData]) -> Array[String]:
	for progress in heroes:
		progress.hp = maxi(heroes_hp.get(progress.data.id, progress.hp), 1)
	var xp := 0
	var gold_won := 0
	for enemy in enemies:
		xp += enemy.xp_reward
		gold_won += enemy.gold_reward
	gold += gold_won
	defeated_encounters[_battle_encounter_id] = true

	var report: Array[String] = [tr("REWARD_LINE").format({"xp": xp, "gold": gold_won})]
	for progress in heroes:
		for new_level in progress.add_xp(xp):
			report.append(tr("REWARD_LEVEL_UP").format({"hero": tr(progress.data.display_name), "level": new_level}))
			for skill in progress.skills_learned_at(new_level):
				report.append(tr("REWARD_NEW_SKILL").format({"hero": tr(progress.data.display_name), "skill": tr(skill.display_name)}))
	return report


## Retour sur la carte après le combat. Défaite : l'équipe est soignée et repart
## du point d'arrivée de la carte (l'ennemi reste là).
func leave_battle(victory: bool) -> void:
	if OS.is_debug_build() and "--autoplay" in OS.get_cmdline_user_args():
		print("[démo] fin du combat ", _battle_encounter_id, " : ", "victoire" if victory else "défaite")
	if not victory:
		heal_party()
		player_position = null
	_battle_from_map = false
	grace_until_ms = Time.get_ticks_msec() + int(ENCOUNTER_GRACE * 1000.0)
	SceneRouter.transition_to(current_map)


# --- Objets ---

func item_data(item_id: StringName) -> ItemData:
	return load("res://data/items/%s.tres" % item_id)


## Objet consommable, carte ou matériau, selon l'identifiant.
func loot_data(loot_id: StringName) -> Resource:
	if ResourceLoader.exists("res://data/cards/%s.tres" % loot_id):
		return card_data(loot_id)
	if ResourceLoader.exists("res://data/materials/%s.tres" % loot_id):
		return material_data(loot_id)
	return item_data(loot_id)


func has_items() -> bool:
	for item_id in inventory:
		if inventory[item_id] > 0:
			return true
	return false


## Ajoute un objet, une carte ou un matériau (coffres, achats).
func add_loot(loot_id: StringName, amount := 1) -> void:
	var loot := loot_data(loot_id)
	if loot is CardData:
		for i in amount:
			add_card(loot_id)
	elif loot is MaterialData:
		add_material(loot_id, amount)
	else:
		add_item(loot_id, amount)


func add_item(item_id: StringName, amount := 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + amount


func remove_item(item_id: StringName) -> void:
	inventory[item_id] = maxi(inventory.get(item_id, 0) - 1, 0)


## Achat chez la marchande. Renvoie false si l'or manque.
func buy(loot_id: StringName) -> bool:
	var price: int = loot_data(loot_id).price
	if gold < price:
		return false
	gold -= price
	add_loot(loot_id)
	return true


# --- Matériaux ---

func material_data(material_id: StringName) -> MaterialData:
	return load("res://data/materials/%s.tres" % material_id)


func add_material(material_id: StringName, amount := 1) -> void:
	materials[material_id] = materials.get(material_id, 0) + amount


func material_count(material_id: StringName) -> int:
	return materials.get(material_id, 0)


# --- Cartes ---

func card_data(card_id: StringName) -> CardData:
	return load("res://data/cards/%s.tres" % card_id)


## Ajoute un nouvel exemplaire de carte à la collection et le renvoie.
func add_card(card_id: StringName, rank := 1) -> CardInstance:
	var card := CardInstance.new(card_data(card_id), next_card_uid, rank)
	next_card_uid += 1
	cards.append(card)
	return card


## Retire une carte de la collection (fusion, amélioration) ; elle est d'abord déséquipée.
func remove_card(card: CardInstance) -> void:
	var holder := owner_of(card)
	if holder:
		holder.equip(holder.slot_of(card), null)
	cards.erase(card)


## Héros qui porte cette carte (null = carte libre).
func owner_of(card: CardInstance) -> HeroProgress:
	for progress in heroes:
		if progress.slot_of(card) != -1:
			return progress
	return null


## Équipe une carte sur un héros (null = vider l'emplacement). Si la carte était portée
## ailleurs (autre héros ou autre emplacement), elle y est retirée d'abord.
func equip_card(progress: HeroProgress, slot: int, card: CardInstance) -> void:
	if card:
		var holder := owner_of(card)
		if holder:
			holder.equip(holder.slot_of(card), null)
	progress.equip(slot, card)


# --- Sauvegarde ---

func to_dict() -> Dictionary:
	var heroes_saved := {}
	for progress in heroes:
		heroes_saved[String(progress.data.id)] = progress.to_dict()
	return {
		"version": SAVE_VERSION,
		"test_mode": test_mode,
		"leader": leader_index,
		"heroes": heroes_saved,
		"gold": gold,
		"inventory": _string_keys(inventory),
		"cards": cards.map(func(card: CardInstance) -> Dictionary: return card.to_dict()),
		"next_card_uid": next_card_uid,
		"materials": _string_keys(materials),
		"map": current_map,
		"position": [player_position.x, player_position.y] if player_position != null else null,
		"defeated": defeated_encounters.keys(),
		"chests": opened_chests.keys(),
	}


func load_dict(saved: Dictionary) -> void:
	new_game()
	var cards_by_uid := {}
	if saved.has("cards"):
		cards.clear()
		for card_saved: Dictionary in saved.cards:
			var card := CardInstance.from_dict(card_saved)
			cards.append(card)
			cards_by_uid[card.uid] = card
		next_card_uid = int(saved.get("next_card_uid", cards.size() + 1))
	var heroes_saved: Dictionary = saved.get("heroes", {})
	for progress in heroes:
		if heroes_saved.has(String(progress.data.id)):
			progress.load_dict(heroes_saved[String(progress.data.id)], cards_by_uid)
	if not saved.has("cards"):
		_convert_old_equipment(saved)
	gold = int(saved.get("gold", START_GOLD))
	inventory = _name_keys(saved.get("inventory", {}))
	materials = _name_keys(saved.get("materials", {}))
	test_mode = saved.get("test_mode", false)
	leader_index = clampi(int(saved.get("leader", 0)), 0, heroes.size() - 1)
	current_map = saved.get("map", START_MAP)
	var position = saved.get("position")
	player_position = Vector2(position[0], position[1]) if position != null else null
	for id in saved.get("defeated", []):
		defeated_encounters[id] = true
	for id in saved.get("chests", []):
		opened_chests[id] = true


## Sauvegarde d'avant les cartes (version 1) : chaque équipement devient la carte
## du même nom ; ceux qui étaient portés sont équipés sur le même héros.
func _convert_old_equipment(saved: Dictionary) -> void:
	var bag: Dictionary = saved.get("equipment_bag", {})
	for equipment_id in bag:
		add_loot(StringName(equipment_id), int(bag[equipment_id]))
	var heroes_saved: Dictionary = saved.get("heroes", {})
	for progress in heroes:
		var worn: Dictionary = heroes_saved.get(String(progress.data.id), {}).get("equipment", {})
		for equipment_id in worn.values():
			var card := add_card(StringName(equipment_id))
			for slot in progress.card_slots():
				if progress.slots[slot] == null and progress.can_equip(slot, card):
					progress.equip(slot, card)
					break


func _string_keys(counts: Dictionary) -> Dictionary:
	var result := {}
	for key in counts:
		result[String(key)] = counts[key]
	return result


func _name_keys(counts: Dictionary) -> Dictionary:
	var result := {}
	for key in counts:
		result[StringName(key)] = int(counts[key])
	return result


## Pour tester un combat précis : lancer la scène de combat avec `-- --encounter=gardien_cloche,squelette`.
func _encounter_paths() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--encounter="):
			return Array(arg.trim_prefix("--encounter=").split(",")).map(
				func(enemy_id: String) -> String: return "res://data/enemies/%s.tres" % enemy_id)
	return TEST_ENCOUNTER_PATHS
