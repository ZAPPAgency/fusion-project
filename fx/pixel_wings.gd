class_name PixelWings
extends RefCounted
## Ailes en pixel art, dessinées pixel par pixel dans une petite image (une aile droite ;
## l'aile gauche est la même retournée). 8 images forment un battement d'ailes.
##
## Forme : un « bras » part de l'épaule, monte puis redescend vers la pointe ; des plumes
## pendent le long du bras (de plus en plus longues vers la pointe), recouvertes de petites
## plumes de couverture. Chaque pixel prend la couleur de la plume du dessus, avec une ombre
## sur un côté de la plume, puis un contour sombre et un liseré clair sur le haut.
##
## Styles : lumière (ailes d'ange dorées), feu (plumes de flammes qui ondulent),
## foudre (ailes d'énergie translucides parcourues d'éclairs).

const SIZE := Vector2i(42, 38)
const ROOT := Vector2i(3, 25)  ## Pixel de l'image placé sur l'épaule du héros
const FRAMES := 8
const FEATHERS := 9

const PALETTES := {
	HeroStage.AuraElement.LIGHT: {
		"outline": Color("6e5020"), "dark": Color("c9a04e"), "mid": Color("efd892"),
		"light": Color("fff6d8"), "cover": Color("fbeab4"), "rim": Color(1.0, 1.0, 0.95)},
	HeroStage.AuraElement.FIRE: {
		"outline": Color("5c1407"), "dark": Color("b72b0e"), "mid": Color("ea5a1c"),
		"light": Color("ffb43a"), "cover": Color("ff8a2c"), "rim": Color(1.0, 0.92, 0.55)},
	HeroStage.AuraElement.LIGHTNING: {
		"outline": Color(0.55, 0.9, 1.0), "dark": Color(0.12, 0.3, 0.75, 0.35), "mid": Color(0.2, 0.5, 0.95, 0.45),
		"light": Color(0.45, 0.8, 1.0, 0.6), "cover": Color(0.35, 0.7, 1.0, 0.55), "rim": Color(0.9, 0.98, 1.0)},
}

static var _cache := {}  # élément -> Array[Texture2D]


## Les 8 images du battement d'ailes pour cet élément (calculées une seule fois).
static func frames(element: HeroStage.AuraElement) -> Array[Texture2D]:
	if not _cache.has(element):
		var textures: Array[Texture2D] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in FRAMES:
			var flap := sin(TAU * i / FRAMES) * 0.24  # en radians : aile levée puis baissée
			textures.append(ImageTexture.create_from_image(_draw_wing(element, flap, i, rng)))
		_cache[element] = textures
	return _cache[element]


static func _draw_wing(element: HeroStage.AuraElement, flap: float, frame: int, rng: RandomNumberGenerator) -> Image:
	var palette: Dictionary = PALETTES[element]
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	# Plumes : [point d'attache, direction, longueur, largeur, est une couverture]
	var feathers: Array[Dictionary] = []
	for layer in [false, true]:  # d'abord les grandes plumes, puis les couvertures par-dessus
		for k in FEATHERS:
			var s := 0.06 + 0.94 * k / (FEATHERS - 1)
			var attach := _arm_point(s, flap)
			var angle := deg_to_rad(lerpf(105.0, 22.0, s)) - flap * 0.7
			var length := lerpf(10.0, 22.0, pow(s, 0.8))
			if element == HeroStage.AuraElement.FIRE:
				# Les plumes de feu ondulent d'une image à l'autre.
				length *= 1.0 + 0.14 * sin(frame * 1.7 + k * 2.3)
			var width := 3.3
			if layer:
				length *= 0.42
				width = 3.8
			feathers.append({"from": attach, "dir": Vector2.from_angle(angle), "length": length, "width": width, "cover": layer})

	for y in SIZE.y:
		for x in SIZE.x:
			var color := _pixel_color(Vector2(x + 0.5, y + 0.5), feathers, palette, element)
			if color.a > 0.0:
				image.set_pixel(x, y, color)
	_add_arm(image, flap, palette)
	_add_outline_and_rim(image, palette)
	if element == HeroStage.AuraElement.LIGHTNING:
		_add_bolts(image, feathers, palette, rng)
	return image


## Point du « bras » de l'aile : s = 0 à l'épaule, 1 à la pointe. Le bras monte puis redescend.
static func _arm_point(s: float, flap: float) -> Vector2:
	var local := Vector2(s * 28.0, -17.0 * sin(s * PI * 0.78))
	return Vector2(ROOT) + local.rotated(-flap)


## Couleur du pixel : celle de la dernière plume qui le recouvre (les couvertures sont dessus).
static func _pixel_color(p: Vector2, feathers: Array[Dictionary], palette: Dictionary, element: HeroStage.AuraElement) -> Color:
	var color := Color(0, 0, 0, 0)
	for feather in feathers:
		var offset: Vector2 = p - feather.from
		var along: float = offset.dot(feather.dir) / feather.length
		if along < 0.0 or along > 1.0:
			continue
		var across: float = feather.dir.cross(offset)
		var half_width: float = feather.width * sqrt(1.0 - along)  # plume pointue
		if absf(across) > half_width:
			continue
		var shaded := across > half_width * 0.25  # le bas de la plume est dans l'ombre
		if feather.cover:
			color = palette.cover if not shaded else palette.mid
		elif element == HeroStage.AuraElement.FIRE:
			# Plumes de feu : rouge sombre à la base, jaune vif au bout.
			color = palette.dark if along < 0.35 else (palette.mid if along < 0.65 else palette.light)
			if shaded and along < 0.65:
				color = color.darkened(0.2)
		else:
			color = palette.light if along > 0.82 else (palette.dark if shaded else palette.mid)
	return color


## Os de l'aile : une ligne claire le long du haut.
static func _add_arm(image: Image, flap: float, palette: Dictionary) -> void:
	for i in 60:
		var point := _arm_point(i / 59.0 * 0.9, flap)
		var pixel := Vector2i(point.floor())
		if Rect2i(Vector2i.ZERO, SIZE).has_point(pixel):
			image.set_pixelv(pixel, palette.cover)


## Contour sombre autour de l'aile, liseré clair sur les pixels du haut.
static func _add_outline_and_rim(image: Image, palette: Dictionary) -> void:
	var source: Image = image.duplicate()
	for y in SIZE.y:
		for x in SIZE.x:
			var filled := source.get_pixel(x, y).a > 0.0
			var up_empty := y == 0 or source.get_pixel(x, y - 1).a == 0.0
			if filled and up_empty:
				image.set_pixel(x, y, palette.rim)
			elif not filled and _touches_filled(source, x, y):
				image.set_pixel(x, y, palette.outline)


static func _touches_filled(image: Image, x: int, y: int) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = Vector2i(x, y) + step
		if Rect2i(Vector2i.ZERO, SIZE).has_point(n) and image.get_pixelv(n).a > 0.0:
			return true
	return false


## Ailes de foudre : quelques éclairs blancs zigzaguent le long des grandes plumes.
static func _add_bolts(image: Image, feathers: Array[Dictionary], palette: Dictionary, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var feather: Dictionary = feathers[rng.randi_range(2, FEATHERS - 1)]
		var point: Vector2 = feather.from
		for step in int(feather.length * 0.9):
			point += feather.dir + Vector2(feather.dir.y, -feather.dir.x) * rng.randf_range(-0.9, 0.9)
			var pixel := Vector2i(point.floor())
			if Rect2i(Vector2i.ZERO, SIZE).has_point(pixel):
				image.set_pixelv(pixel, palette.rim)
