extends Node2D
## Décor du combat : la forêt de Brumecendre la nuit, en couches « 2D-HD ».
## Dessiné un peu plus grand que l'écran pour les zooms et tremblements de la caméra.
##
## Du fond vers l'avant : ciel (étoiles qui scintillent, lune, nuages qui passent devant elle
## et baissent sa lumière, étoile filante), sapins lointains, banc de brume, sapins proches,
## brume, rayons de lune, sol (brume basse, lucioles, feuilles, cendres).
## Les couches lointaines bougent moins quand la caméra bouge (parallaxe) : effet de profondeur.
##
## Léger pour les petites machines : les formes sont dessinées une seule fois ; le mouvement
## vient des shaders (brume, rayons), de nœuds qu'on déplace (nuages) et de peu de particules.
## La qualité des effets (Settings, F3) enlève les shaders et réduit les particules.

const AREA := Rect2(-120, -80, 880, 520)
const CENTER := Vector2(320, 180)  ## Centre de l'écran quand la caméra est au repos
const HORIZON := 150.0
const SKY_TOP := Color("080a16")
const SKY_BOTTOM := Color("232a45")
const MOON_POSITION := Vector2(520, 62)
const MOON := Color(1.7, 1.65, 1.5)  # > 1 : la lune brille avec le glow
const FAR_TREES := Color("1a2236")
const MID_TREES := Color("131b24")
const GROUND_TOP := Color("2b3326")
const GROUND_BOTTOM := Color("171c16")
const FOG := Color(0.6, 0.65, 0.8, 0.10)
const CLOUD := Color("252b44")
const CLOUD_RIM := Color("59628a")  # bord éclairé par la lune
## Part du mouvement de la caméra suivie par chaque couche (1 = comme le sol).
const SKY_DEPTH := 0.15
const FAR_DEPTH := 0.45
const MID_DEPTH := 0.75

var _sky: Node2D
var _far: Node2D
var _mid: Node2D
var _rays: Node2D
var _ground: Node2D
var _clouds: Array[Node2D] = []
var _rays_material: ShaderMaterial
var _halo: Sprite2D
var _fx: BattleFx  ## Pour baisser la lumière de la lune quand un nuage passe
var _shooting_timer := 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -10
	_rng.randomize()
	Settings.quality_changed.connect(_build)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_clouds.clear()
	_rays_material = null
	var high := Settings.quality == Settings.Quality.HIGH
	var shaders := Settings.quality >= Settings.Quality.MEDIUM

	_sky = _layer(_draw_sky)
	_sky.add_child(Stars.new(AREA, Settings.quality != Settings.Quality.LOW))
	_add_moon_halo()
	for i in (3 if high else 2):
		_add_cloud(i)

	_far = _layer(_draw_far_trees)
	if shaders:
		_mist_band(_far, Rect2(AREA.position.x, HORIZON - 52, AREA.size.x, 60), 0.5, Vector2(150, 30), Vector2(7, 0))
	else:
		_far.add_child(_flat_rect(Rect2(AREA.position.x, HORIZON - 30, AREA.size.x, 34), FOG))

	_mid = _layer(_draw_mid_trees)
	if shaders:
		_mist_band(_mid, Rect2(AREA.position.x, HORIZON - 20, AREA.size.x, 44), 0.55, Vector2(120, 25), Vector2(11, 0))

	if shaders:
		_rays = _make_rays(0.085 if high else 0.055)

	_ground = _layer(_draw_ground)
	if shaders:
		_mist_band(_ground, Rect2(AREA.position.x, HORIZON + 30, AREA.size.x, 150), 0.17, Vector2(160, 40), Vector2(9, 0))
	else:
		_ground.add_child(_flat_rect(Rect2(AREA.position.x, HORIZON, AREA.size.x, 14), FOG))
	_add_moonlit_clearing()
	_ground.add_child(_make_ash())
	_ground.add_child(_make_fireflies())
	_ground.add_child(_make_leaves())


func _process(delta: float) -> void:
	_follow_camera()
	_move_clouds(delta)
	if Settings.quality != Settings.Quality.LOW:
		_shooting_timer -= delta
		if _shooting_timer <= 0.0:
			_shooting_timer = _rng.randf_range(6.0, 14.0)
			_sky.add_child(ShootingStar.new(Vector2(_rng.randf_range(60, 560), _rng.randf_range(-30, 50))))


# --- Couches ------------------------------------------------------------------------

## Couche dessinée une fois par `painter(canvas)`.
func _layer(painter: Callable) -> Node2D:
	var layer := Painted.new(painter)
	add_child(layer)
	return layer


## Parallaxe : chaque couche suit une part du déplacement de la caméra (tremblements compris).
func _follow_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var moved := camera.get_screen_center_position() - CENTER
	_sky.position = (moved * (1.0 - SKY_DEPTH)).round()
	_far.position = (moved * (1.0 - FAR_DEPTH)).round()
	_mid.position = (moved * (1.0 - MID_DEPTH)).round()
	if _rays:
		_rays.position = _sky.position


func _draw_sky(canvas: CanvasItem) -> void:
	_vertical_gradient(canvas, Rect2(AREA.position, Vector2(AREA.size.x, HORIZON - AREA.position.y)), SKY_TOP, SKY_BOTTOM)
	canvas.draw_circle(MOON_POSITION, 11, MOON)
	# Quelques taches sur la lune, en pixels.
	for spot in [Vector2(-4, -3), Vector2(3, 2), Vector2(-1, 5), Vector2(5, -5)]:
		canvas.draw_rect(Rect2(MOON_POSITION + spot, Vector2(2, 2)), Color(1.25, 1.22, 1.15))


func _draw_far_trees(canvas: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		_pine(canvas, -110 + i * 40 + rng.randf_range(-8, 8), HORIZON + 4, rng.randf_range(50, 80), FAR_TREES)


func _draw_mid_trees(canvas: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 15:
		var x := -100 + i * 60 + rng.randf_range(-12, 12)
		var height := rng.randf_range(80, 115)
		_pine(canvas, x, HORIZON + 10, height, MID_TREES)
		# Liseré de lune sur le côté droit (la lune est à droite).
		_pine_rim(canvas, x, HORIZON + 10, height, Color(0.3, 0.36, 0.5, 0.5))


func _draw_ground(canvas: CanvasItem) -> void:
	_vertical_gradient(canvas, Rect2(AREA.position.x, HORIZON, AREA.size.x, AREA.end.y - HORIZON), GROUND_TOP, GROUND_BOTTOM)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 70:
		var tuft := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(HORIZON + 15, 300)).floor()
		canvas.draw_rect(Rect2(tuft, Vector2(1, 2)), Color("3b4732"))
		canvas.draw_rect(Rect2(tuft + Vector2(2, 1), Vector2(1, 1)), Color("3b4732"))
	# L'horizon se fond dans une bande de brume (pas de ligne nette entre arbres et sol).
	var haze := Color(0.45, 0.5, 0.65, 0.16)
	_vertical_gradient(canvas, Rect2(AREA.position.x, HORIZON - 8, AREA.size.x, 10), Color(haze, 0.0), haze)
	_vertical_gradient(canvas, Rect2(AREA.position.x, HORIZON + 2, AREA.size.x, 26), haze, Color(haze, 0.0))


## Sapin en trois étages de triangles.
func _pine(canvas: CanvasItem, x: float, base_y: float, height: float, color: Color) -> void:
	var width := height * 0.45
	canvas.draw_rect(Rect2(x - 2, base_y - height * 0.15, 4, height * 0.15), color)
	for tier in 3:
		var top := base_y - height + tier * height * 0.25
		var bottom := top + height * 0.45
		var half := width * (0.5 + tier * 0.25) / 2
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bottom), Vector2(x - half, bottom)]), color)


## Bord droit de chaque étage du sapin, un peu plus clair : la lune l'éclaire.
func _pine_rim(canvas: CanvasItem, x: float, base_y: float, height: float, color: Color) -> void:
	var width := height * 0.45
	for tier in 3:
		var top := base_y - height + tier * height * 0.25
		var bottom := top + height * 0.45
		var half := width * (0.5 + tier * 0.25) / 2
		canvas.draw_line(Vector2(x, top), Vector2(x + half, bottom), color, 1.0)


func _vertical_gradient(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	canvas.draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _flat_rect(rect: Rect2, color: Color) -> Node2D:
	return Painted.new(func(canvas: CanvasItem) -> void: canvas.draw_rect(rect, color))


# --- Lune, nuages, rayons ------------------------------------------------------------

## Clairière éclairée par la lune, côté ennemis : halo doux et aplati (pas de bord net).
func _add_moonlit_clearing() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var clearing := Sprite2D.new()
	clearing.texture = FxLibrary.light_texture()
	clearing.material = additive
	clearing.position = Vector2(470, 240)
	clearing.scale = Vector2(3.0, 0.8)
	clearing.modulate = Color(0.35, 0.42, 0.6, 0.22)
	_ground.add_child(clearing)


func _add_moon_halo() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo = Sprite2D.new()
	_halo.texture = FxLibrary.light_texture()
	_halo.material = additive
	_halo.position = MOON_POSITION
	_halo.scale = Vector2.ONE * 0.75
	_halo.modulate = Color(0.55, 0.6, 0.85, 0.35)
	_sky.add_child(_halo)


## Nuage sombre fait de quelques disques, bord éclairé côté lune. Il traverse le ciel en boucle.
func _add_cloud(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + index
	var puffs: Array[Vector3] = []  # x, y, rayon
	var width := rng.randf_range(50, 80)
	for i in 6:
		puffs.append(Vector3(rng.randf_range(-width / 2, width / 2), rng.randf_range(-4, 3), rng.randf_range(7, 13)))
	var cloud := Painted.new(func(canvas: CanvasItem) -> void:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))  # nuages étirés, pas des boules
		for puff in puffs:
			canvas.draw_circle(Vector2(puff.x + 1, puff.y - 2), puff.z, CLOUD_RIM)
		for puff in puffs:
			canvas.draw_circle(Vector2(puff.x - 1, puff.y + 1), puff.z, CLOUD)
		canvas.draw_set_transform(Vector2.ZERO))
	cloud.position = Vector2(AREA.position.x + index * 330 + rng.randf_range(0, 120), rng.randf_range(30, 95))
	cloud.set_meta("speed", rng.randf_range(4.0, 7.0))
	cloud.set_meta("radius", width / 2 + 10)
	_sky.add_child(cloud)
	_clouds.append(cloud)


## Les nuages avancent ; quand l'un passe devant la lune, elle et ses rayons faiblissent.
func _move_clouds(delta: float) -> void:
	var cover := 0.0
	for cloud in _clouds:
		cloud.position.x += cloud.get_meta("speed") * delta
		if cloud.position.x > AREA.end.x + 60:
			cloud.position.x = AREA.position.x - 60
		var distance := cloud.position.distance_to(MOON_POSITION)
		cover = maxf(cover, 1.0 - smoothstep(cloud.get_meta("radius") * 0.4, cloud.get_meta("radius"), distance))
	if _rays_material:
		_rays_material.set_shader_parameter("cover", cover)
	if _halo:
		_halo.modulate.a = 0.35 * (1.0 - cover * 0.7)
	if _fx == null:
		_fx = get_parent().get_node_or_null("Fx") as BattleFx
	if _fx:
		_fx.set_moon_cover(cover)


## Rayons de lune qui descendent en biais sur les arbres et le sol (additifs).
func _make_rays(strength: float) -> Node2D:
	var rays := Painted.new(func(canvas: CanvasItem) -> void: canvas.draw_rect(AREA, Color.WHITE))
	_rays_material = ShaderMaterial.new()
	_rays_material.shader = preload("res://fx/shaders/god_rays.gdshader")
	_rays_material.set_shader_parameter("source", MOON_POSITION)
	_rays_material.set_shader_parameter("strength", strength)
	_rays_material.set_shader_parameter("reach", 330.0)
	rays.material = _rays_material
	add_child(rays)
	return rays


## Bande de brume qui dérive (shader), fondue en haut et en bas.
func _mist_band(layer: Node2D, rect: Rect2, density: float, noise_scale: Vector2, wind: Vector2) -> void:
	var band := Painted.new(func(canvas: CanvasItem) -> void: canvas.draw_rect(Rect2(Vector2.ZERO, rect.size), Color.WHITE))
	band.position = rect.position
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://fx/shaders/mist.gdshader")
	shader_material.set_shader_parameter("mist_density", density)
	shader_material.set_shader_parameter("mist_color", Color(0.7, 0.75, 0.95))
	shader_material.set_shader_parameter("mist_scale", noise_scale)
	shader_material.set_shader_parameter("wind", wind)
	shader_material.set_shader_parameter("detailed", Settings.quality == Settings.Quality.HIGH)
	shader_material.set_shader_parameter("rect_size", rect.size)
	shader_material.set_shader_parameter("fade_top", rect.size.y * 0.45)
	shader_material.set_shader_parameter("fade_bottom", rect.size.y * 0.45)
	band.material = shader_material
	layer.add_child(band)


# --- Particules ---------------------------------------------------------------------

## Cendres et braises qui flottent lentement vers le haut, en continu.
func _make_ash() -> CPUParticles2D:
	var ash := _particles(Settings.particles(40), 9.0, Vector2(320, 300), Vector2(380, 60))
	ash.direction = Vector2(0.3, -1)
	ash.spread = 25.0
	ash.initial_velocity_min = 6.0
	ash.initial_velocity_max = 16.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1.8, 0.8, 0.3, 0.0), Color(1.8, 0.8, 0.3, 0.8), Color(0.6, 0.55, 0.5, 0.5), Color(0.5, 0.5, 0.5, 0.0)])
	ash.color_ramp = ramp
	return ash


## Lucioles dans l'herbe, autour des combattants.
func _make_fireflies() -> CPUParticles2D:
	var flies := _particles(Settings.particles(14), 5.0, Vector2(320, 230), Vector2(340, 60))
	flies.direction = Vector2.UP
	flies.spread = 180.0
	flies.initial_velocity_min = 2.0
	flies.initial_velocity_max = 8.0
	flies.color_ramp = Atmosphere._fade_ramp(Color(2.0, 2.6, 0.8))
	return flies


## Feuilles et aiguilles de pin qui traversent l'écran en tournoyant.
func _make_leaves() -> CPUParticles2D:
	var leaves := _particles(Settings.particles(9), 10.0, Vector2(100, 120), Vector2(320, 120))
	leaves.material = null  # éclairées comme le décor (pas lumineuses)
	leaves.direction = Vector2(1, 0.45)
	leaves.spread = 15.0
	leaves.initial_velocity_min = 14.0
	leaves.initial_velocity_max = 26.0
	leaves.tangential_accel_min = -5.0
	leaves.tangential_accel_max = 5.0
	leaves.angle_max = 360.0
	leaves.angular_velocity_min = -140.0
	leaves.angular_velocity_max = 140.0
	leaves.scale_amount_min = 2.0
	leaves.scale_amount_max = 3.0
	var colors := Gradient.new()
	colors.set_color(0, Color("3d5a32"))
	colors.set_color(1, Color("6b5228"))
	leaves.color_initial_ramp = colors
	leaves.color_ramp = Atmosphere._fade_ramp(Color.WHITE)
	return leaves


func _particles(amount: int, lifetime: float, center: Vector2, extents: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.material = FxLibrary.unshaded_material()
	particles.position = center
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = extents
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.0
	return particles


# --- Petits nœuds de dessin ------------------------------------------------------------

## Nœud dessiné une seule fois par une fonction (pas de redessin à chaque image).
class Painted:
	extends Node2D

	var painter: Callable

	func _init(paint: Callable) -> void:
		painter = paint

	func _draw() -> void:
		painter.call(self)


## Étoiles qui scintillent. Redessinées quelques fois par seconde seulement (pas à chaque image).
class Stars:
	extends Node2D

	const REDRAW_EVERY := 0.12

	var _stars: Array[Vector4] = []  # x, y, éclat, phase
	var _time := 0.0
	var _wait := 0.0

	func _init(area: Rect2, twinkle: bool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 55:
			_stars.append(Vector4(floorf(rng.randf_range(area.position.x, area.end.x)), floorf(rng.randf_range(-60, 115)),
				rng.randf_range(0.3, 0.9), rng.randf() * TAU))
		set_process(twinkle)

	func _process(delta: float) -> void:
		_time += delta
		_wait -= delta
		if _wait <= 0.0:
			_wait = REDRAW_EVERY
			queue_redraw()

	func _draw() -> void:
		for star in _stars:
			var twinkle := 0.65 + 0.35 * sin(_time * (1.5 + star.w) + star.w * 7.0)
			var alpha := star.z * twinkle
			draw_rect(Rect2(star.x, star.y, 1, 1), Color(1, 1, 1, alpha))
			if star.z > 0.8 and twinkle > 0.9:  # les plus brillantes font une petite croix
				for step in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					draw_rect(Rect2(Vector2(star.x, star.y) + step, Vector2.ONE), Color(0.8, 0.85, 1.0, alpha * 0.4))


## Étoile filante : un trait qui file en biais et s'efface en moins d'une seconde.
class ShootingStar:
	extends Node2D

	const DURATION := 0.7
	const TRAVEL := Vector2(-90, 34)

	var _age := 0.0

	func _init(start: Vector2) -> void:
		position = start

	func _process(delta: float) -> void:
		_age += delta
		if _age >= DURATION:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := _age / DURATION
		var head := TRAVEL * progress
		var fade := 1.0 - progress
		for i in 14:  # traînée de pixels de plus en plus pâles
			var point := (head - TRAVEL.normalized() * i * 1.5).floor()
			draw_rect(Rect2(point, Vector2.ONE), Color(1.4, 1.4, 1.6, fade * (1.0 - i / 14.0)))
