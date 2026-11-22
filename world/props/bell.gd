@tool
class_name Bell
extends Interactable
## La grande cloche fêlée de Valbrune, sur son portique. Sa fissure brille.
## On peut l'examiner ; le texte change une fois le Gardien vaincu.

@export var boss_encounter_id := "gardien"

var _glow_time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super()
	_add_collision(Vector2(70, 14), Vector2(0, -7))
	var light := PointLight2D.new()
	light.texture = FxLibrary.light_texture()
	light.color = Color(1.0, 0.45, 0.15)
	light.energy = 0.8
	light.texture_scale = 2.5
	light.position = Vector2(0, -50)
	add_child(light)


func _process(delta: float) -> void:
	_glow_time += delta
	queue_redraw()
	if not Engine.is_editor_hint():
		super(delta)


func interact(_player: Node2D) -> void:
	if GameState.defeated_encounters.has(boss_encounter_id):
		await Dialogue.say("", ["DLG_BELL_AFTER_1", "DLG_BELL_AFTER_2"])
	else:
		await Dialogue.say("", ["DLG_BELL_BEFORE"])


func _draw() -> void:
	var wood := Color("4a3626")
	draw_rect(Rect2(-36, -4, 72, 6), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-34, -92, 6, 92), wood)
	draw_rect(Rect2(28, -92, 6, 92), wood)
	draw_rect(Rect2(-38, -98, 76, 8), wood.darkened(0.2))
	# Cloche en bronze.
	var bronze := Color("8a6a35")
	var bell := PackedVector2Array([Vector2(-8, -88), Vector2(8, -88), Vector2(14, -70), Vector2(20, -46), Vector2(24, -40), Vector2(-24, -40), Vector2(-20, -46), Vector2(-14, -70)])
	draw_colored_polygon(bell, bronze)
	draw_rect(Rect2(-24, -42, 48, 3), bronze.darkened(0.3))
	draw_rect(Rect2(-10, -84, 4, 36), bronze.lightened(0.25))
	# Fissure incandescente qui pulse.
	var glow := 2.5 + sin(_glow_time * 2.0) * 0.8
	var crack := Color(glow, glow * 0.45, glow * 0.12)
	var points := [Vector2(3, -88), Vector2(0, -78), Vector2(5, -70), Vector2(1, -60), Vector2(6, -50), Vector2(2, -40)]
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], crack, 2.0)
