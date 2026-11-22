extends Node
## État de la partie en cours : équipe (niveaux, PV, équipement), or, objets,
## carte actuelle, ennemis vaincus, coffres ouverts, combat en cours.

const PARTY_PATHS := [
	"res://data/characters/aldric.tres",
	"res://data/characters/ysolde.tres",
	"res://data/characters/fenn.tres",
]

const START_MAP := "res://world/maps/village.tscn"
const START_SPAWN := "start"
const START_GOLD := 30

## Combat lancé directement depuis la scène de combat (tests, sans carte).
const TEST_ENCOUNTER_PATHS := [
	"res://data/enemies/squelette.tres",
	"res://data/enemies/gobelin_lancier.tres",
	"res://data/enemies/oeil_spectral.tres",
]

## Temps (s) pendant lequel les ennemis de la carte ignorent le joueur après un combat.
const ENCOUNTER_GRACE := 2.0

var party: Array[CombatantData] = []  ## Fiches de base des héros (dans l'ordre de l'équipe)
var heroes: Array[HeroProgress] = []  ## Progression de chaque héros (même ordre)
var gold := 0
var inventory := {}  # id d'objet consommable (StringName) -> quantité
var equipment_bag := {}  # id d'équipement non porté (StringName) -> quantité

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
	inventory = {&"potion": 3, &"ether": 1}
	equipment_bag = {}
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


func progress_of(hero: CombatantData) -> HeroProgress:
	for progress in heroes:
		if progress.data.id == hero.id:
			return progress
	return null


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


# --- Objets et équipement ---

func item_data(item_id: StringName) -> ItemData:
	return load("res://data/items/%s.tres" % item_id)


func equipment_data(equipment_id: StringName) -> EquipmentData:
	return load("res://data/equipment/%s.tres" % equipment_id)


## Objet consommable ou équipement, selon l'identifiant.
func loot_data(loot_id: StringName) -> Resource:
	if ResourceLoader.exists("res://data/equipment/%s.tres" % loot_id):
		return equipment_data(loot_id)
	return item_data(loot_id)


func has_items() -> bool:
	for item_id in inventory:
		if inventory[item_id] > 0:
			return true
	return false


## Ajoute un objet ou un équipement (coffres, achats).
func add_loot(loot_id: StringName, amount := 1) -> void:
	if loot_data(loot_id) is EquipmentData:
		equipment_bag[loot_id] = equipment_bag.get(loot_id, 0) + amount
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


## Équipe un objet du sac sur un héros ; l'ancien retourne dans le sac. `item` null = retirer.
func equip(progress: HeroProgress, slot: EquipmentData.Slot, item: EquipmentData) -> void:
	if item:
		equipment_bag[item.id] = equipment_bag.get(item.id, 0) - 1
		if equipment_bag[item.id] <= 0:
			equipment_bag.erase(item.id)
	var previous := progress.equip(slot, item)
	if previous:
		equipment_bag[previous.id] = equipment_bag.get(previous.id, 0) + 1


# --- Sauvegarde ---

func to_dict() -> Dictionary:
	var heroes_saved := {}
	for progress in heroes:
		heroes_saved[String(progress.data.id)] = progress.to_dict()
	return {
		"heroes": heroes_saved,
		"gold": gold,
		"inventory": _string_keys(inventory),
		"equipment_bag": _string_keys(equipment_bag),
		"map": current_map,
		"position": [player_position.x, player_position.y] if player_position != null else null,
		"defeated": defeated_encounters.keys(),
		"chests": opened_chests.keys(),
	}


func load_dict(saved: Dictionary) -> void:
	new_game()
	var heroes_saved: Dictionary = saved.get("heroes", {})
	for progress in heroes:
		if heroes_saved.has(String(progress.data.id)):
			progress.load_dict(heroes_saved[String(progress.data.id)])
	gold = int(saved.get("gold", START_GOLD))
	inventory = _name_keys(saved.get("inventory", {}))
	equipment_bag = _name_keys(saved.get("equipment_bag", {}))
	current_map = saved.get("map", START_MAP)
	var position = saved.get("position")
	player_position = Vector2(position[0], position[1]) if position != null else null
	for id in saved.get("defeated", []):
		defeated_encounters[id] = true
	for id in saved.get("chests", []):
		opened_chests[id] = true


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
