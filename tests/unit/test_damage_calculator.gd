extends GutTest


func _unit(attack: int, defense: int) -> BattleUnit:
	var data := CombatantData.new()
	data.attack = attack
	data.defense = defense
	return BattleUnit.new(data)


func _skill(power: float) -> SkillData:
	var skill := SkillData.new()
	skill.power = power
	return skill


func test_defense_of_50_halves_damage() -> void:
	assert_eq(DamageCalculator.damage(_unit(20, 0), _unit(0, 50), _skill(1.0)), 10)


func test_power_and_multiplier_scale_damage() -> void:
	var attacker := _unit(20, 0)
	var defender := _unit(0, 0)
	assert_eq(DamageCalculator.damage(attacker, defender, _skill(1.5)), 30)
	assert_eq(DamageCalculator.damage(attacker, defender, _skill(1.0), 2.0), 40)


func test_damage_is_at_least_one() -> void:
	assert_eq(DamageCalculator.damage(_unit(1, 0), _unit(0, 999), _skill(0.1)), 1)


func test_heal_uses_attack_and_power() -> void:
	assert_eq(DamageCalculator.heal(_unit(14, 0), _skill(1.2)), 17)
