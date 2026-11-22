@tool
class_name Lantern
extends StaticBody2D
## Lanterne sur poteau : éclaire les alentours d'une lumière chaude qui vacille.

var _light: PointLight2D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6, 6)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -3)
	add_child(collision)
	_light = PointLight2D.new()
	_light.texture = FxLibrary.light_texture()
	_light.color = Color(1.0, 0.72, 0.4)
	_light.energy = 0.9
	_light.texture_scale = 2.2
	_light.position = Vector2(0, -38)
	add_child(_light)


func _process(delta: float) -> void:
	if _light:
		_time += delta
		_light.energy = 0.85 + sin(_time * 7.0) * 0.05 + sin(_time * 13.0) * 0.04


func _draw() -> void:
	draw_rect(Rect2(-5, -2, 10, 3), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-1, -36, 3, 36), Color("3a2c22"))
	draw_rect(Rect2(-4, -44, 9, 9), Color("2a2a2a"))
	draw_rect(Rect2(-3, -43, 7, 7), Color(2.8, 1.9, 0.8))  # flamme : brille avec le glow
