extends Node2D
## Introduction d'une nouvelle partie : l'histoire en quelques pages, sur fond de nuit,
## avec la grande cloche qui se fêle, puis la quête (le but du jeu). Ensuite : le village.
## Espace / clic : page suivante. Échap : passer l'histoire (la quête s'affiche quand même).

const STORY := ["INTRO_1", "INTRO_2", "INTRO_3", "INTRO_4"]
const GOALS := ["INTRO_GOAL_1", "INTRO_GOAL_2", "INTRO_GOAL_3", "INTRO_GOAL_4"]
const BELL_CENTER := Vector2(320, 118)
const SKY_TOP := Color("05060f")
const SKY_BOTTOM := Color("1b2038")
const BRONZE := Color("6b4a2a")
const BRONZE_LIGHT := Color("9a6f3e")
const CRACK := Color(3.0, 1.3, 0.35)  # > 1 : la fissure brille avec le glow
## Points de la fissure, du haut vers le bas de la cloche (relatifs au centre).
const CRACK_POINTS := [Vector2(-3, -48), Vector2(4, -36), Vector2(-2, -24), Vector2(7, -12),
	Vector2(1, 0), Vector2(9, 12), Vector2(3, 26), Vector2(12, 40)]

var _page := -1
var _crack := 0.0  # 0 = cloche intacte, 1 = fissure complète
var _time := 0.0
var _text: Label
var _goal_box: PanelContainer  ## La quête (dernière page)
var _footer: Label
var _embers: CPUParticles2D
var _busy := false
var _done := false


func _ready() -> void:
	FxLibrary.add_night_ambience(self, Color(0.75, 0.75, 0.9))
	_embers = _make_embers()
	add_child(_embers)
	_build_ui()
	_next_page()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _done or SceneRouter.is_busy():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		if _page < STORY.size():
			_page = STORY.size() - 1  # on saute à la quête
			_crack = 1.0
			_next_page()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_next_page()


func _next_page() -> void:
	_page += 1
	if _page > STORY.size():
		_done = true
		SceneRouter.transition_to(GameState.START_MAP)
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_text, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(_goal_box, "modulate:a", 0.0, 0.25)
	await tween.finished
	if _page == 1:  # « la cloche a sonné faux » : la fissure s'ouvre
		_crack_the_bell()
	if _page == 2:
		_embers.amount = 60  # les créatures de cendre
	if _page < STORY.size():
		_text.text = tr(STORY[_page])
		_goal_box.hide()
		_text.show()
		_footer.text = tr("INTRO_HINT")
		create_tween().tween_property(_text, "modulate:a", 1.0, 0.6)
	else:
		_text.hide()
		_goal_box.show()
		_footer.text = tr("INTRO_START")
		create_tween().tween_property(_goal_box, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(0.4).timeout
	_busy = false


func _crack_the_bell() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_crack", 1.0, 0.9).set_ease(Tween.EASE_OUT)
	FxLibrary.flash_light(self, BELL_CENTER, Color(1.0, 0.5, 0.2), 2.0, 3.0, 0.8)
	AudioManager.play_parry()
	var shake := create_tween()
	for i in 6:
		shake.tween_property(self, "position", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.04)
	shake.tween_property(self, "position", Vector2.ZERO, 0.05)


# --- Dessin -------------------------------------------------------------------------------

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(-20, -20), Vector2(660, -20), Vector2(660, 380), Vector2(-20, 380)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		var star := Vector2(rng.randf_range(0, 640), rng.randf_range(0, 240)).floor()
		var twinkle := 0.6 + 0.4 * sin(_time * rng.randf_range(1.0, 3.0) + i)
		draw_rect(Rect2(star, Vector2.ONE), Color(1, 1, 1, rng.randf_range(0.2, 0.8) * twinkle))
	draw_circle(Vector2(540, 50), 12, Color(1.6, 1.55, 1.4))
	_draw_bell()


## La grande cloche sur son portique, et sa fissure qui brille et palpite.
func _draw_bell() -> void:
	var c := BELL_CENTER
	# Portique en bois.
	draw_rect(Rect2(c.x - 78, c.y - 70, 8, 150), Color("2b1f17"))
	draw_rect(Rect2(c.x + 70, c.y - 70, 8, 150), Color("2b1f17"))
	draw_rect(Rect2(c.x - 86, c.y - 78, 172, 10), Color("3a2a1e"))
	draw_rect(Rect2(c.x - 2, c.y - 68, 4, 14), Color("1e1712"))
	# Cloche : sommet arrondi, flancs, lèvre évasée.
	var shape := PackedVector2Array([
		Vector2(-22, -54), Vector2(22, -54), Vector2(30, -44), Vector2(34, -20), Vector2(38, 10),
		Vector2(48, 34), Vector2(56, 44), Vector2(-56, 44), Vector2(-48, 34), Vector2(-38, 10),
		Vector2(-34, -20), Vector2(-30, -44)])
	for i in shape.size():
		shape[i] += c
	draw_colored_polygon(shape, BRONZE)
	draw_rect(Rect2(c.x - 26, c.y - 46, 6, 82), BRONZE_LIGHT)  # reflet sur le flanc gauche
	draw_rect(Rect2(c.x - 56, c.y + 40, 112, 4), Color("4a321c"))
	draw_rect(Rect2(c.x - 40, c.y + 4, 80, 3), Color("4a321c"))  # bandeau
	# Fissure : dessinée jusqu'à `_crack`, avec un cœur clair et un halo qui palpite.
	if _crack <= 0.0:
		return
	var pulse := 0.8 + 0.2 * sin(_time * 3.0)
	var count := CRACK_POINTS.size() - 1
	var drawn := _crack * count
	for i in count:
		if i >= drawn:
			break
		var from: Vector2 = c + CRACK_POINTS[i]
		var to: Vector2 = c + CRACK_POINTS[i + 1]
		if i + 1 > drawn:
			to = from.lerp(to, drawn - i)
		draw_line(from, to, Color(1.0, 0.4, 0.1, 0.5 * pulse), 5.0)
		draw_line(from, to, Color(CRACK.r * pulse, CRACK.g * pulse, CRACK.b, 1.0), 2.0)


func _make_embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.material = FxLibrary.unshaded_material()
	embers.position = Vector2(320, 380)
	embers.amount = Settings.particles(25)
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(340, 10)
	embers.direction = Vector2(0.2, -1)
	embers.spread = 20.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 20.0
	embers.initial_velocity_max = 45.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(2.0, 0.8, 0.3, 0.0), Color(2.0, 0.8, 0.3, 0.9), Color(0.6, 0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5, 0.0)])
	embers.color_ramp = ramp
	return embers


# --- Texte -------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.size = Vector2(640, 360)
	layer.add_child(root)
	_text = UiTheme.label("", Color(0.95, 0.92, 0.85), 12)
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 4)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.position = Vector2(70, 222)
	_text.size = Vector2(500, 80)
	_text.modulate.a = 0.0
	root.add_child(_text)

	_goal_box = PanelContainer.new()
	_goal_box.position = Vector2(110, 186)
	_goal_box.custom_minimum_size = Vector2(420, 0)
	_goal_box.modulate.a = 0.0
	_goal_box.hide()
	root.add_child(_goal_box)
	var goals := VBoxContainer.new()
	goals.add_theme_constant_override("separation", 4)
	_goal_box.add_child(goals)
	goals.add_child(UiTheme.label(tr("INTRO_GOAL_TITLE"), UiTheme.GOLD, 13))
	for goal in GOALS:
		var line := UiTheme.label("•  " + tr(goal), Color(0.92, 0.9, 0.85), 10)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(400, 0)
		goals.add_child(line)

	_footer = UiTheme.label("", UiTheme.DIM, 8)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.position = Vector2(20, 336)
	_footer.size = Vector2(600, 14)
	root.add_child(_footer)
