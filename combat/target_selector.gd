class_name TargetSelector
extends Node2D
## Curseur pour choisir une cible : gauche/droite (ou haut/bas) pour changer,
## Espace pour valider, Échap pour revenir au menu.

signal finished(target: BattleUnit)  # null si le joueur annule

var _views: Array[UnitView] = []
var _index := 0
var _time := 0.0


func _ready() -> void:
	z_index = 200
	material = FxLibrary.unshaded_material()
	hide()


func choose(views: Array[UnitView]) -> void:
	_views = views
	_index = 0
	_place()
	show()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


## Petit triangle doré qui flotte au-dessus de la cible.
func _draw() -> void:
	var tip := Vector2(0, sin(_time * 8.0) * 2.0)
	var points := PackedVector2Array([tip, tip + Vector2(-5, -7), tip + Vector2(5, -7)])
	draw_colored_polygon(points, Color(1.0, 0.85, 0.3))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle(-1)
	elif event.is_action_pressed("ui_accept"):
		_finish(_views[_index].unit)
	elif event.is_action_pressed("ui_cancel"):
		_finish(null)
	else:
		return
	get_viewport().set_input_as_handled()


func _cycle(step: int) -> void:
	_index = posmod(_index + step, _views.size())
	_place()


func _place() -> void:
	position = _views[_index].home_position + Vector2(0, -_views[_index].body_size.y - 16)


func _finish(target: BattleUnit) -> void:
	hide()
	finished.emit(target)
