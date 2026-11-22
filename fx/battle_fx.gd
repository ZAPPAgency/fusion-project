class_name BattleFx
extends Node2D
## Effets visuels du combat :
## - ambiance : glow (bloom), nuit bleutée, lumières chaude (héros) et froide (ennemis) ;
## - impacts : particules + éclair de lumière + tremblement + arrêt sur image (hit-stop) ;
## - effets d'écran : onde de choc, aberration chromatique, vignette.

const AMBIENT := Color(0.62, 0.66, 0.85)  ## Teinte de nuit appliquée à la scène
const SCREEN_SIZE := Vector2(640, 360)
const MOON_ENERGY := 0.45

@export var camera: BattleCamera

var _screen: ShaderMaterial
var _moon_light: PointLight2D
var _hit_stop_end_ms := 0
var _shock_tween: Tween
var _aberration_tween: Tween
var _vignette_tween: Tween


func _ready() -> void:
	_make_environment()
	_make_screen_layer()
	_make_ambient_lights()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if Engine.time_scale != 1.0 and Time.get_ticks_msec() >= _hit_stop_end_ms:
		Engine.time_scale = 1.0


# --- Effets ponctuels ---------------------------------------------------------

## Impact d'un coup : particules du type `preset`, tremblement et arrêt sur image.
## `strength` : 0.8 (coup faible) à 1.5 (coup parfait).
func impact(at: Vector2, preset: StringName, strength := 1.0) -> void:
	FxLibrary.burst(self, at, preset, Vector2.UP, strength)
	shake(0.25 * strength)
	hit_stop(0.04 * strength)


## Parade : gerbe dorée, onde de choc, aberration, arrêt sur image marqué.
func parry(at: Vector2, toward: Vector2) -> void:
	FxLibrary.burst(self, at, &"parry", (toward - at).normalized(), 1.2)
	shockwave(at, 0.03)
	aberration(2.5)
	shake(0.3)
	hit_stop(0.09)


## Coup parfait ou contre-attaque : en plus de l'impact, onde de choc et aberration.
func big_hit(at: Vector2) -> void:
	shockwave(at, 0.025)
	aberration(2.0)


## Un héros est touché : vignette rouge brève.
func hero_hurt() -> void:
	_tween_vignette(Color(0.5, 0.0, 0.0), 0.65)


## Gèle (presque) le temps du jeu pendant `duration` secondes réelles.
func hit_stop(duration: float, time_scale := 0.05) -> void:
	Engine.time_scale = time_scale
	_hit_stop_end_ms = maxi(_hit_stop_end_ms, Time.get_ticks_msec() + int(duration * 1000.0))


func shake(trauma: float) -> void:
	if camera:
		camera.add_trauma(trauma)


func shockwave(world_position: Vector2, strength := 0.03) -> void:
	var screen_position := get_viewport().get_canvas_transform() * world_position
	_screen.set_shader_parameter("shock_center", screen_position / SCREEN_SIZE)
	if _shock_tween:
		_shock_tween.kill()
	_shock_tween = create_tween().set_parallel()
	_shock_tween.tween_method(func(radius: float) -> void: _screen.set_shader_parameter("shock_radius", radius), 0.0, 0.7, 0.45)
	_shock_tween.tween_method(func(value: float) -> void: _screen.set_shader_parameter("shock_strength", value), strength, 0.0, 0.45)


func aberration(pixels: float) -> void:
	if _aberration_tween:
		_aberration_tween.kill()
	_aberration_tween = create_tween()
	_aberration_tween.tween_method(func(value: float) -> void: _screen.set_shader_parameter("aberration", value), pixels, 0.0, 0.3)


## Lance un projectile qui arrivera sur `to` dans `duration` secondes.
func projectile(texture: Texture2D, from: Vector2, to: Vector2, duration: float) -> void:
	var shot := Projectile.new()
	shot.setup(texture, from, to, duration)
	add_child(shot)


# --- Mise en place --------------------------------------------------------------

func _make_environment() -> void:
	FxLibrary.add_night_ambience(self, AMBIENT)


## Calque des effets plein écran : au-dessus du combat, sous l'interface (Hud = calque 2).
func _make_screen_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_screen = ShaderMaterial.new()
	_screen.shader = preload("res://fx/screen_fx.gdshader")
	var rect := ColorRect.new()
	rect.size = SCREEN_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _screen
	layer.add_child(rect)


func _make_ambient_lights() -> void:
	_ambient_light(Vector2(170, 250), Color(1.0, 0.72, 0.45), 0.55, 4.0)  # lueur chaude côté héros
	_moon_light = _ambient_light(Vector2(480, 220), Color(0.55, 0.65, 1.0), MOON_ENERGY, 4.5)  # lune côté ennemis


## Un nuage passe devant la lune (0 = ciel dégagé, 1 = lune cachée) : sa lumière baisse.
func set_moon_cover(cover: float) -> void:
	if _moon_light:
		_moon_light.energy = MOON_ENERGY * (1.0 - cover * 0.45)


func _ambient_light(at: Vector2, color: Color, energy: float, size: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = FxLibrary.light_texture()
	light.position = at
	light.color = color
	light.energy = energy
	light.texture_scale = size
	add_child(light)
	return light


func _tween_vignette(color: Color, amount: float) -> void:
	if _vignette_tween:
		_vignette_tween.kill()
	_screen.set_shader_parameter("vignette_color", color)
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(func(value: float) -> void: _screen.set_shader_parameter("vignette", value), amount, 0.45, 0.5)
	_vignette_tween.tween_callback(func() -> void: _screen.set_shader_parameter("vignette_color", Color.BLACK))
