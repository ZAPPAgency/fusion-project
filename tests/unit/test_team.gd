extends GutTest
## Équipe de 3 et réserve : le Gardien rejoint après le boss (ou d'office en partie de test).

const TEST_SAVE := "user://test_team_save.json"
const BOSS := "res://data/enemies/gardien_cloche.tres"


func before_each() -> void:
	GameState.new_game()


func after_all() -> void:
	GameState.new_game()
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _gardien() -> HeroProgress:
	return GameState.progress_of(GameState.hero_data(&"gardien"))


func _beat_boss() -> Array[String]:
	return GameState.win_battle({}, [load(BOSS)])


func test_new_game_has_three_heroes_all_in_the_party() -> void:
	assert_eq(GameState.heroes.size(), 3)
	assert_eq(GameState.party.size(), GameState.MAX_PARTY)
	assert_null(_gardien())


func test_beating_the_boss_recruits_the_gardien_on_the_bench() -> void:
	var report := _beat_boss()
	assert_not_null(_gardien())
	assert_eq(GameState.heroes.size(), 4)
	assert_eq(GameState.party.size(), GameState.MAX_PARTY, "toujours 3 au combat")
	assert_false(GameState.in_party(_gardien()))
	assert_true(report.has(tr("REWARD_RECRUIT").format({"hero": tr("HERO_GARDIEN")})))
	assert_eq(_gardien().slots[0].data.id, &"echo_cloche", "carte de départ")


func test_recruit_joins_at_the_strongest_level() -> void:
	GameState.heroes[0].add_xp(2000)
	_beat_boss()
	assert_eq(_gardien().level, GameState.heroes[0].level)
	assert_eq(_gardien().hp, _gardien().max_hp())


func test_beating_the_boss_twice_recruits_once() -> void:
	_beat_boss()
	_beat_boss()
	assert_eq(GameState.heroes.size(), 4)


func test_swap_puts_the_bench_hero_in_the_same_place() -> void:
	_beat_boss()
	var ysolde := GameState.heroes[1]
	GameState.swap_party(_gardien(), ysolde)
	assert_eq(GameState.party[1], _gardien().data)
	assert_false(GameState.in_party(ysolde))


func test_swapping_out_the_leader_gives_the_lead_to_the_newcomer() -> void:
	_beat_boss()
	GameState.swap_party(_gardien(), GameState.leader())
	assert_eq(GameState.leader(), _gardien())


func test_leader_only_cycles_through_the_party() -> void:
	_beat_boss()
	GameState.swap_party(_gardien(), GameState.heroes[2])  # Fenn sort
	var seen := {}
	for i in 6:
		GameState.cycle_leader()
		seen[GameState.leader().data.id] = true
	assert_false(seen.has(&"fenn"))
	assert_eq(seen.size(), 3)


func test_test_game_unlocks_every_hero() -> void:
	GameState.new_test_game()
	assert_not_null(_gardien())
	assert_eq(GameState.party.size(), GameState.MAX_PARTY)
	assert_eq(_gardien().level, HeroProgress.MAX_LEVEL)


func test_team_is_saved() -> void:
	SaveSystem.save_path = TEST_SAVE
	_beat_boss()
	_gardien().add_xp(300)
	var level := _gardien().level
	GameState.swap_party(_gardien(), GameState.heroes[0])
	assert_true(SaveSystem.save_game(Vector2(10, 20)))

	GameState.new_game()
	assert_true(SaveSystem.load_game())
	assert_not_null(_gardien())
	assert_eq(_gardien().level, level)
	assert_eq(GameState.party[0].id, &"gardien")
	assert_false(GameState.in_party(GameState.heroes[0]))
	assert_eq(_gardien().slots[0].data.id, &"echo_cloche")
	assert_eq(GameState.cards.filter(func(card: CardInstance) -> bool: return card.data.id == &"echo_cloche").size(), 1,
		"pas de carte de départ en double au chargement")


func test_gardien_has_three_stages_and_no_wings() -> void:
	var stages := GameState.hero_data(&"gardien").stages
	assert_eq(stages.size(), 3)
	assert_eq(stages[2].aura_element, HeroStage.AuraElement.BELL)


func test_seen_tutorial_tips_are_saved_and_reset_by_a_new_game() -> void:
	GameState.seen_tips[&"forge"] = true
	var saved := GameState.to_dict()
	GameState.new_game()
	assert_false(GameState.seen_tips.has(&"forge"), "nouvelle partie : les fiches reviennent")
	GameState.load_dict(saved)
	assert_true(GameState.seen_tips.has(&"forge"))


func test_every_tutorial_text_is_translated() -> void:
	for id in Tutorial.TIPS:
		for page: Dictionary in Tutorial.TIPS[id]:
			for key in [page.title] + page.lines:
				assert_ne(TranslationServer.translate(key), key, "texte manquant : %s" % key)


func test_no_tutorial_in_the_test_game() -> void:
	var was_disabled: bool = Tutorial._disabled
	Tutorial._disabled = false  # comme dans le vrai jeu (les tests coupent les fiches)
	GameState.new_game()
	assert_true(Tutorial.should_show(&"battle"), "partie normale : la fiche s'affiche")
	GameState.new_test_game()
	for id in Tutorial.TIPS:
		assert_false(Tutorial.should_show(id), "fiche %s dans la partie de test" % id)
	Tutorial._disabled = was_disabled
