class_name Atmosphere
extends Node2D
## Ambiance « 2D-HD » d'une carte d'exploration, selon le lieu et la qualité des effets :
## - brume qui dérive au ras du sol (sous les personnages, éclairée par les lanternes) ;
## - ombres de nuages qui passent et rayons de lune en biais (au-dessus de tout) ;
## - particules : feuilles portées par le vent, lucioles, poussière, reflets de lune sur l'eau.
##
## Pour rester léger (navigateur, petites machines) :
## - brume, ombres et rayons = un seul shader par calque, sans texture, calculé seulement
##   sur les pixels visibles ; rien n'est redessiné en GDScript à chaque image ;
## - particules CPU en petit nombre, proportionnel à la taille de la carte et plafonné ;
## - qualité basse : pas de shader du tout et un tiers des particules (Settings, touche F3).
## Tout est reconstruit quand la qualité change.

enum Preset { VILLAGE, FOREST, CHAPEL }

const WATER_TILE := Vector2i(8, 0)  ## Case d'eau du tileset (reflets de lune)
const SCREEN_AREA := 640.0 * 360.0
const MAX_PARTICLES := 70  ## Plafond par effet, même sur une grande carte

## Réglages de chaque lieu. Densités par écran (les particules suivent la taille de la carte).
const PRESETS := {
	Preset.VILLAGE: {"mist": 0.16, "mist_color": Color(0.85, 0.9, 1.0), "shadows": 0.2, "shafts": 0.0,
		"leaves": 8, "leaf_colors": [Color("7a5a2a"), Color("4f6a33")], "dust": 0, "sparkles": true},
	Preset.FOREST: {"mist": 0.28, "mist_color": Color(0.72, 0.82, 1.0), "shadows": 0.26, "shafts": 0.14,
		"leaves": 14, "leaf_colors": [Color("2f4a2a"), Color("5a4424")], "dust": 0, "sparkles": true},
	Preset.CHAPEL: {"mist": 0.17, "mist_color": Color(0.78, 0.66, 1.0), "shadows": 0.0, "shafts": 0.12,
		"leaves": 0, "leaf_colors": [], "dust": 18, "sparkles": false},
}

var preset := Preset.VILLAGE
var area: Rect2  ## Rectangle de la carte, en pixels
var ground: TileMapLayer
var fireflies := false


## À appeler une fois, avant l'ajout à la scène.
func setup(map_preset: Preset, map_area: Rect2, map_ground: TileMapLayer, with_fireflies: bool) -> void:
	preset = map_preset
	area = map_area
	ground = map_ground
	fireflies = with_fireflies


func _ready() -> void:
	Settings.quality_changed.connect(_build)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var config: Dictionary = PRESETS[preset]
	var screens := area.get_area() / SCREEN_AREA
	if Settings.quality >= Settings.Quality.MEDIUM:
		_add_ground_mist(config)
		_add_sky_layer(config)
	if config.sparkles:
		_add_water_sparkles()
	if config.leaves > 0:
		_add_leaves(config, int(config.leaves * screens))
	if config.dust > 0:
		_add_dust(int(config.dust * screens))
	if fireflies:
		_add_fireflies(int(area.get_area() / 6000.0))


func _count(amount: int) -> int:
	return Settings.particles(mini(amount, MAX_PARTICLES))


# --- Calques en shader ---------------------------------------------------------------

## Rectangle de toute la carte avec le shader de brume (voir fx/shaders/mist.gdshader).
func _mist_layer(params: Dictionary) -> ShaderRect:
	var layer := ShaderRect.new(area)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://fx/shaders/mist.gdshader")
	shader_material.set_shader_parameter("detailed", Settings.quality == Settings.Quality.HIGH)
	for key in params:
		shader_material.set_shader_parameter(key, params[key])
	layer.material = shader_material
	add_child(layer)
	return layer


## Brume au sol : dessinée juste après le sol, donc sous les personnages et le décor.
func _add_ground_mist(config: Dictionary) -> void:
	if config.mist > 0.0:
		_mist_layer({"mist_density": config.mist, "mist_color": config.mist_color})


## Au-dessus de tout : ombres des nuages et, en qualité haute, rayons de lune.
func _add_sky_layer(config: Dictionary) -> void:
	var shafts: float = config.shafts if Settings.quality == Settings.Quality.HIGH else 0.0
	if config.shadows <= 0.0 and shafts <= 0.0:
		return
	var layer := _mist_layer({"cloud_shadow": config.shadows, "shafts": shafts, "wind": Vector2(5, 2)})
	layer.z_index = 40
	layer.light_mask = 0  # pas éclairé par les lanternes : ce sont des ombres et de la lune


# --- Particules ---------------------------------------------------------------------

## Émetteur qui couvre toute la carte.
func _area_particles(amount: int, lifetime: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = area.get_center()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = area.size / 2
	particles.gravity = Vector2.ZERO
	add_child(particles)
	return particles


static func _fade_ramp(color: Color, peak := 1.0) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(color, 0.0), Color(color, peak), Color(color, peak), Color(color, 0.0)])
	return ramp


## Feuilles et aiguilles emportées par le vent, qui tournoient en traversant la carte.
func _add_leaves(config: Dictionary, amount: int) -> void:
	var leaves := _area_particles(_count(amount), 8.0)
	leaves.z_index = 45
	leaves.direction = Vector2(1, 0.35)
	leaves.spread = 20.0
	leaves.initial_velocity_min = 10.0
	leaves.initial_velocity_max = 22.0
	leaves.tangential_accel_min = -6.0  # trajectoires qui ondulent
	leaves.tangential_accel_max = 6.0
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.angular_velocity_min = -120.0
	leaves.angular_velocity_max = 120.0
	leaves.scale_amount_min = 2.0
	leaves.scale_amount_max = 3.0
	var colors := Gradient.new()
	colors.set_color(0, config.leaf_colors[0])
	colors.set_color(1, config.leaf_colors[1])
	leaves.color_initial_ramp = colors  # chaque feuille a sa couleur entre les deux
	leaves.color_ramp = _fade_ramp(Color.WHITE)


## Lucioles : petites lumières qui flottent et brillent (glow).
func _add_fireflies(amount: int) -> void:
	var flies := _area_particles(_count(amount), 6.0)
	flies.material = FxLibrary.unshaded_material()
	flies.z_index = 50
	flies.direction = Vector2.UP
	flies.spread = 180.0
	flies.initial_velocity_min = 3.0
	flies.initial_velocity_max = 10.0
	flies.color_ramp = _fade_ramp(Color(2.0, 2.6, 0.8))


## Poussière qui flotte lentement dans l'air (chapelle) et accroche la lumière.
func _add_dust(amount: int) -> void:
	var dust := _area_particles(_count(amount), 9.0)
	dust.material = FxLibrary.unshaded_material()
	dust.z_index = 45
	dust.direction = Vector2(0.4, -1)
	dust.spread = 180.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 5.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 0.6, 1.0])
	var pale := Color(1.1, 1.0, 1.3)
	ramp.colors = PackedColorArray([Color(pale, 0.0), Color(pale, 0.35), Color(1.6, 1.5, 1.8, 0.9), Color(pale, 0.35), Color(pale, 0.0)])
	dust.color_ramp = ramp  # chaque grain scintille une fois au milieu de sa vie


## Reflets de lune qui scintillent sur l'eau, à des points pris au hasard dans les cases d'eau.
func _add_water_sparkles() -> void:
	var cells := ground.get_used_cells_by_id(0, WATER_TILE)
	if cells.is_empty():
		return
	var tile_size := Vector2(ground.tile_set.tile_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = cells.size()
	var points := PackedVector2Array()
	for i in mini(cells.size() * 2, 120):
		var cell: Vector2i = cells[rng.randi() % cells.size()]
		points.append((Vector2(cell) + Vector2(rng.randf(), rng.randf())) * tile_size)
	var sparkles := CPUParticles2D.new()
	sparkles.material = FxLibrary.unshaded_material()
	sparkles.amount = _count(clampi(cells.size() / 2, 4, 40))
	sparkles.lifetime = 1.4
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	sparkles.emission_points = points
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 0.0
	sparkles.initial_velocity_max = 2.0
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1.6, 1.7, 2.0, 0.0), Color(1.6, 1.7, 2.0, 0.9), Color(1.6, 1.7, 2.0, 0.0)])
	sparkles.color_ramp = ramp
	add_child(sparkles)


## Rectangle dessiné une seule fois ; tout le mouvement est dans son shader.
class ShaderRect:
	extends Node2D

	var rect: Rect2

	func _init(area_rect: Rect2) -> void:
		rect = area_rect

	func _draw() -> void:
		draw_rect(rect, Color.WHITE)
