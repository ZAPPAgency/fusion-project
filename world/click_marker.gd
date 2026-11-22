class_name ClickMarker
extends Node2D
## Repère du clic sur la carte : un anneau doré en pixels qui se resserre puis disparaît.

const LIFE := 0.45

var _age := 0.0


func _ready() -> void:
	z_index = -1  # au sol, sous les personnages
	material = FxLibrary.unshaded_material()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _age / LIFE
	var radius := lerpf(9.0, 3.0, progress)
	var color := Color(1.0, 0.85, 0.35, 1.0 - progress)
	for i in 20:
		var angle := TAU * i / 20
		var point := Vector2(cos(angle) * radius, sin(angle) * radius * 0.4).floor()
		draw_rect(Rect2(point, Vector2.ONE), color)
