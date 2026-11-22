class_name PixelFire
extends RefCounted
## Brasier pixel art autour d'un héros, dessiné par le shader fx/pixel_fire.gdshader
## (bruit qui monte, découpé en gros pixels et en paliers de couleurs).
## Deux rectangles : le feu entier derrière le héros (`back`) et le bas du feu devant ses pieds
## (`front`). L'origine est aux pieds du héros.

const CELL := 2  ## Taille d'un pixel de feu, en pixels du jeu
const FRONT_PART := 0.1  ## Part du bas du feu qui passe devant les pieds

static var _noise: NoiseTexture2D
static var _palette: GradientTexture1D

var back: ColorRect
var front: ColorRect


## `size` : taille de la zone de feu en pixels du jeu.
func _init(size: Vector2i) -> void:
	var grid := Vector2(size / CELL)
	var seed := randf() * 10.0
	back = _make_rect(Vector2(grid * CELL), grid, 1.0, seed)
	front = _make_rect(Vector2(grid * CELL), grid, FRONT_PART, seed)
	front.modulate.a = 0.6


func _make_rect(size: Vector2, grid: Vector2, front_cut: float, seed: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.position = Vector2(-size.x / 2, -size.y)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://fx/pixel_fire.gdshader")
	material.set_shader_parameter("palette", _get_palette())
	material.set_shader_parameter("noise_tex", _get_noise())
	material.set_shader_parameter("grid", grid)
	material.set_shader_parameter("front_cut", front_cut)
	material.set_shader_parameter("seed", seed)
	rect.material = material
	return rect


## Plus rien à calculer image par image : le shader anime tout seul.
func update(_delta: float) -> void:
	pass


static func _get_noise() -> NoiseTexture2D:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		_noise = NoiseTexture2D.new()
		_noise.noise = noise
		_noise.seamless = true
		_noise.width = 128
		_noise.height = 128
	return _noise


## Palette du feu : transparent, rouge sombre, rouge, orange, jaune, cœur presque blanc.
## Les couleurs les plus chaudes dépassent 1 : elles brillent avec le glow du décor.
static func _get_palette() -> GradientTexture1D:
	if _palette == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
		gradient.colors = PackedColorArray([
			Color(0.35, 0.04, 0.02, 0.0),
			Color(0.6, 0.08, 0.03, 0.45),
			Color(0.9, 0.22, 0.05, 0.7),
			Color(1.0, 0.48, 0.1, 0.8),
			Color(1.05, 0.78, 0.25, 0.88),
			Color(1.25, 1.05, 0.55, 0.95),
		])
		_palette = GradientTexture1D.new()
		_palette.gradient = gradient
		_palette.use_hdr = true
		_palette.width = 64
	return _palette
