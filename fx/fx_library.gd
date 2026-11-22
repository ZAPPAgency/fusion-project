class_name FxLibrary
extends RefCounted
## Effets réutilisables : gerbes de particules et éclairs de lumière.
## Les couleurs > 1 brillent grâce au glow (voir BattleFx).

## Préréglages de particules. Chaque compétence choisit le sien (SkillData.impact_fx).
const BURSTS := {
	# Coup physique : étincelles blanches et dorées.
	&"slash": {"amount": 14, "lifetime": 0.35, "speed": [60.0, 150.0], "gravity": 220.0, "spread": 180.0,
		"size": [1.0, 2.0], "colors": [Color(3.0, 2.8, 2.2), Color(2.0, 1.2, 0.4), Color(1.0, 0.4, 0.1, 0.0)], "light": Color(1.0, 0.85, 0.6)},
	# Feu : braises qui montent.
	&"fire": {"amount": 26, "lifetime": 0.7, "speed": [30.0, 110.0], "gravity": -60.0, "spread": 180.0,
		"size": [1.0, 3.0], "colors": [Color(4.0, 2.6, 0.8), Color(2.5, 0.8, 0.1), Color(0.6, 0.1, 0.0, 0.0)], "light": Color(1.0, 0.5, 0.15)},
	# Magie arcanique (Ysolde) : éclats violets.
	&"arcane": {"amount": 22, "lifetime": 0.5, "speed": [40.0, 130.0], "gravity": 0.0, "spread": 180.0,
		"size": [1.0, 2.0], "colors": [Color(2.6, 2.4, 4.0), Color(1.4, 0.6, 2.6), Color(0.4, 0.1, 0.8, 0.0)], "light": Color(0.7, 0.45, 1.0)},
	# Ténèbres (boss, œil) : fumée pourpre et rouge.
	&"dark": {"amount": 20, "lifetime": 0.6, "speed": [20.0, 90.0], "gravity": -20.0, "spread": 180.0,
		"size": [1.0, 3.0], "colors": [Color(2.4, 0.5, 0.8), Color(0.8, 0.1, 0.5), Color(0.2, 0.0, 0.2, 0.0)], "light": Color(0.9, 0.2, 0.5)},
	# Poison (champignon) : spores vertes lentes.
	&"poison": {"amount": 18, "lifetime": 0.9, "speed": [15.0, 60.0], "gravity": -25.0, "spread": 180.0,
		"size": [1.0, 2.0], "colors": [Color(1.2, 2.6, 0.8), Color(0.5, 1.2, 0.2), Color(0.2, 0.4, 0.1, 0.0)], "light": Color(0.5, 1.0, 0.3)},
	# Parade : grosse gerbe dorée.
	&"parry": {"amount": 28, "lifetime": 0.4, "speed": [90.0, 200.0], "gravity": 150.0, "spread": 180.0,
		"size": [1.0, 2.0], "colors": [Color(4.0, 3.4, 1.5), Color(2.5, 1.6, 0.3), Color(1.0, 0.5, 0.0, 0.0)], "light": Color(1.0, 0.8, 0.3)},
	# Esquive : petit nuage de poussière au sol.
	&"dust": {"amount": 10, "lifetime": 0.4, "speed": [15.0, 45.0], "gravity": -10.0, "spread": 70.0,
		"size": [1.0, 2.0], "colors": [Color(0.8, 0.8, 0.85, 0.8), Color(0.5, 0.5, 0.55, 0.0)], "light": Color()},
	# Soin : étincelles vertes qui montent.
	&"heal": {"amount": 16, "lifetime": 0.8, "speed": [15.0, 40.0], "gravity": -50.0, "spread": 60.0,
		"size": [1.0, 2.0], "colors": [Color(1.5, 3.0, 1.5), Color(0.5, 1.5, 0.6, 0.0)], "light": Color(0.4, 1.0, 0.5)},
	# Mort : les créatures de cendre partent en braises et en cendres.
	&"ash": {"amount": 40, "lifetime": 1.3, "speed": [10.0, 50.0], "gravity": -40.0, "spread": 50.0,
		"size": [1.0, 2.0], "colors": [Color(3.0, 1.4, 0.4), Color(0.6, 0.55, 0.5), Color(0.3, 0.3, 0.3, 0.0)], "light": Color(1.0, 0.45, 0.15)},
}

static var _unshaded: CanvasItemMaterial
static var _light_texture: GradientTexture2D


## Matériau qui ignore l'éclairage et l'assombrissement de la scène (popups, particules...).
static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Halo radial blanc → transparent, utilisé par toutes les lumières.
static func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(0.5, 0.0)
		_light_texture.width = 128
		_light_texture.height = 128
	return _light_texture


## Gerbe de particules ponctuelle. `direction` : vers où partent les particules.
static func burst(parent: Node, at: Vector2, preset: StringName, direction := Vector2.UP, scale_factor := 1.0) -> void:
	var config: Dictionary = BURSTS.get(preset, BURSTS[&"slash"])
	var particles := CPUParticles2D.new()
	particles.material = unshaded_material()
	particles.position = at
	particles.z_index = 60
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = int(config.amount * 1.6 * scale_factor)
	particles.lifetime = config.lifetime
	particles.direction = direction
	particles.spread = config.spread
	particles.gravity = Vector2(0, config.gravity)
	particles.initial_velocity_min = config.speed[0] * scale_factor
	particles.initial_velocity_max = config.speed[1] * scale_factor
	particles.damping_min = 40.0
	particles.damping_max = 80.0
	particles.scale_amount_min = config.size[0] + 1.0
	particles.scale_amount_max = config.size[1] + 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0 * scale_factor
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(config.colors)
	particles.color_ramp = ramp
	parent.add_child(particles)
	particles.emitting = true
	particles.get_tree().create_timer(config.lifetime + 0.2).timeout.connect(particles.queue_free)

	if config.light != Color():
		flash_light(parent, at, config.light, 0.8 * scale_factor, 0.7 * scale_factor, 0.25)


## Ambiance de nuit d'une scène : glow (ce qui dépasse 1 rayonne) + teinte générale.
static func add_night_ambience(parent: Node, tint_color: Color) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in 7:
		environment.set_glow_level(level, 1.0 if level in [1, 2, 3] else 0.0)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	parent.add_child(world_environment)

	var night := CanvasModulate.new()
	night.color = tint_color
	parent.add_child(night)


## Coupe ou rétablit le glow de la scène (sinon les lumières « bavent » à travers les menus).
static func set_scene_glow(tree: SceneTree, enabled: bool) -> void:
	for node in tree.root.find_children("*", "WorldEnvironment", true, false):
		node.environment.glow_enabled = enabled


## Couleur du flash d'un sprite touché par ce type d'effet.
static func tint(preset: StringName) -> Color:
	var config: Dictionary = BURSTS.get(preset, BURSTS[&"slash"])
	return config.light if config.light != Color() else Color.WHITE


## Éclair de lumière qui s'éteint progressivement.
static func flash_light(parent: Node, at: Vector2, color: Color, energy := 1.2, size := 1.0, duration := 0.3) -> void:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.position = at
	light.color = color
	light.energy = energy
	light.texture_scale = size
	parent.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "energy", 0.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(light.queue_free)
