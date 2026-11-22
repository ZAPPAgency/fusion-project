extends GutTest


func _unit(max_hp := 50) -> BattleUnit:
	var data := CombatantData.new()
	data.max_hp = max_hp
	return BattleUnit.new(data)


func test_hp_never_goes_below_zero_and_unit_dies() -> void:
	var unit := _unit()
	watch_signals(unit)
	unit.take_damage(80)
	assert_eq(unit.hp, 0)
	assert_false(unit.is_alive())
	assert_signal_emitted(unit, "died")


func test_heal_is_capped_at_max_hp() -> void:
	var unit := _unit()
	unit.take_damage(10)
	unit.heal(100)
	assert_eq(unit.hp, 50)


func test_dead_units_cannot_be_healed() -> void:
	var unit := _unit()
	unit.take_damage(50)
	unit.heal(20)
	assert_eq(unit.hp, 0)


func test_ap_is_clamped_between_zero_and_max() -> void:
	var unit := _unit()
	assert_eq(unit.ap, BattleUnit.START_AP)
	unit.gain_ap(100)
	assert_eq(unit.ap, BattleUnit.MAX_AP)
	unit.spend_ap(100)
	assert_eq(unit.ap, 0)


func test_can_pay_checks_current_ap() -> void:
	var unit := _unit()
	assert_true(unit.can_pay(BattleUnit.START_AP))
	assert_false(unit.can_pay(BattleUnit.START_AP + 1))


func test_suffix_distinguishes_identical_enemies() -> void:
	var data := CombatantData.new()
	data.display_name = "Loup"
	var unit := BattleUnit.new(data)
	unit.add_suffix("B")
	assert_eq(unit.display_name, "Loup B")
	assert_eq(unit.short_name, "LB")
