class_name Glint
extends Node2D
## Reflet bref sur l'arme : annonce qu'un coup va tomber (indice de timing).

var _size := 1.0
var _growth := 0.0  # 0 → 1 → 0 pendant l'animation


func setup(size_scale: float) -> void:
	_size = size_scale


func _ready() -> void:
	z_index = 50
	material = FxLibrary.unshaded_material()
	modulate = Color(2.0, 1.8, 1.2)  # valeurs > 1 : brillera avec le glow (étape 5)
	var tween := create_tween()
	tween.tween_property(self, "_growth", 1.0, 0.08)
	tween.tween_property(self, "_growth", 0.0, 0.16)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


## Étoile à 4 branches.
func _draw() -> void:
	var radius := 8.0 * _size * _growth
	if radius < 0.5:
		return
	var thin := radius * 0.25
	var points := PackedVector2Array([
		Vector2(0, -radius), Vector2(thin, -thin), Vector2(radius, 0), Vector2(thin, thin),
		Vector2(0, radius), Vector2(-thin, thin), Vector2(-radius, 0), Vector2(-thin, -thin),
	])
	draw_colored_polygon(points, Color.WHITE)
