extends GutTest
## État de la partie : PV, objets, achats, équipement, récompenses, sauvegarde.

const TEST_SAVE := "user://test_save.json"


func before_each() -> void:
	GameState.new_game()


func after_all() -> void:
	GameState.new_game()
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _aldric() -> HeroProgress:
	return GameState.heroes[0]


func test_new_game_starts_with_full_hp() -> void:
	for progress in GameState.heroes:
		assert_eq(progress.hp, progress.max_hp())


func test_heal_party_restores_hp() -> void:
	_aldric().hp = 5
	GameState.heal_party()
	assert_eq(_aldric().hp, _aldric().max_hp())


func test_add_and_remove_items() -> void:
	GameState.add_item(&"potion", 2)
	assert_eq(GameState.inventory[&"potion"], 5)
	GameState.remove_item(&"potion")
	assert_eq(GameState.inventory[&"potion"], 4)


func test_loot_goes_to_the_right_bag() -> void:
	GameState.add_loot(&"anneau_vie")
	GameState.add_loot(&"grande_potion")
	assert_eq(GameState.equipment_bag[&"anneau_vie"], 1)
	assert_eq(GameState.inventory[&"grande_potion"], 1)


func test_buy_needs_enough_gold() -> void:
	GameState.gold = 10
	assert_false(GameState.buy(&"potion"))
	GameState.gold = 25
	assert_true(GameState.buy(&"potion"))
	assert_eq(GameState.gold, 5)


func test_equip_swaps_with_the_bag() -> void:
	var sword := GameState.equipment_data(&"epee_acier")
	GameState.add_loot(&"epee_acier")
	GameState.equip(_aldric(), EquipmentData.Slot.WEAPON, sword)
	assert_false(GameState.equipment_bag.has(&"epee_acier"))
	assert_eq(_aldric().equipped(EquipmentData.Slot.WEAPON), sword)
	GameState.equip(_aldric(), EquipmentData.Slot.WEAPON, null)
	assert_eq(GameState.equipment_bag[&"epee_acier"], 1)


func test_victory_gives_xp_gold_and_revives_knocked_out_heroes() -> void:
	var gold_before := GameState.gold
	var hp := {}
	for progress in GameState.heroes:
		hp[progress.data.id] = 0
	var report := GameState.win_battle(hp, [load("res://data/enemies/gardien_cloche.tres")])
	assert_eq(GameState.gold, gold_before + 80)
	assert_gt(_aldric().level, 1, "150 XP font monter de niveau")
	assert_gte(_aldric().hp, 1)
	assert_gt(report.size(), 1)


func test_save_and_load_round_trip() -> void:
	SaveSystem.save_path = TEST_SAVE
	GameState.gold = 123
	GameState.add_loot(&"cotte_mailles")
	GameState.opened_chests["village_chest_0"] = true
	GameState.defeated_encounters["forest_1"] = true
	_aldric().add_xp(200)
	var level := _aldric().level
	assert_true(SaveSystem.save_game(Vector2(100, 200)))

	GameState.new_game()
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.gold, 123)
	assert_eq(GameState.equipment_bag[&"cotte_mailles"], 1)
	assert_true(GameState.opened_chests.has("village_chest_0"))
	assert_true(GameState.defeated_encounters.has("forest_1"))
	assert_eq(_aldric().level, level)
	assert_eq(GameState.player_position, Vector2(100, 200))


func test_arriving_on_a_map_forgets_the_old_position() -> void:
	GameState.player_position = Vector2(10, 10)
	GameState.arrive_at("res://world/maps/forest.tscn", "from_village")
	assert_eq(GameState.current_map, "res://world/maps/forest.tscn")
	assert_eq(GameState.spawn_name, "from_village")
	assert_null(GameState.player_position)
