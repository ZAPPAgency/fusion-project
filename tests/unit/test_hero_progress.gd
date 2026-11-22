extends GutTest
## Progression d'un héros : niveaux, stats, compétences, cartes équipées, sauvegarde.

var _data: CombatantData


func before_each() -> void:
	_data = CombatantData.new()
	_data.id = &"test"
	_data.max_hp = 100
	_data.attack = 10
	_data.defense = 10
	_data.speed = 10
	_data.hp_growth = 10.0
	_data.attack_growth = 2.0
	_data.defense_growth = 1.0
	_data.speed_growth = 0.5


func _skill(level: int) -> SkillData:
	var skill := SkillData.new()
	skill.unlock_level = level
	return skill


func _card(card_id: StringName, attack := 0, max_hp := 0, rank := 1) -> CardInstance:
	var data := CardData.new()
	data.id = card_id
	data.attack = attack
	data.attack_per_rank = 1.0
	data.max_hp = max_hp
	return CardInstance.new(data, 1, rank)


func test_starts_level_one_with_full_hp() -> void:
	var hero := HeroProgress.new(_data)
	assert_eq(hero.level, 1)
	assert_eq(hero.hp, 100)


func test_xp_levels_up_and_grows_stats() -> void:
	var hero := HeroProgress.new(_data)
	var reached := hero.add_xp(HeroProgress.xp_to_next(1) + HeroProgress.xp_to_next(2))
	assert_eq(reached, [2, 3])
	assert_eq(hero.max_hp(), 120)
	assert_eq(hero.attack(), 14)
	assert_eq(hero.speed(), 11, "0.5 par niveau : +1 au bout de 2 niveaux")


func test_level_up_raises_current_hp_by_the_max_hp_gain() -> void:
	var hero := HeroProgress.new(_data)
	hero.hp = 40
	hero.add_xp(HeroProgress.xp_to_next(1))
	assert_eq(hero.hp, 50)


func test_leftover_xp_is_kept() -> void:
	var hero := HeroProgress.new(_data)
	hero.add_xp(HeroProgress.xp_to_next(1) + 7)
	assert_eq(hero.xp, 7)


func test_level_is_capped() -> void:
	var hero := HeroProgress.new(_data)
	hero.add_xp(100000)
	assert_eq(hero.level, HeroProgress.MAX_LEVEL)
	assert_eq(hero.xp, 0)


func test_skills_unlock_with_level() -> void:
	var early := _skill(1)
	var late := _skill(3)
	_data.skills = [early, late]
	var hero := HeroProgress.new(_data)
	assert_eq(hero.skills(), [early])
	hero.add_xp(HeroProgress.xp_to_next(1) + HeroProgress.xp_to_next(2))
	assert_eq(hero.skills(), [early, late])
	assert_eq(hero.skills_learned_at(3), [late])


func test_card_adds_bonuses_and_returns_previous_card() -> void:
	var hero := HeroProgress.new(_data)
	var sword := _card(&"epee", 4)
	assert_null(hero.equip(0, sword))
	assert_eq(hero.attack(), 14)
	var better := _card(&"lame", 6)
	assert_eq(hero.equip(0, better), sword)
	assert_eq(hero.attack(), 16)


func test_card_rank_raises_its_bonus() -> void:
	var hero := HeroProgress.new(_data)
	hero.equip(0, _card(&"epee", 4, 0, 3))
	assert_eq(hero.attack(), 16, "4 + 1 par rang au-dessus du premier")


func test_removing_hp_card_caps_current_hp() -> void:
	var hero := HeroProgress.new(_data)
	hero.equip(1, _card(&"anneau", 0, 25))
	hero.hp = hero.max_hp()
	hero.equip(1, null)
	assert_eq(hero.hp, 100)


func test_card_slots_unlock_with_level() -> void:
	var hero := HeroProgress.new(_data)
	assert_eq(hero.card_slots(), 2)
	assert_false(hero.can_equip(2, _card(&"epee")), "3e emplacement verrouillé au niveau 1")
	hero.level = 6
	assert_eq(hero.card_slots(), 4)
	hero.level = HeroProgress.MAX_LEVEL
	assert_eq(hero.card_slots(), 5)


func test_same_card_cannot_be_equipped_twice_on_one_hero() -> void:
	var hero := HeroProgress.new(_data)
	hero.equip(0, _card(&"epee"))
	assert_false(hero.can_equip(1, _card(&"epee")))
	assert_true(hero.can_equip(1, _card(&"anneau")))


func test_hero_bound_card_only_fits_its_hero() -> void:
	var hero := HeroProgress.new(_data)
	var card := _card(&"arc")
	card.data.for_hero = &"autre_heros"
	assert_false(hero.can_equip(0, card))
	card.data.for_hero = &"test"
	assert_true(hero.can_equip(0, card))


func test_card_skill_passive_and_timing_are_added() -> void:
	var hero := HeroProgress.new(_data)
	var card := _card(&"magie")
	card.data.skill = _skill(1)
	card.data.passive = CardData.Passive.PARRY_AP
	card.data.passive_value = 1.0
	card.data.timing_bonus_ms = 10.0
	card.data.timing_bonus_per_rank = 5.0
	card.rank = 3
	hero.equip(0, card)
	assert_has(hero.skills(), card.data.skill)
	assert_eq(hero.passive(CardData.Passive.PARRY_AP), 1.0)
	assert_eq(hero.timing_bonus_ms(), 20.0)


func test_save_round_trip() -> void:
	var hero := HeroProgress.new(_data)
	hero.add_xp(HeroProgress.xp_to_next(1) + 5)
	hero.hp = 42
	var card := _card(&"epee", 4)
	hero.equip(1, card)
	var copy := HeroProgress.new(_data)
	copy.load_dict(hero.to_dict(), {card.uid: card})
	assert_eq(copy.slots[1], card)
	assert_eq(copy.level, 2)
	assert_eq(copy.xp, 5)
	assert_eq(copy.hp, 42)
