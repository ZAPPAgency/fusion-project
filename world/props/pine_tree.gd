@tool
class_name PineTree
extends StaticBody2D
## Sapin dessiné (provisoire). L'origine est au pied du tronc ; seul le tronc bloque.

@export var height := 64.0:
	set(value):
		height = value
		queue_redraw()
@export var dark := false:  ## Forêt profonde : feuillage plus sombre
	set(value):
		dark = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -4)
	add_child(collision)


func _draw() -> void:
	var leaves := Color("1f3a2c") if dark else Color("2a4a33")
	var light := leaves.lightened(0.18)
	var width := height * 0.55
	_ellipse(Vector2(0, 0), Vector2(width * 0.45, 5), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-3, -height * 0.18, 6, height * 0.18), Color("4a3322"))
	for tier in 3:
		var top := -height + tier * height * 0.24
		var bottom := top + height * 0.42
		var half := width * (0.45 + tier * 0.27) / 2
		draw_colored_polygon(PackedVector2Array([Vector2(0, top), Vector2(half, bottom), Vector2(-half, bottom)]), leaves)
		# Côté gauche éclairé par la lune.
		draw_colored_polygon(PackedVector2Array([Vector2(0, top), Vector2(0, bottom), Vector2(-half, bottom)]), light)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
