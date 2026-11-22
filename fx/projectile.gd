class_name Projectile
extends Node2D
## Projectile (flèche, bombe...) qui vole d'un point à un autre en `duration` secondes,
## avec une traînée lumineuse. Il arrive pile au moment de l'impact du QTE.

var _texture: Texture2D
var _from: Vector2
var _to: Vector2
var _duration: float
var _trail_color: Color


func setup(texture: Texture2D, from: Vector2, to: Vector2, duration: float, trail_color := Color(2.0, 1.8, 1.4)) -> void:
	_texture = texture
	_from = from
	_to = to
	_duration = duration
	_trail_color = trail_color


func _ready() -> void:
	z_index = 70
	position = _from
	rotation = (_to - _from).angle()

	var sprite := Sprite2D.new()
	sprite.texture = _texture
	sprite.material = FxLibrary.unshaded_material()
	sprite.modulate = Color(1.6, 1.5, 1.3)
	add_child(sprite)

	var trail := CPUParticles2D.new()
	trail.material = FxLibrary.unshaded_material()
	trail.amount = 24
	trail.lifetime = 0.2
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 5.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([_trail_color, Color(_trail_color, 0.0)])
	trail.color_ramp = ramp
	add_child(trail)

	var tween := create_tween()
	tween.tween_property(self, "position", _to, _duration)
	tween.tween_callback(queue_free)
