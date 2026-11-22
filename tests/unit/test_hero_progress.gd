extends GutTest
## Progression d'un héros : niveaux, stats, compétences, équipement, sauvegarde.

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


func _item(slot: EquipmentData.Slot, attack := 0, max_hp := 0) -> EquipmentData:
	var item := EquipmentData.new()
	item.id = &"objet_test"
	item.slot = slot
	item.attack = attack
	item.max_hp = max_hp
	return item


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


func test_equipment_adds_bonuses_and_returns_previous_item() -> void:
	var hero := HeroProgress.new(_data)
	var sword := _item(EquipmentData.Slot.WEAPON, 4)
	assert_null(hero.equip(EquipmentData.Slot.WEAPON, sword))
	assert_eq(hero.attack(), 14)
	var better := _item(EquipmentData.Slot.WEAPON, 6)
	assert_eq(hero.equip(EquipmentData.Slot.WEAPON, better), sword)
	assert_eq(hero.attack(), 16)


func test_removing_hp_equipment_caps_current_hp() -> void:
	var hero := HeroProgress.new(_data)
	hero.equip(EquipmentData.Slot.ACCESSORY, _item(EquipmentData.Slot.ACCESSORY, 0, 25))
	hero.hp = hero.max_hp()
	hero.equip(EquipmentData.Slot.ACCESSORY, null)
	assert_eq(hero.hp, 100)


func test_save_round_trip() -> void:
	var hero := HeroProgress.new(_data)
	hero.add_xp(HeroProgress.xp_to_next(1) + 5)
	hero.hp = 42
	var copy := HeroProgress.new(_data)
	copy.load_dict(hero.to_dict())
	assert_eq(copy.level, 2)
	assert_eq(copy.xp, 5)
	assert_eq(copy.hp, 42)
