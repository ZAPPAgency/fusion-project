extends Node2D
## Décor provisoire : la forêt de Brumecendre la nuit, avec des cendres qui flottent.
## Dessiné un peu plus grand que l'écran pour les zooms et tremblements de la caméra.

const AREA := Rect2(-120, -80, 880, 520)
const HORIZON := 150.0
const SKY_TOP := Color("080a16")
const SKY_BOTTOM := Color("232a45")
const MOON := Color(1.7, 1.65, 1.5)  # > 1 : la lune brille avec le glow
const FAR_TREES := Color("1a2236")
const MID_TREES := Color("131b24")
const GROUND_TOP := Color("2b3326")
const GROUND_BOTTOM := Color("171c16")
const FOG := Color(0.6, 0.65, 0.8, 0.10)


func _ready() -> void:
	z_index = -10
	_make_ash()


func _draw() -> void:
	_vertical_gradient(Rect2(AREA.position, Vector2(AREA.size.x, HORIZON - AREA.position.y)), SKY_TOP, SKY_BOTTOM)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var star := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(-60, 110))
		draw_rect(Rect2(star.floor(), Vector2.ONE), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	draw_circle(Vector2(520, 62), 11, MOON)
	draw_circle(Vector2(520, 62), 18, Color(0.8, 0.85, 1.0, 0.06))

	for i in 22:
		_pine(-110 + i * 40 + rng.randf_range(-8, 8), HORIZON + 4, rng.randf_range(50, 80), FAR_TREES)
	draw_rect(Rect2(AREA.position.x, HORIZON - 30, AREA.size.x, 34), FOG)
	for i in 15:
		_pine(-100 + i * 60 + rng.randf_range(-12, 12), HORIZON + 10, rng.randf_range(80, 115), MID_TREES)

	_vertical_gradient(Rect2(AREA.position.x, HORIZON, AREA.size.x, AREA.end.y - HORIZON), GROUND_TOP, GROUND_BOTTOM)
	draw_rect(Rect2(AREA.position.x, HORIZON, AREA.size.x, 14), FOG)
	for i in 70:
		var tuft := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(HORIZON + 15, 300)).floor()
		draw_rect(Rect2(tuft, Vector2(1, 2)), Color("3b4732"))
		draw_rect(Rect2(tuft + Vector2(2, 1), Vector2(1, 1)), Color("3b4732"))


## Sapin en trois étages de triangles.
func _pine(x: float, base_y: float, height: float, color: Color) -> void:
	var width := height * 0.45
	draw_rect(Rect2(x - 2, base_y - height * 0.15, 4, height * 0.15), color)
	for tier in 3:
		var top := base_y - height + tier * height * 0.25
		var bottom := top + height * 0.45
		var half := width * (0.5 + tier * 0.25) / 2
		draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bottom), Vector2(x - half, bottom)]), color)


func _vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


## Cendres et braises qui flottent lentement vers le haut, en continu.
func _make_ash() -> void:
	var ash := CPUParticles2D.new()
	ash.material = FxLibrary.unshaded_material()
	ash.position = Vector2(320, 300)
	ash.amount = 40
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(380, 60)
	ash.direction = Vector2(0.3, -1)
	ash.spread = 25.0
	ash.gravity = Vector2.ZERO
	ash.initial_velocity_min = 6.0
	ash.initial_velocity_max = 16.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1.8, 0.8, 0.3, 0.0), Color(1.8, 0.8, 0.3, 0.8), Color(0.6, 0.55, 0.5, 0.5), Color(0.5, 0.5, 0.5, 0.0)])
	ash.color_ramp = ramp
	add_child(ash)
