class_name CardView
extends Control
## Dessin d'une carte : cadre de la couleur de sa rareté, nom, illustration, étoiles de rang.
## Sans carte, dessine un emplacement vide, ou verrouillé si `locked_level` > 0.
## Les cartes rares et plus ont un reflet brillant qui passe dessus (fx/card_shine.gdshader).

const SIZE := Vector2(72, 100)
const ART_RECT := Rect2(5, 22, 62, 50)
const BACKGROUND := Color(0.09, 0.08, 0.12)
const STAR_GOLD := Color(1.0, 0.82, 0.3)
const STAR_EMPTY := Color(0.3, 0.28, 0.35)
const SHINE_SHADER := preload("res://fx/card_shine.gdshader")

## Illustrations déjà découpées dans les sprites (CardData -> Texture2D).
static var _art_cache := {}

var card: CardInstance
var locked_level := 0  ## > 0 : emplacement verrouillé jusqu'à ce niveau
var dimmed := false  ## Carte grisée (ex. déjà portée par un autre héros)

var _name_label: Label


func _init(card_instance: CardInstance = null, unlock_level := 0) -> void:
	card = card_instance
	locked_level = unlock_level
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_name_label = Label.new()
	_name_label.position = Vector2(4, 3)
	_name_label.size = Vector2(SIZE.x - 8, 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 7)
	_name_label.add_theme_constant_override("line_spacing", -3)
	add_child(_name_label)
	if card and card.data.rarity >= CardData.Rarity.RARE:
		_add_shine()
	refresh()


func refresh() -> void:
	if card:
		_name_label.text = tr(card.data.display_name)
	elif locked_level > 0:
		_name_label.text = tr("CARD_SLOT_LOCKED").format({"level": locked_level})
	else:
		_name_label.text = tr("CARD_SLOT_EMPTY")
	_name_label.modulate = Color(1, 1, 1, 0.5) if card == null or dimmed else Color.WHITE
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SIZE)
	if card == null:
		_draw_empty(rect)
		return
	var color := card.data.rarity_color()
	if dimmed:
		color = color.darkened(0.5)
	draw_rect(rect, color)
	draw_rect(rect.grow(-2), BACKGROUND)
	draw_rect(rect.grow(-3), color.darkened(0.45), false, 1.0)
	# Fond de l'illustration : dégradé vertical de la couleur de rareté.
	for y in int(ART_RECT.size.y):
		var shade := color.darkened(0.55 + 0.35 * y / ART_RECT.size.y)
		draw_rect(Rect2(ART_RECT.position + Vector2(0, y), Vector2(ART_RECT.size.x, 1)), shade)
	var art := art_texture(card.data)
	if art:
		_draw_art(art)
	else:
		_draw_icon(_icon_kind(), ART_RECT.get_center(), color.lightened(0.35))
	draw_rect(ART_RECT, color.darkened(0.2), false, 1.0)
	_draw_stars(Vector2(SIZE.x / 2, 81))
	if card.data.for_hero != &"":
		_draw_hero_mark()
	if dimmed:
		draw_rect(rect, Color(0, 0, 0, 0.45))


func _draw_empty(rect: Rect2) -> void:
	draw_rect(rect, Color(0.05, 0.05, 0.08, 0.7))
	var line := Color(0.45, 0.42, 0.5) if locked_level == 0 else Color(0.28, 0.26, 0.32)
	# Bord en pointillés.
	for x in range(2, int(SIZE.x) - 2, 6):
		draw_rect(Rect2(x, 1, 3, 1), line)
		draw_rect(Rect2(x, SIZE.y - 2, 3, 1), line)
	for y in range(2, int(SIZE.y) - 2, 6):
		draw_rect(Rect2(1, y, 1, 3), line)
		draw_rect(Rect2(SIZE.x - 2, y, 1, 3), line)
	if locked_level > 0:
		_draw_lock(rect.get_center() + Vector2(0, 8), line)


## Illustration agrandie d'un nombre entier de fois (pixels nets), centrée et rognée au cadre.
func _draw_art(art: Texture2D) -> void:
	var art_size := art.get_size()
	var zoom := maxf(1.0, floorf(minf(ART_RECT.size.x / art_size.x, ART_RECT.size.y / art_size.y)))
	var shown := art_size * zoom
	var top_left := ART_RECT.get_center() - shown / 2
	draw_texture_rect(art, Rect2(top_left.round(), shown), false)


## 5 étoiles : pleines jusqu'au rang de la carte.
func _draw_stars(center: Vector2) -> void:
	for i in CardData.MAX_RANK:
		var star_center := center + Vector2((i - 2) * 10, 0)
		_draw_star(star_center, 4.0, STAR_GOLD if i < card.rank else STAR_EMPTY)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2 + i * PI / 5
		var distance := radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * distance)
	draw_colored_polygon(points, color)


## Pastille de la couleur du héros à qui la carte est réservée.
func _draw_hero_mark() -> void:
	var hero_color := Color.WHITE
	var path := "res://data/characters/%s.tres" % card.data.for_hero
	if ResourceLoader.exists(path):
		hero_color = (load(path) as CombatantData).placeholder_color.lightened(0.2)
	var center := Vector2(SIZE.x - 9, ART_RECT.position.y + 5)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)]), hero_color)


func _draw_lock(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-6, -2), Vector2(12, 9)), color)
	draw_arc(center + Vector2(0, -3), 4.0, PI, TAU, 8, color, 2.0)


# --- Icônes des cartes sans illustration -------------------------------------------

func _icon_kind() -> String:
	if card.timing_bonus_ms() > 0:
		return "eye"
	if card.data.passive != CardData.Passive.NONE:
		return "star"
	var best := "attack"
	for stat_name in CardData.STATS:
		# Comparaison en « poids » : 1 point de vitesse vaut bien 5 PV.
		if _stat_weight(stat_name) > _stat_weight(best):
			best = stat_name
	return best


func _stat_weight(stat_name: String) -> float:
	var weights := {"max_hp": 0.2, "attack": 1.0, "defense": 1.0, "speed": 2.5}
	return card.stat(stat_name) * weights[stat_name]


func _draw_icon(kind: String, c: Vector2, color: Color) -> void:
	var dark := color.darkened(0.5)
	match kind:
		"attack":  # épée
			draw_rect(Rect2(c + Vector2(-1, -16), Vector2(3, 22)), color)
			draw_rect(Rect2(c + Vector2(0, -15), Vector2(1, 20)), color.lightened(0.4))
			draw_rect(Rect2(c + Vector2(-7, 6), Vector2(15, 3)), dark)
			draw_rect(Rect2(c + Vector2(-1, 9), Vector2(3, 6)), dark.darkened(0.3))
			draw_rect(Rect2(c + Vector2(-2, 15), Vector2(5, 3)), dark)
		"defense":  # bouclier
			var shield := PackedVector2Array([c + Vector2(-12, -14), c + Vector2(12, -14), c + Vector2(12, 0), c + Vector2(0, 16), c + Vector2(-12, 0)])
			draw_colored_polygon(shield, dark)
			var inner := PackedVector2Array([c + Vector2(-9, -11), c + Vector2(9, -11), c + Vector2(9, -1), c + Vector2(0, 12), c + Vector2(-9, -1)])
			draw_colored_polygon(inner, color)
			draw_rect(Rect2(c + Vector2(-1, -11), Vector2(3, 22)), dark)
		"max_hp":  # cœur
			draw_circle(c + Vector2(-6, -4), 7, color)
			draw_circle(c + Vector2(6, -4), 7, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -2), c + Vector2(13, -2), c + Vector2(0, 14)]), color)
			draw_circle(c + Vector2(-7, -6), 2, color.lightened(0.5))
		"speed":  # chevrons
			for i in 3:
				var x := -12 + i * 9
				draw_colored_polygon(PackedVector2Array([c + Vector2(x, -10), c + Vector2(x + 5, -10), c + Vector2(x + 12, 0), c + Vector2(x + 5, 10), c + Vector2(x, 10), c + Vector2(x + 7, 0)]), color if i == 2 else dark)
		"eye":  # œil
			var eye := PackedVector2Array()
			for i in 16:
				var angle := i * TAU / 16
				eye.append(c + Vector2(cos(angle) * 15, sin(angle) * 8))
			draw_colored_polygon(eye, dark)
			draw_circle(c, 6, color)
			draw_circle(c, 3, BACKGROUND)
			draw_circle(c + Vector2(-2, -2), 1.5, Color.WHITE)
		_:  # étoile
			_draw_star(c, 15.0, color)
			_draw_star(c, 7.0, color.lightened(0.4))


# --- Illustrations ------------------------------------------------------------------

## Illustration de la carte : son dessin, sinon le haut du corps du sprite de `art_source`.
static func art_texture(data: CardData) -> Texture2D:
	if data.art:
		return data.art
	if data.art_source == null or data.art_source.sprite_frames == null:
		return null
	if not _art_cache.has(data.art_source):
		_art_cache[data.art_source] = _portrait(data.art_source.sprite_frames)
	return _art_cache[data.art_source]


## Découpe le buste du personnage dans la première image de son animation de repos.
static func _portrait(frames: SpriteFrames) -> Texture2D:
	var frame := frames.get_frame_texture(&"idle", 0)
	var body := frame.get_image().get_used_rect()
	var width := mini(body.size.x, int(ART_RECT.size.x))
	var height := mini(body.size.y, int(width * ART_RECT.size.y / ART_RECT.size.x))
	var region := Rect2(body.get_center().x - width / 2.0, body.position.y, width, height)
	var portrait := AtlasTexture.new()
	if frame is AtlasTexture:
		portrait.atlas = frame.atlas
		region.position += frame.region.position
	else:
		portrait.atlas = frame
	portrait.region = region
	return portrait


func _add_shine() -> void:
	var shine := ColorRect.new()
	shine.size = SIZE
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHINE_SHADER
	material.set_shader_parameter("rainbow", 1.0 if card.data.rarity >= CardData.Rarity.EPIC else 0.0)
	# Décalage pour que toutes les cartes ne brillent pas en même temps.
	material.set_shader_parameter("phase", fmod(card.uid * 0.37, 1.0))
	shine.material = material
	add_child(shine)
