extends GutTest
## État de la partie : PV, objets, achats, cartes, récompenses, sauvegarde.

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


func _count_cards(card_id: StringName) -> int:
	return GameState.cards.filter(func(card: CardInstance) -> bool: return card.data.id == card_id).size()


func test_new_game_equips_starter_cards() -> void:
	for progress in GameState.heroes:
		assert_eq(progress.slots[0].data.id, GameState.STARTER_CARDS[progress.data.id])


func test_loot_goes_to_cards_or_items() -> void:
	GameState.add_loot(&"anneau_vie")
	GameState.add_loot(&"grande_potion")
	assert_eq(_count_cards(&"anneau_vie"), 1)
	assert_eq(GameState.inventory[&"grande_potion"], 1)


func test_buy_needs_enough_gold() -> void:
	GameState.gold = 10
	assert_false(GameState.buy(&"potion"))
	GameState.gold = 25
	assert_true(GameState.buy(&"potion"))
	assert_eq(GameState.gold, 5)


func test_equipping_a_worn_card_moves_it() -> void:
	var ring := GameState.add_card(&"anneau_vie")
	var ysolde := GameState.heroes[1]
	GameState.equip_card(_aldric(), 1, ring)
	assert_eq(GameState.owner_of(ring), _aldric())
	GameState.equip_card(ysolde, 1, ring)
	assert_null(_aldric().slots[1])
	assert_eq(GameState.owner_of(ring), ysolde)


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
	var mail := GameState.add_card(&"cotte_mailles", 3)
	GameState.equip_card(_aldric(), 1, mail)
	GameState.opened_chests["village_chest_0"] = true
	GameState.defeated_encounters["forest_1"] = true
	_aldric().add_xp(200)
	var level := _aldric().level
	assert_true(SaveSystem.save_game(Vector2(100, 200)))

	GameState.new_game()
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.gold, 123)
	assert_eq(_count_cards(&"cotte_mailles"), 1)
	assert_eq(_aldric().slots[1].data.id, &"cotte_mailles")
	assert_eq(_aldric().slots[1].rank, 3)
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


func test_old_save_equipment_becomes_cards() -> void:
	var old_save := {
		"heroes": {"aldric": {"level": 2, "xp": 0, "hp": 50, "equipment": {"0": "epee_acier"}}},
		"gold": 10,
		"equipment_bag": {"cape_voyage": 2},
	}
	GameState.load_dict(old_save)
	assert_eq(_count_cards(&"cape_voyage"), 2)
	assert_eq(_aldric().slots[0].data.id, &"seve_vitale", "la carte de départ reste")
	assert_eq(_aldric().slots[1].data.id, &"epee_acier", "l'arme portée devient une carte équipée")


func test_leader_cycles_and_is_saved() -> void:
	assert_eq(GameState.leader(), _aldric())
	GameState.cycle_leader()
	GameState.cycle_leader()
	assert_eq(GameState.leader().data.id, &"fenn")
	GameState.cycle_leader()
	assert_eq(GameState.leader_index, 0, "après le dernier héros, on revient au premier")
	GameState.leader_index = 1
	var saved := GameState.to_dict()
	GameState.new_game()
	GameState.load_dict(saved)
	assert_eq(GameState.leader().data.id, &"ysolde")
