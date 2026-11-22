extends GutTest
## Forge : amélioration, doublons, recettes, fabrication, évolution des cartes et des héros.


func before_each() -> void:
	GameState.new_game()
	GameState.gold = 0


func after_all() -> void:
	GameState.new_game()


func _give_materials(amount: int) -> void:
	for material_id in [&"fragment_cendre", &"minerai_fer", &"eclat_cloche", &"larme_lune"]:
		GameState.materials[material_id] = amount


func _recipe(result_id: StringName) -> FusionRecipe:
	for recipe in Forge.recipes():
		if recipe.result.id == result_id:
			return recipe
	return null


func test_upgrade_needs_and_spends_materials() -> void:
	var card := GameState.add_card(&"croc_squelette")
	assert_false(Forge.upgrade(card), "rien pour payer")
	GameState.gold = 1000
	_give_materials(10)
	assert_true(Forge.upgrade(card))
	assert_eq(card.rank, 2)
	assert_eq(GameState.material_count(&"fragment_cendre"), 9)
	assert_eq(GameState.gold, 1000 - Forge.UPGRADE_GOLD)


func test_rank_is_capped() -> void:
	GameState.gold = 100000
	_give_materials(1000)
	var card := GameState.add_card(&"croc_squelette", CardData.MAX_RANK)
	assert_false(Forge.can_upgrade(card))


func test_merging_duplicates_raises_rank_and_removes_the_copy() -> void:
	var card := GameState.add_card(&"plume_vent", 2)
	var copy := GameState.add_card(&"plume_vent", 2)
	var other_rank := GameState.add_card(&"plume_vent", 1)
	assert_eq(Forge.duplicates_of(card), [copy])
	assert_true(Forge.merge_duplicates(card, copy))
	assert_eq(card.rank, 3)
	assert_false(copy in GameState.cards)
	assert_false(Forge.merge_duplicates(card, other_rank), "rangs différents")


func test_merging_an_equipped_copy_unequips_it() -> void:
	var aldric: HeroProgress = GameState.heroes[0]
	var card := GameState.add_card(&"cotte_mailles")
	var worn := GameState.add_card(&"cotte_mailles")
	GameState.equip_card(aldric, 1, worn)
	Forge.merge_duplicates(card, worn)
	assert_null(aldric.slots[1])


func test_fusion_recipe_consumes_both_cards() -> void:
	var recipe := _recipe(&"danse_os")
	GameState.gold = recipe.gold
	var fang := GameState.add_card(&"croc_squelette")
	var result := Forge.fuse(recipe)
	assert_not_null(result, "la plume de départ de Fenn sert d'ingrédient")
	assert_eq(result.data.id, &"danse_os")
	assert_false(fang in GameState.cards)
	assert_eq(GameState.gold, 0)


func test_fusion_prefers_free_cards() -> void:
	var recipe := _recipe(&"danse_os")
	var free_feather := GameState.add_card(&"plume_vent")
	GameState.add_card(&"croc_squelette")
	assert_has(Forge.ingredients(recipe), free_feather)


func test_crafting_uses_only_materials() -> void:
	var recipe := _recipe(&"croc_squelette")
	assert_true(recipe.is_crafting())
	assert_null(Forge.fuse(recipe))
	_give_materials(5)
	GameState.gold = 100
	var card := Forge.fuse(recipe)
	assert_eq(card.data.id, &"croc_squelette")
	assert_eq(GameState.material_count(&"fragment_cendre"), 2)


func test_card_evolution_needs_max_rank() -> void:
	GameState.gold = 1000
	_give_materials(5)
	var sword := GameState.add_card(&"epee_acier", 4)
	assert_false(Forge.can_evolve(sword))
	sword.rank = CardData.MAX_RANK
	GameState.equip_card(GameState.heroes[0], 1, sword)
	assert_true(Forge.evolve(sword))
	assert_eq(sword.data.id, &"lame_aube")
	assert_eq(sword.rank, 1)
	assert_eq(GameState.heroes[0].slots[1], sword, "reste équipée")
	assert_eq(GameState.material_count(&"eclat_cloche"), 3)


func test_hero_evolution_needs_level_and_changes_stats_and_skills() -> void:
	var aldric: HeroProgress = GameState.heroes[0]
	GameState.gold = 100000
	_give_materials(100)
	assert_false(Forge.can_evolve_hero(aldric), "niveau trop bas")
	aldric.add_xp(100000)
	var attack_before := aldric.attack()
	assert_true(Forge.evolve_hero(aldric))
	assert_eq(aldric.stage, 1)
	assert_gt(aldric.attack(), attack_before)
	assert_has(aldric.skills(), aldric.stage_data().skill)
	assert_true(Forge.evolve_hero(aldric))
	assert_null(aldric.next_stage_data(), "stade maximum")
	assert_false(Forge.can_evolve_hero(aldric))


func test_test_game_gives_every_card_and_saves_apart() -> void:
	GameState.new_test_game()
	assert_true(GameState.test_mode)
	for card_id in GameState.all_card_ids():
		assert_true(GameState.cards.any(func(card: CardInstance) -> bool: return card.data.id == card_id and card.rank == CardData.MAX_RANK))
	assert_eq(GameState.heroes[0].level, HeroProgress.MAX_LEVEL)
	assert_true(Forge.can_evolve_hero(GameState.heroes[0]))


func test_every_recipe_and_evolution_is_valid() -> void:
	assert_gte(Forge.recipes().size(), 10)
	for recipe in Forge.recipes():
		assert_not_null(recipe.result)
		for material_id in recipe.materials:
			assert_true(ResourceLoader.exists("res://data/materials/%s.tres" % material_id))
	for card_id in GameState.all_card_ids():
		var card := GameState.card_data(card_id)
		if card.evolves_into:
			assert_true(ResourceLoader.exists("res://data/materials/%s.tres" % card.evolution_material), "%s : matériau d'évolution" % card_id)
