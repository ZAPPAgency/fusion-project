extends GutTest
## Cartes : fichiers de données, bonus par rang, textes d'effet, effets en combat.


func _all_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for file in DirAccess.get_files_at("res://data/cards"):
		if file.ends_with(".tres"):
			cards.append(load("res://data/cards/" + file))
	return cards


func test_every_card_file_is_valid() -> void:
	var cards := _all_cards()
	assert_gt(cards.size(), 15)
	for card in cards:
		assert_eq(card.resource_path.get_file().get_basename(), String(card.id), "l'id correspond au nom du fichier")
		assert_ne(tr(card.display_name), card.display_name, "%s a un nom traduit" % card.id)
		assert_false(CardInstance.new(card, 1).effect_lines().is_empty(), "%s a au moins un effet" % card.id)
		if card.skill:
			assert_ne(card.for_hero, &"", "une carte de compétence est liée à un héros (animations)")


func test_stat_grows_with_rank_and_rounds_down() -> void:
	var data := CardData.new()
	data.speed = 1
	data.speed_per_rank = 0.5
	assert_eq(CardInstance.new(data, 1, 1).stat("speed"), 1)
	assert_eq(CardInstance.new(data, 1, 2).stat("speed"), 1)
	assert_eq(CardInstance.new(data, 1, 3).stat("speed"), 2)


func test_effect_text_shows_percentages() -> void:
	var data := CardData.new()
	data.passive = CardData.Passive.COUNTER_POWER
	data.passive_value = 0.5
	var text := "".join(CardInstance.new(data, 1).effect_lines())
	assert_string_contains(text, "50")


func test_save_round_trip_keeps_rank() -> void:
	var card := CardInstance.new(load("res://data/cards/garde_fer.tres"), 7, 4)
	var copy := CardInstance.from_dict(card.to_dict())
	assert_eq(copy.uid, 7)
	assert_eq(copy.rank, 4)
	assert_eq(copy.data.id, &"garde_fer")


func test_battle_unit_gets_passives_and_start_ap() -> void:
	var aldric: CombatantData = load("res://data/characters/aldric.tres")
	var progress := HeroProgress.new(aldric)
	progress.equip(0, CardInstance.new(load("res://data/cards/echo_cloche.tres"), 1))
	progress.equip(1, CardInstance.new(load("res://data/cards/oeil_vigilant.tres"), 2))
	var unit := BattleUnit.new(aldric)
	unit.apply_progress(progress)
	assert_eq(unit.ap, BattleUnit.START_AP + 2)
	assert_eq(unit.passive_ap(CardData.Passive.START_AP), 2)
	assert_eq(unit.passive(CardData.Passive.PARRY_AP), 0.0)
	assert_eq(unit.timing_bonus_ms, 15.0)


func test_card_art_is_cut_from_the_sprite() -> void:
	var art := CardView.art_texture(load("res://data/cards/croc_squelette.tres"))
	assert_not_null(art)
	assert_lte(art.get_width(), int(CardView.ART_RECT.size.x))
