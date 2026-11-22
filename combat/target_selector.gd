class_name TargetSelector
extends Node2D
## Curseur pour choisir une cible : gauche/droite (ou haut/bas) pour changer,
## Espace pour valider, Échap pour revenir au menu.
## Souris : survoler un combattant le vise, clic gauche pour valider, clic droit pour annuler.

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
	if event is InputEventMouseMotion:
		var hovered := _view_under_mouse()
		if hovered != -1 and hovered != _index:
			_index = hovered
			_place()
			AudioManager.play_tick()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _view_under_mouse()
		if clicked != -1:
			get_viewport().set_input_as_handled()
			_finish(_views[clicked].unit)
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


## Indice du combattant sous la souris (-1 s'il n'y en a pas).
func _view_under_mouse() -> int:
	var mouse := get_global_mouse_position()
	for i in _views.size():
		var view := _views[i]
		var box := Rect2(view.home_position + Vector2(-view.body_size.x / 2 - 6, -view.body_size.y - 6),
			view.body_size + Vector2(12, 12))
		if box.has_point(mouse):
			return i
	return -1


func _cycle(step: int) -> void:
	_index = posmod(_index + step, _views.size())
	_place()


func _place() -> void:
	position = _views[_index].home_position + Vector2(0, -_views[_index].body_size.y - 16)


func _finish(target: BattleUnit) -> void:
	hide()
	finished.emit(target)
