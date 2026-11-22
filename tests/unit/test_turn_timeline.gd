extends GutTest


func _unit(speed: int) -> BattleUnit:
	var data := CombatantData.new()
	data.speed = speed
	data.max_hp = 10
	return BattleUnit.new(data)


func test_faster_unit_plays_more_often() -> void:
	var fast := _unit(20)
	var slow := _unit(10)
	var timeline := TurnTimeline.new([fast, slow])
	var order := []
	for i in 6:
		order.append(timeline.next_unit())
	assert_eq(order, [fast, fast, slow, fast, fast, slow])


func test_ties_follow_list_order() -> void:
	var first := _unit(10)
	var second := _unit(10)
	var timeline := TurnTimeline.new([first, second])
	assert_eq(timeline.next_unit(), first)
	assert_eq(timeline.next_unit(), second)


func test_preview_does_not_change_the_order() -> void:
	var fast := _unit(15)
	var slow := _unit(8)
	var timeline := TurnTimeline.new([fast, slow])
	var preview := timeline.preview(5)
	for i in 5:
		assert_eq(timeline.next_unit(), preview[i])


func test_dead_units_are_skipped() -> void:
	var alive := _unit(10)
	var dead := _unit(30)
	var timeline := TurnTimeline.new([alive, dead])
	dead.take_damage(999)
	assert_eq(timeline.next_unit(), alive)
	assert_false(timeline.preview(3).has(dead))
