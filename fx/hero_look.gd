class_name HeroLook
extends Node2D
## Apparence d'un héros selon son stade d'évolution (voir HeroStage) :
## - sur le sprite (fx/unit.gdshader) : nouvelles couleurs, armure teintée, contour lumineux ;
## - stade 2 (aura_level 1) : halo doux au sol et étincelles ;
## - forme ultime (aura_level 2) : aura en pixel art liée à l'élément du héros, comme les auras
##   des jeux en ligne : ailes, motif au sol, particules et auréole.
##     lumière (Aldric) : ailes d'ange, cercle de runes, rayons qui montent, auréole dorée ;
##     feu (Ysolde) : deux rubans de feu épais qui montent en s'enroulant autour d'elle
##       (en boucle), braises ;
##     foudre (Fenn) : ailes d'énergie, éclairs qui crépitent, anneau électrique.
## Ce nœud se place derrière le sprite ; `front` (devant le sprite) dessine ce qui passe
## devant le corps. Utiliser HeroLook.attach(). L'origine est aux pieds du héros.
## Tout est dessiné sur des pixels entiers pour rester en pixel art.

const LIGHT_GOLD := Color(1.0, 0.86, 0.45)
const LIGHT_WHITE := Color(1.25, 1.2, 1.0)  # > 1 : brille un peu avec le glow
const FIRE_RAMP := [Color(1.5, 1.35, 0.8), Color(1.25, 0.72, 0.2), Color(0.95, 0.34, 0.08), Color(0.55, 0.1, 0.03, 0.75)]
## Spirale de feu : durée d'une montée (s), nombre de tours, part de la hauteur occupée par la traînée.
const SPIRAL_PERIOD := 1.9
const SPIRAL_TURNS := 2.2
const SPIRAL_TRAIL := 0.45
const BOLT_CORE := Color(1.4, 1.6, 1.9)
const BOLT_GLOW := Color(0.35, 0.75, 1.0, 0.45)
const BOLT_DIM := Color(0.15, 0.4, 0.9, 0.45)

var stage: HeroStage
var body_size: Vector2
var front: Node2D  ## Calque devant le sprite

var _time := 0.0
var _glow: Sprite2D
var _soft_color: Color  ## Couleur de l'aura ramenée sous 1 (grandes surfaces sans éblouir)
var _wings: Array[Sprite2D] = []
var _wing_frames: Array[Texture2D] = []
var _motes: Array[Dictionary] = []  # particules : position, vitesse, âge, durée, couleur
var _beams: Array[Dictionary] = []  # rayons de lumière qui montent
var _bolts: Array[PackedVector2Array] = []  # éclairs affichés en ce moment
var _bolt_timer := 0.0
var _spawn_timer := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


## Ajoute l'apparence du stade autour de `sprite` (même parent) : aura derrière, calque devant.
static func attach(sprite: Node2D, hero_stage: HeroStage, hero_body_size: Vector2) -> HeroLook:
	var look := HeroLook.new(hero_stage, hero_body_size)
	var parent := sprite.get_parent()
	parent.add_child(look)
	parent.move_child(look, sprite.get_index())  # derrière le sprite
	parent.add_child(look.front)
	parent.move_child(look.front, sprite.get_index() + 1)  # devant le sprite
	look.tree_exiting.connect(look.front.queue_free)
	return look


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
	front = FrontLayer.new(self)
	if stage:
		var brightest := maxf(stage.aura_color.r, maxf(stage.aura_color.g, stage.aura_color.b))
		_soft_color = stage.aura_color / maxf(brightest, 1.0)
	_noise.frequency = 0.08
	_rng.randomize()


func _ready() -> void:
	if stage == null or stage.aura_level == 0:
		set_process(false)
		return
	material = FxLibrary.unshaded_material()
	front.material = FxLibrary.unshaded_material()
	# Halo doux derrière le corps (additif).
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow = Sprite2D.new()
	_glow.texture = FxLibrary.light_texture()
	_glow.material = additive
	_glow.position = Vector2(0, -body_size.y * 0.5)
	_glow.scale = Vector2.ONE * body_size.y * 1.3 / 128.0
	_glow.modulate = Color(_soft_color, 0.2)
	add_child(_glow)
	if stage.aura_level == 1:
		add_child(_make_sparks())
	elif stage.aura_element != HeroStage.AuraElement.FIRE:  # le feu a ses rubans à la place des ailes
		_make_wings()


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = 0.18 + 0.05 * sin(_time * 2.5)
	if stage.aura_level >= 2:
		_update_wings()
		_update_particles(delta)
	queue_redraw()
	front.queue_redraw()


# --- Ailes ------------------------------------------------------------------------------

func _make_wings() -> void:
	_wing_frames = PixelWings.frames(stage.aura_element)
	var wing_scale := clampf(body_size.y / 50.0, 1.0, 1.2)  # proche de 1 : pixels nets
	for side in [1.0, -1.0]:
		var wing := Sprite2D.new()
		wing.centered = false
		wing.offset = -Vector2(PixelWings.ROOT)
		wing.position = Vector2(side * 2.0, -roundf(body_size.y * 0.62))
		wing.scale = Vector2(side, 1.0) * wing_scale  # l'aile gauche est l'aile droite retournée
		wing.modulate = Color(1.12, 1.12, 1.12)  # les pixels les plus clairs brillent légèrement
		wing.use_parent_material = true  # pas assombries par la nuit
		add_child(wing)
		_wings.append(wing)


func _update_wings() -> void:
	var frame := int(_time * 7.0) % PixelWings.FRAMES
	for wing in _wings:
		wing.texture = _wing_frames[frame]


# --- Particules (pixels) ---------------------------------------------------------------

func _update_particles(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.06
		_spawn_particles()
	for mote in _motes:
		mote.age += delta
		mote.pos += mote.vel * delta
	_motes = _motes.filter(func(mote: Dictionary) -> bool: return mote.age < mote.life)
	for beam in _beams:
		beam.age += delta
	_beams = _beams.filter(func(beam: Dictionary) -> bool: return beam.age < beam.life)
	if stage.aura_element == HeroStage.AuraElement.LIGHTNING:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = _rng.randf_range(0.06, 0.16)
			_new_bolts()


func _spawn_particles() -> void:
	var half_width := body_size.x * 0.6
	match stage.aura_element:
		HeroStage.AuraElement.LIGHT:
			_add_mote(Vector2(_rng.randf_range(-half_width, half_width), _rng.randf_range(-4, 0)),
				Vector2(0, -_rng.randf_range(10, 18)), 1.6, LIGHT_WHITE if _rng.randf() < 0.4 else LIGHT_GOLD)
			if _rng.randf() < 0.25:
				_beams.append({"x": roundf(_rng.randf_range(-half_width, half_width)), "age": 0.0,
					"life": _rng.randf_range(0.8, 1.3), "height": _rng.randf_range(body_size.y * 0.6, body_size.y * 1.1)})
		HeroStage.AuraElement.FIRE:
			# Quelques braises s'échappent de la tête des spirales.
			if _rng.randf() < 0.5:
				var strand := _rng.randi_range(0, 1)
				var head := _spiral_point(strand, _spiral_progress(strand) * _spiral_height())
				_add_mote(head, Vector2(_rng.randf_range(-6, 6), -_rng.randf_range(10, 20)), 0.8, FIRE_RAMP[_rng.randi_range(0, 1)])
		HeroStage.AuraElement.LIGHTNING:
			if _rng.randf() < 0.5:
				_add_mote(Vector2(_rng.randf_range(-half_width, half_width), -_rng.randf_range(0, body_size.y)),
					Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(20, 40), 0.25, BOLT_CORE)


func _add_mote(pos: Vector2, vel: Vector2, life: float, color: Color) -> void:
	_motes.append({"pos": pos, "vel": vel, "age": 0.0, "life": life, "color": color, "big": _rng.randf() < 0.2})


## 1 à 3 éclairs entre deux points d'une ellipse autour du corps, en zigzag.
func _new_bolts() -> void:
	_bolts.clear()
	if _rng.randf() < 0.45:  # des moments sans éclair : le crépitement reste lisible
		return
	var center := Vector2(0, -body_size.y * 0.5)
	var radius := Vector2(body_size.x * 0.75, body_size.y * 0.55)
	for i in _rng.randi_range(1, 2):
		var start_angle := _rng.randf() * TAU
		var end_angle := start_angle + _rng.randf_range(0.6, 1.6)
		var start := center + Vector2(cos(start_angle), sin(start_angle)) * radius
		var end := center + Vector2(cos(end_angle), sin(end_angle)) * radius
		var points := PackedVector2Array([start])
		var normal := (end - start).orthogonal().normalized()
		for step in range(1, 6):
			points.append(start.lerp(end, step / 6.0) + normal * _rng.randf_range(-4.0, 4.0))
		points.append(end)
		_bolts.append(points)


# --- Dessin ------------------------------------------------------------------------------

func _draw() -> void:
	if stage == null or stage.aura_level == 0:
		return
	if stage.aura_level == 1:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, body_size.x * 0.9, Color(_soft_color, 0.14 + 0.04 * sin(_time * 3.0)))
		draw_set_transform(Vector2.ZERO)
		return
	match stage.aura_element:
		HeroStage.AuraElement.LIGHT:
			_draw_rune_ring(self, true)
			_draw_beams(self)
		HeroStage.AuraElement.FIRE:
			_draw_fire_spiral(self, true)
		HeroStage.AuraElement.LIGHTNING:
			_draw_electric_ring(self, true)


## Ce qui passe devant le corps (appelé par le calque `front`).
func draw_front(canvas: CanvasItem) -> void:
	if stage == null or stage.aura_level < 2:
		return
	match stage.aura_element:
		HeroStage.AuraElement.LIGHT:
			_draw_rune_ring(canvas, false)
			_draw_motes(canvas)
			_draw_halo(canvas)
		HeroStage.AuraElement.FIRE:
			_draw_fire_spiral(canvas, false)
			_draw_motes(canvas)
		HeroStage.AuraElement.LIGHTNING:
			_draw_electric_ring(canvas, false)
			_draw_bolts(canvas)
			_draw_motes(canvas)
			_draw_electric_halo(canvas)


static func _pixel(canvas: CanvasItem, at: Vector2, color: Color, size := 1.0) -> void:
	canvas.draw_rect(Rect2(at.floor(), Vector2(size, size)), color)


func _ground_radius() -> Vector2:
	var radius := roundf(body_size.x * 0.85 + 4.0)
	return Vector2(radius, roundf(radius * 0.32))


## Point de l'ellipse au sol ; angle entre 0 et PI = devant (bas de l'ellipse).
func _ground_point(angle: float, scale_factor: float) -> Vector2:
	var radius := _ground_radius() * scale_factor
	return Vector2(cos(angle) * radius.x, sin(angle) * radius.y)


## Lumière : deux cercles de runes en pointillés qui tournent en sens inverse.
func _draw_rune_ring(canvas: CanvasItem, back: bool) -> void:
	for ring in 2:
		var scale_factor := 1.0 if ring == 0 else 0.62
		var direction := 1.0 if ring == 0 else -1.4
		var count := 48 if ring == 0 else 30
		for i in count:
			var angle := TAU * i / count + _time * 0.6 * direction
			if (sin(angle) < 0.0) != back:
				continue
			# Motif de runes : traits de longueurs différentes, quelques trous.
			var pattern := (i + ring * 3) % 6
			if pattern == 5:
				continue
			var color := LIGHT_WHITE if pattern == 0 else Color(LIGHT_GOLD, 0.85)
			_pixel(canvas, _ground_point(angle, scale_factor), color)


## Lumière : fins rayons verticaux qui montent du sol et s'effacent vers le haut.
func _draw_beams(canvas: CanvasItem) -> void:
	for beam in _beams:
		var progress: float = beam.age / beam.life
		var fade := sin(progress * PI)
		var height: float = beam.height * minf(1.0, progress * 2.0)
		for y in int(height):
			var alpha := fade * (1.0 - y / height) * 0.8
			_pixel(canvas, Vector2(beam.x, -y), Color(LIGHT_GOLD, alpha))
			if y % 2 == 0:
				_pixel(canvas, Vector2(beam.x, -y), Color(LIGHT_WHITE, alpha * 0.5))


## Foudre : anneau en pointillés dont des pixels s'allument au hasard.
func _draw_electric_ring(canvas: CanvasItem, back: bool) -> void:
	var count := 44
	var tick := int(_time * 18.0)
	for i in count:
		var angle := TAU * i / count
		if (sin(angle) < 0.0) != back:
			continue
		var lit := hash(i * 31 + tick) % 5 == 0
		_pixel(canvas, _ground_point(angle, 1.0), BOLT_CORE if lit else BOLT_DIM)


func _draw_bolts(canvas: CanvasItem) -> void:
	for bolt in _bolts:
		for i in bolt.size() - 1:
			_pixel_line(canvas, bolt[i], bolt[i + 1])


## Ligne d'éclair pixel par pixel : cœur blanc, halo bleu de part et d'autre.
func _pixel_line(canvas: CanvasItem, from: Vector2, to: Vector2) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y))) + 1
	for step in steps:
		var point := from.lerp(to, float(step) / steps).floor()
		_pixel(canvas, point + Vector2(0, -1), BOLT_GLOW)
		_pixel(canvas, point + Vector2(0, 1), BOLT_GLOW)
		_pixel(canvas, point, BOLT_CORE)


func _draw_motes(canvas: CanvasItem) -> void:
	for mote in _motes:
		var fade: float = 1.0 - mote.age / mote.life
		var wobble := Vector2(sin(mote.age * 6.0 + mote.pos.x) * 1.5, 0)
		var color: Color = mote.color
		color.a *= fade
		_pixel(canvas, mote.pos + wobble, color)
		if mote.big and fade > 0.5:  # petite étoile en croix
			for step in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_pixel(canvas, mote.pos + wobble + step, Color(color, color.a * 0.5))


func _head_center() -> Vector2:
	return Vector2(0, -roundf(body_size.y + 6.0 + sin(_time * 2.0) * 1.5))


## Lumière : auréole en pixels, avec un éclat qui en fait le tour.
func _draw_halo(canvas: CanvasItem) -> void:
	var center := _head_center()
	var sparkle := int(_time * 10.0) % 28
	for i in 28:
		var angle := TAU * i / 28
		var point := center + Vector2(round(cos(angle) * 7.0), round(sin(angle) * 2.0))
		_pixel(canvas, point, LIGHT_WHITE if i == sparkle else LIGHT_GOLD)


## Feu : deux rubans de feu montent en s'enroulant autour du corps, puis repartent d'en bas
## (décalés d'une demi-montée pour que l'effet ne s'arrête jamais).
## Chaque point du ruban est une petite colonne de flamme : bord rouge sombre, cœur jaune-blanc
## en bas, orange puis pointe rouge en haut. La hauteur des pointes vacille (bruit).
## Le ruban est épais à la tête et s'affine vers la queue. Un point est devant le corps
## quand il est sur la moitié avant du cercle.
## Pour que le feu soit irrégulier tout au long de la montée, deux bruits qui dépendent de la
## hauteur et du temps font varier le ruban : épaisseur (renflements et passages fins), trous,
## grandes flammes qui jaillissent, ondulation de la trajectoire et points plus chauds.
func _draw_fire_spiral(canvas: CanvasItem, back: bool) -> void:
	var height := _spiral_height()
	for strand in 2:
		var progress := _spiral_progress(strand)
		# Apparition en bas et extinction en haut : la boucle repart en douceur.
		var fade := minf(1.0, progress * 6.0) * minf(1.0, (1.0 - progress) * 5.0)
		var head := progress * height
		var samples := int(height * SPIRAL_TRAIL * 4.0)
		# De la queue vers la tête : la tête (la plus chaude) est dessinée par-dessus.
		for i in range(samples - 1, -1, -1):
			var behind := float(i) / samples  # 0 = tête du ruban, 1 = bout de la queue
			var y := head - behind * height * SPIRAL_TRAIL
			if y < 0.0:
				continue
			var angle := _spiral_angle(strand, y)
			if (sin(angle) < 0.0) != back:
				continue
			var flicker := (_noise.get_noise_2d(i * 5.0 + strand * 40.0, _time * 90.0) + 1.0) * 0.5
			var shape := _noise.get_noise_2d(y * 2.5 + strand * 100.0, _time * 35.0)  # -1 à 1
			var flare := _noise.get_noise_2d(y * 1.2 + strand * 60.0 + 500.0, _time * 25.0)
			if behind > 0.12 and shape < -0.35:
				continue  # le ruban se déchire par endroits
			var point := _spiral_point(strand, y, 1.0 + flare * 0.18) + Vector2(0, roundf(shape * 2.0))
			# Grandes flammes aux pointes déchiquetées : leur hauteur varie d'une colonne à l'autre.
			var flame_height := maxf(0.0, flare) * 16.0 * (0.4 + flicker)
			# Épaisseur : des renflements parcourent le ruban comme des pulsations (gros puis fin),
			# modulés par le bruit pour ne jamais se répéter à l'identique.
			var pulse := 0.5 + 0.5 * sin(y * 0.32 - _time * 5.0 + strand * 2.0)
			var swell := (0.35 + 1.4 * pulse) * (1.0 + shape * 0.45)
			_draw_flame_column(canvas, point.floor(), behind, flicker, fade, swell, flame_height)


## Une colonne de flamme de 2 pixels de large posée sur le ruban.
## `swell` : épaisseur relative à cet endroit ; `flare` : hauteur en plus d'une grande flamme.
func _draw_flame_column(canvas: CanvasItem, base: Vector2, behind: float, flicker: float, fade: float,
		swell := 1.0, flare := 0.0) -> void:
	var alpha := (1.0 - behind * 0.8) * fade
	var taper := clampf(behind / 0.1, 0.4, 1.0)  # la tête du ruban se termine en pointe
	var thickness := clampf(roundf(lerpf(6.0, 2.5, behind) * taper * swell), 1.0, 10.0)
	var tongue := roundf(thickness * 0.6 + (flicker * 8.0 + flare) * (1.0 - behind))  # pointe au-dessus du ruban
	var bottom := base.y + ceilf(thickness * 0.5)
	var top := base.y - tongue
	var core_top := bottom - maxf(2.0, thickness * 0.8)
	var middle_top := core_top - roundf((core_top - top) * 0.45)
	var hot := behind < 0.35 or swell > 1.3  # la tête et les renflements sont plus chauds
	# Bord sombre autour de la colonne : donne du volume et une silhouette de flamme.
	canvas.draw_rect(Rect2(base.x - 1, top + 1, 4, bottom - top), Color(FIRE_RAMP[3], FIRE_RAMP[3].a * alpha * 0.7))
	canvas.draw_rect(Rect2(base.x, top, 2, middle_top - top), Color(FIRE_RAMP[2 if hot else 3], alpha))
	canvas.draw_rect(Rect2(base.x, middle_top, 2, core_top - middle_top), Color(FIRE_RAMP[1 if hot else 2], alpha))
	canvas.draw_rect(Rect2(base.x, core_top, 2, bottom - core_top), Color(FIRE_RAMP[0 if hot else 1], alpha))


func _spiral_height() -> float:
	return roundf(body_size.y * 1.15)


## Avancement de la montée (0 en bas, 1 en haut) de la traînée `strand`.
func _spiral_progress(strand: int) -> float:
	return fmod(_time / SPIRAL_PERIOD + strand * 0.5, 1.0)


func _spiral_angle(strand: int, y: float) -> float:
	return strand * PI + y / _spiral_height() * TAU * SPIRAL_TURNS


## Point de la spirale à la hauteur `y` : le cercle se resserre un peu en montant.
## `wobble` : écart au cercle (1 = sur le cercle) pour que la trajectoire ondule.
func _spiral_point(strand: int, y: float, wobble := 1.0) -> Vector2:
	var angle := _spiral_angle(strand, y)
	var radius := (body_size.x * 0.7 + 3.0) * lerpf(1.0, 0.7, y / _spiral_height()) * wobble
	return Vector2(cos(angle) * radius, -y + sin(angle) * radius * 0.3)


## Foudre : anneau électrique qui tressaute au-dessus de la tête.
func _draw_electric_halo(canvas: CanvasItem) -> void:
	var center := _head_center()
	var tick := int(_time * 20.0)
	for i in 28:
		var angle := TAU * i / 28
		var jitter := float(hash(i + tick * 7) % 3 - 1)
		var point := center + Vector2(round(cos(angle) * 7.0), round(sin(angle) * 2.0) + jitter)
		_pixel(canvas, point, BOLT_CORE if hash(i * 5 + tick) % 4 == 0 else BOLT_GLOW)


## Stade 2 : étincelles de la couleur de l'aura qui montent autour du corps.
func _make_sparks() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.material = FxLibrary.unshaded_material()
	sparks.amount = 10
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
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(spark, 0.0), Color(spark, 1.0), Color(spark, 0.0)])
	sparks.color_ramp = ramp
	return sparks


## Calque devant le sprite : délègue le dessin à son HeroLook.
class FrontLayer:
	extends Node2D

	var look: HeroLook

	func _init(owner_look: HeroLook) -> void:
		look = owner_look

	func _draw() -> void:
		look.draw_front(self)
