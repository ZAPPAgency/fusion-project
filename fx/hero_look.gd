class_name HeroLook
extends Node2D
## Apparence d'un héros selon son stade d'évolution (voir HeroStage) :
## - sur le sprite (fx/unit.gdshader) : nouvelles couleurs, armure teintée, contour lumineux ;
## - ce nœud, placé derrière le sprite : halo au sol, étincelles qui montent,
##   et au dernier stade des ailes de lumière qui battent et une auréole.
## L'origine du nœud est aux pieds du héros.

var stage: HeroStage
var body_size: Vector2

var _time := 0.0
var _glow: Sprite2D
## Couleur de l'aura ramenée sous 1 : les grandes surfaces (halo, ailes) ne doivent pas
## déclencher le glow du décor, sinon le héros disparaît dans une boule de lumière.
var _soft_color: Color


## Règle les couleurs et le contour du sprite (stage null = apparence d'origine).
static func apply_to_material(material: ShaderMaterial, hero_stage: HeroStage) -> void:
	var has_stage := hero_stage != null
	material.set_shader_parameter("recolor_hue_min", hero_stage.recolor_hue_min if has_stage else 0.0)
	material.set_shader_parameter("recolor_hue_max", hero_stage.recolor_hue_max if has_stage else 0.0)
	material.set_shader_parameter("recolor_hue_target", hero_stage.recolor_hue_target if has_stage else 0.0)
	material.set_shader_parameter("recolor_saturation", hero_stage.recolor_saturation if has_stage else 1.0)
	material.set_shader_parameter("recolor_value", hero_stage.recolor_value if has_stage else 1.0)
	material.set_shader_parameter("metal_tint", hero_stage.metal_tint if has_stage else Color.WHITE)
	material.set_shader_parameter("metal_amount", hero_stage.metal_amount if has_stage else 0.0)
	material.set_shader_parameter("outline_color", hero_stage.outline_color if has_stage else Color(0, 0, 0, 0))


## Nouveau matériau de sprite avec l'apparence du stade (pour les sprites hors combat).
static func make_material(hero_stage: HeroStage) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://fx/unit.gdshader")
	material.set_shader_parameter("flash_amount", 0.0)
	material.set_shader_parameter("dissolve", 0.0)
	apply_to_material(material, hero_stage)
	return material


func _init(hero_stage: HeroStage, hero_body_size: Vector2) -> void:
	stage = hero_stage
	body_size = hero_body_size
	if stage:
		var brightest := maxf(stage.aura_color.r, maxf(stage.aura_color.g, stage.aura_color.b))
		_soft_color = stage.aura_color / maxf(brightest, 1.0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = additive


func _ready() -> void:
	if stage == null or stage.aura_level == 0:
		set_process(false)
		return
	# Halo doux derrière le corps.
	_glow = Sprite2D.new()
	_glow.texture = FxLibrary.light_texture()
	_glow.position = Vector2(0, -body_size.y * 0.5)
	_glow.scale = Vector2.ONE * body_size.y * 1.3 / 128.0
	_glow.modulate = Color(_soft_color, 0.25)
	_glow.use_parent_material = true
	add_child(_glow)
	add_child(_make_sparks())


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = 0.2 + 0.06 * sin(_time * 2.5)
	queue_redraw()


func _draw() -> void:
	if stage == null or stage.aura_level == 0:
		return
	var color := _soft_color
	# Halo au sol.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, body_size.x * 0.9, Color(color, 0.14 + 0.04 * sin(_time * 3.0)))
	draw_set_transform(Vector2.ZERO)
	if stage.aura_level >= 2:
		_draw_wings(color)
		_draw_halo(color)


## Deux ailes de 6 plumes de lumière, qui battent doucement.
func _draw_wings(color: Color) -> void:
	var size := body_size.y / 40.0
	var root := Vector2(0, -body_size.y * 0.62)
	var flap := sin(_time * 2.2) * 0.14
	for side in [-1.0, 1.0]:
		for i in 6:
			var angle := deg_to_rad(40.0 - i * 15.0) + flap * (1.0 - i * 0.12)
			var direction := Vector2(side * cos(angle), -sin(angle))
			var length := (30.0 - absf(i - 1.5) * 3.5) * size
			var across := Vector2(-direction.y, direction.x) * 3.5 * size
			var middle := root + direction * length * 0.55
			var feather := PackedVector2Array([root + direction * 3.0 - across * 0.3, middle + across,
				root + direction * length, middle - across])
			draw_colored_polygon(feather, Color(color, 0.14 + 0.025 * i))
			var core := PackedVector2Array([root + direction * 4.0, middle + across * 0.3,
				root + direction * length * 0.9, middle - across * 0.3])
			draw_colored_polygon(core, Color(color, 0.22))


## Anneau de lumière au-dessus de la tête, qui flotte.
func _draw_halo(color: Color) -> void:
	var center := Vector2(0, -body_size.y - 7.0 + sin(_time * 2.0) * 1.5)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 28, Color(stage.aura_color, 0.9), 2.0)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 28, Color(color, 0.25), 5.0)
	draw_set_transform(Vector2.ZERO)


## Étincelles de la couleur de l'aura qui montent autour du corps.
func _make_sparks() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.use_parent_material = true
	sparks.amount = 10 * stage.aura_level
	sparks.lifetime = 1.4
	sparks.position = Vector2(0, -body_size.y * 0.4)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(body_size.x * 0.55, body_size.y * 0.45)
	sparks.direction = Vector2.UP
	sparks.spread = 15.0
	sparks.gravity = Vector2(0, -25)
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 18.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	var ramp := Gradient.new()
	var spark := _soft_color * 1.4  # à peine au-dessus de 1 : elles brillent sans éblouir
	ramp.colors = PackedColorArray([Color(spark, 0.0), Color(spark, 1.0), Color(spark, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	sparks.color_ramp = ramp
	return sparks
