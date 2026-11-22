@tool
class_name ForgeFurnace
extends StaticBody2D
## Forge du village : fourneau de pierre aux braises incandescentes, enclume,
## lumière orange qui vacille et étincelles qui s'envolent.

var _light: PointLight2D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 12)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(4, -6)
	add_child(collision)
	_light = PointLight2D.new()
	_light.texture = FxLibrary.light_texture()
	_light.color = Color(1.0, 0.55, 0.2)
	_light.energy = 1.1
	_light.texture_scale = 2.0
	_light.position = Vector2(-10, -14)
	add_child(_light)
	add_child(_embers())


func _process(delta: float) -> void:
	if _light:
		_time += delta
		_light.energy = 1.05 + sin(_time * 9.0) * 0.08 + sin(_time * 17.0) * 0.06


func _draw() -> void:
	draw_rect(Rect2(-24, -2, 50, 4), Color(0, 0, 0, 0.3))
	# Fourneau en pierre avec sa bouche de braises (> 1 : brille avec le glow).
	var stone := Color("4a4440")
	draw_rect(Rect2(-24, -30, 28, 30), stone)
	draw_rect(Rect2(-24, -30, 28, 3), stone.lightened(0.15))
	for row in 3:
		draw_rect(Rect2(-24, -21 + row * 8, 28, 1), stone.darkened(0.3))
	draw_rect(Rect2(-20, -38, 8, 8), stone.darkened(0.15))  # cheminée
	draw_rect(Rect2(-18, -16, 16, 12), Color(0.12, 0.05, 0.03))
	draw_rect(Rect2(-17, -10, 14, 5), Color(3.2, 1.4, 0.35))
	draw_rect(Rect2(-15, -13, 10, 3), Color(2.2, 0.8, 0.2))
	# Enclume.
	var iron := Color("3c3f46")
	draw_rect(Rect2(12, -6, 8, 6), iron.darkened(0.3))
	draw_rect(Rect2(14, -10, 4, 4), iron)
	draw_rect(Rect2(8, -14, 18, 4), iron.lightened(0.1))
	draw_rect(Rect2(6, -14, 4, 2), iron.lightened(0.1))
	draw_rect(Rect2(8, -14, 18, 1), iron.lightened(0.4))


func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.material = FxLibrary.unshaded_material()
	embers.position = Vector2(-16, -38)
	embers.amount = 8
	embers.lifetime = 1.6
	embers.direction = Vector2.UP
	embers.spread = 25.0
	embers.gravity = Vector2(0, -20)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 20.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(3.0, 1.5, 0.4), Color(1.5, 0.4, 0.1, 0.0)])
	embers.color_ramp = ramp
	return embers
