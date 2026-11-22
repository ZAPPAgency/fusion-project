@tool
class_name Lantern
extends StaticBody2D
## Lanterne sur poteau : éclaire les alentours d'une lumière chaude qui vacille ;
## quelques papillons de nuit tournent autour (pas en qualité basse).

var _light: PointLight2D
var _time := 0.0
var _moths: CPUParticles2D


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
	_make_moths()
	Settings.quality_changed.connect(_make_moths)


func _make_moths() -> void:
	if _moths:
		_moths.queue_free()
		_moths = null
	if Settings.quality == Settings.Quality.LOW:
		return
	_moths = CPUParticles2D.new()
	_moths.material = FxLibrary.unshaded_material()
	_moths.position = Vector2(0, -40)
	_moths.z_index = 2
	_moths.amount = Settings.particles(4)
	_moths.lifetime = 3.0
	_moths.preprocess = 3.0
	_moths.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_moths.emission_sphere_radius = 9.0
	_moths.gravity = Vector2.ZERO
	_moths.spread = 180.0
	_moths.initial_velocity_min = 2.0
	_moths.initial_velocity_max = 6.0
	_moths.orbit_velocity_min = 0.25  # tournent autour de la flamme
	_moths.orbit_velocity_max = 0.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	var wing := Color(1.5, 1.3, 1.0)
	ramp.colors = PackedColorArray([Color(wing, 0.0), Color(wing, 0.9), Color(wing, 0.9), Color(wing, 0.0)])
	_moths.color_ramp = ramp
	add_child(_moths)


func _process(delta: float) -> void:
	if _light:
		_time += delta
		_light.energy = 0.85 + sin(_time * 7.0) * 0.05 + sin(_time * 13.0) * 0.04


func _draw() -> void:
	draw_rect(Rect2(-5, -2, 10, 3), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-1, -36, 3, 36), Color("3a2c22"))
	draw_rect(Rect2(-4, -44, 9, 9), Color("2a2a2a"))
	draw_rect(Rect2(-3, -43, 7, 7), Color(2.8, 1.9, 0.8))  # flamme : brille avec le glow
