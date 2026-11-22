@tool
class_name House
extends StaticBody2D
## Maison dessinée (provisoire) : murs, toit, porte, fenêtres éclairées qui brillent.
## L'origine est au milieu du bas de la façade ; toute la base bloque le passage.

@export var width := 80.0:
	set(value):
		width = value
		queue_redraw()
@export var wall_color := Color("8c7356"):
	set(value):
		wall_color = value
		queue_redraw()
@export var roof_color := Color("6a2f2a"):
	set(value):
		roof_color = value
		queue_redraw()
@export var sign_text := ""  ## Enseigne (ex. auberge), facultatif


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 40)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -20)
	add_child(collision)
	# Lumière chaude qui sort des fenêtres.
	var light := PointLight2D.new()
	light.texture = FxLibrary.light_texture()
	light.color = Color(1.0, 0.7, 0.4)
	light.energy = 0.5
	light.texture_scale = 1.2
	light.position = Vector2(0, -10)
	add_child(light)


func _draw() -> void:
	var half := width / 2
	var wall_height := 44.0
	draw_rect(Rect2(-half - 2, -2, width + 4, 6), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-half, -wall_height, width, wall_height), wall_color)
	# Colombages.
	var beam := wall_color.darkened(0.45)
	draw_rect(Rect2(-half, -wall_height, width, 3), beam)
	draw_rect(Rect2(-half, -3, width, 3), beam)
	draw_rect(Rect2(-half, -wall_height, 3, wall_height), beam)
	draw_rect(Rect2(half - 3, -wall_height, 3, wall_height), beam)
	# Toit.
	var roof := PackedVector2Array([Vector2(-half - 8, -wall_height), Vector2(half + 8, -wall_height), Vector2(half - 6, -wall_height - 34), Vector2(-half + 6, -wall_height - 34)])
	draw_colored_polygon(roof, roof_color)
	for row in 4:
		var y := -wall_height - 8 - row * 8
		draw_rect(Rect2(-half - 6 + row * 3, y, 2 * half + 12 - row * 6, 1), roof_color.darkened(0.3))
	# Porte et fenêtres (les fenêtres dépassent 1 : elles brillent avec le glow).
	draw_rect(Rect2(-7, -24, 14, 24), Color("3d2516"))
	draw_rect(Rect2(3, -13, 2, 2), Color(1.5, 1.2, 0.5))
	var window := Color(2.2, 1.5, 0.7)
	draw_rect(Rect2(-half + 9, -32, 12, 10), window)
	draw_rect(Rect2(half - 21, -32, 12, 10), window)
	draw_rect(Rect2(-half + 14, -32, 2, 10), beam)
	draw_rect(Rect2(half - 16, -32, 2, 10), beam)
	if sign_text != "":
		draw_rect(Rect2(-half + 4, -46, 24, 10), Color("5a3a1e"))
		draw_rect(Rect2(-half + 7, -43, 18, 4), Color(1.4, 1.1, 0.5))
