class_name UnitView
extends Node2D
## Affichage d'un combattant : sprite animé si sa fiche en a un, sinon rectangle coloré.
## L'origine du nœud est aux pieds du personnage.
##
## Animations reconnues (toutes facultatives sauf "idle") :
## idle, run, attack1, attack2, attack3, cast, hurt, death, block (parade), dodge (esquive).

const PLACEHOLDER_SIZE := Vector2(28, 40)
const HP_BAR_SIZE := Vector2(30, 3)
const ANIMATED_STRIKE_AMPLITUDE := 0.3  ## Les vrais sprites ont leur propre élan : léger décalage en plus

var unit: BattleUnit
var home_position: Vector2
var body_size := PLACEHOLDER_SIZE  ## Taille visible, pour placer le nom, le curseur, les popups

var _body: Node2D  # conteneur déplacé, étiré et teinté pendant les animations ; origine aux pieds
var _sprite: AnimatedSprite2D  # null si rectangle provisoire
var _strike_amplitude := 1.0
var _name_label: Label
var _effects: ShaderMaterial  # fx/unit.gdshader : flash et dissolution (null pour un rectangle)

static var _dissolve_noise: NoiseTexture2D

## 1 = regarde vers la droite (héros), -1 = vers la gauche (ennemis).
var facing: float:
	get:
		return -1.0 if unit.is_enemy else 1.0


func setup(battle_unit: BattleUnit, start_position: Vector2) -> void:
	unit = battle_unit
	position = start_position
	home_position = start_position

	_body = Node2D.new()
	add_child(_body)
	material = FxLibrary.unshaded_material()  # la barre de PV reste lisible dans la pénombre
	if unit.data.sprite_frames:
		_make_sprite(unit.data.sprite_frames)
	else:
		_make_placeholder()

	# Le nom des héros est déjà affiché dans les panneaux du bas.
	if unit.is_enemy:
		_name_label = _make_label(unit.display_name, 8)
		_name_label.position = Vector2(-50, -body_size.y - 13)
		_name_label.size = Vector2(100, 12)
		add_child(_name_label)

	unit.hp_changed.connect(func(_hp: int, _max_hp: int) -> void: queue_redraw())
	unit.died.connect(_on_died)


func _make_sprite(frames: SpriteFrames) -> void:
	var scale_factor := unit.data.sprite_scale
	var source_facing := -1.0 if frames.get_meta("faces_left", false) else 1.0
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.offset = frames.get_meta("feet_offset", Vector2.ZERO)
	_sprite.scale = Vector2(facing * source_facing, 1.0) * scale_factor
	_sprite.animation_finished.connect(_on_animation_finished)
	_effects = ShaderMaterial.new()
	_effects.shader = preload("res://fx/unit.gdshader")
	_effects.set_shader_parameter("noise", _noise_texture())
	# Les paramètres doivent exister pour être animés par un Tween.
	_effects.set_shader_parameter("flash_amount", 0.0)
	_effects.set_shader_parameter("dissolve", 0.0)
	_sprite.material = _effects
	_body.add_child(_sprite)
	body_size = frames.get_meta("body_size", PLACEHOLDER_SIZE) * scale_factor
	_strike_amplitude = ANIMATED_STRIKE_AMPLITUDE
	play_anim(&"idle")


func _make_placeholder() -> void:
	var rect := ColorRect.new()
	rect.color = unit.data.placeholder_color
	rect.size = PLACEHOLDER_SIZE
	rect.position = Vector2(-PLACEHOLDER_SIZE.x / 2, -PLACEHOLDER_SIZE.y)
	_body.add_child(rect)
	var initial := _make_label(unit.short_name, 14)
	initial.size = PLACEHOLDER_SIZE
	rect.add_child(initial)


## Barre de PV sous les pieds.
func _draw() -> void:
	if not unit.is_alive():
		return
	var bar := Rect2(Vector2(-HP_BAR_SIZE.x / 2, 3), HP_BAR_SIZE)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.8))
	var ratio := float(unit.hp) / unit.max_hp
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(0.85, 0.2, 0.2))


# --- Animations du sprite -----------------------------------------------------

func has_anim(anim: StringName) -> bool:
	return _sprite != null and _sprite.sprite_frames.has_animation(anim)


func play_anim(anim: StringName) -> void:
	if has_anim(anim):
		_sprite.play(anim)


## L'animation d'attaque à jouer : celle demandée, sinon "attack1", sinon aucune.
func attack_anim(wanted: StringName) -> StringName:
	if has_anim(wanted):
		return wanted
	if has_anim(&"attack1"):
		return &"attack1"
	return &""


## Temps (ms) entre le début d'une animation d'attaque et son image d'impact.
func impact_lead_ms(anim: StringName) -> float:
	if not has_anim(anim):
		return 0.0
	var impact_frames: Dictionary = _sprite.sprite_frames.get_meta("impact_frames", {})
	var fps := _sprite.sprite_frames.get_animation_speed(anim)
	return impact_frames.get(String(anim), 0) * 1000.0 / fps


## Les animations jouées une seule fois reviennent au repos (sauf la mort).
func _on_animation_finished() -> void:
	if unit.is_alive():
		play_anim(&"idle")


# --- Déplacements et actions ---------------------------------------------------

## Court jusqu'à la cible, appelle `on_impact` au moment du coup, puis revient (sans QTE).
func play_melee(target: UnitView, on_impact: Callable) -> void:
	await play_approach(target)
	play_anim(attack_anim(&"attack1"))
	await get_tree().create_timer(impact_lead_ms(attack_anim(&"attack1")) / 1000.0).timeout
	on_impact.call()
	await get_tree().create_timer(0.3).timeout
	await play_return()


## Se place juste devant la cible (avant une séquence de coups).
func play_approach(target: UnitView) -> void:
	var gap := (body_size.x + target.body_size.x) / 2 + 8
	var strike_position := target.home_position + Vector2(target.facing * gap, 0)
	await _run_to(strike_position, 0.3)


func play_return() -> void:
	await _run_to(home_position, 0.3, true)


## Décale le corps vers l'avant (> 0) ou l'arrière (< 0). Piloté par TimingSession.
func set_strike_pose(offset: float) -> void:
	_body.position.x = offset * _strike_amplitude * facing


## Reflet sur l'arme : indice qu'un coup arrive.
func show_cue(size_scale: float) -> void:
	var glint := Glint.new()
	glint.setup(size_scale)
	glint.position = _weapon_point()
	add_child(glint)


## Parade : animation de blocage, flash doré et léger recul.
func play_parry() -> void:
	play_anim(&"block")
	_flash(Color(1.0, 0.8, 0.3), 0.25, 0.6)
	var tween := create_tween()
	tween.tween_property(_body, "position:x", -4 * facing, 0.05)
	tween.tween_property(_body, "position:x", 0.0, 0.15)


## Esquive : bond en arrière, translucide.
func play_dodge() -> void:
	play_anim(&"dodge")
	FxLibrary.burst(get_parent(), position, &"dust", Vector2(-facing, -0.4))
	var tween := create_tween()
	tween.tween_property(_body, "position:x", -16 * facing, 0.08)
	tween.parallel().tween_property(_body, "modulate:a", 0.5, 0.08)
	tween.tween_property(_body, "position:x", 0.0, 0.2)
	tween.parallel().tween_property(_body, "modulate:a", 1.0, 0.2)


## Sort ou objet sur place, puis `on_impact`.
func play_cast(on_impact: Callable) -> void:
	if has_anim(&"cast"):
		play_anim(&"cast")
		await get_tree().create_timer(maxf(impact_lead_ms(&"cast"), 250.0) / 1000.0).timeout
	else:
		var tween := create_tween()
		tween.tween_property(_body, "scale", Vector2(1.2, 0.85), 0.12)
		tween.tween_property(_body, "scale", Vector2(0.9, 1.15), 0.1)
		tween.tween_property(_body, "scale", Vector2.ONE, 0.1)
		await tween.finished
	on_impact.call()
	await get_tree().create_timer(0.35).timeout


## `tint` : couleur du flash (celle de l'élément : feu, magie...).
func show_hit(amount: int, tint := Color.WHITE) -> void:
	_spawn_popup(str(amount), Color.WHITE)
	if unit.is_alive():
		play_anim(&"hurt")
	_flash(tint)
	_shake()


func show_heal(amount: int) -> void:
	_spawn_popup("+%d" % amount, Color(0.45, 1.0, 0.5))
	_flash(Color(0.5, 1.0, 0.6), 0.3, 0.6)
	FxLibrary.burst(get_parent(), center(), &"heal")


## Milieu du corps, en coordonnées de la scène (pour placer les effets).
func center() -> Vector2:
	return position + _body.position + Vector2(0, -body_size.y * 0.5)


## Point de départ d'un projectile (l'arme), en coordonnées de la scène.
func weapon_position() -> Vector2:
	return position + _weapon_point()


## `raise` : décalage vers le haut, pour ne pas chevaucher le nombre de dégâts.
func show_text(text: String, color: Color, raise := 0.0) -> void:
	_spawn_popup(text, color, raise)


## Déplacement en courant. `turn_around` : le personnage se retourne pendant la course.
func _run_to(target_position: Vector2, duration: float, turn_around := false) -> void:
	play_anim(&"run")
	if turn_around and _sprite:
		_sprite.scale.x *= -1
	var tween := create_tween()
	tween.tween_property(self, "position", target_position, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if turn_around and _sprite:
		_sprite.scale.x *= -1
	if unit.is_alive():
		play_anim(&"idle")


## Point où brille le reflet : défini dans sprite.json ("weapon_point"), sinon devant le torse.
func _weapon_point() -> Vector2:
	if _sprite and _sprite.sprite_frames.has_meta("weapon_point"):
		var point: Vector2 = _sprite.sprite_frames.get_meta("weapon_point")
		return Vector2(point.x * facing, point.y) * unit.data.sprite_scale
	return Vector2(facing * (body_size.x / 2 + 3), -body_size.y * 0.7)


## Le sprite vire brièvement à `color` (valeurs vives → brille avec le glow).
func _flash(color := Color.WHITE, duration := 0.2, amount := 1.0) -> void:
	if _effects == null:
		_body.modulate = Color(2.5, 2.5, 2.5)
		create_tween().tween_property(_body, "modulate", Color.WHITE, duration)
		return
	_effects.set_shader_parameter("flash_color", color)
	_effects.set_shader_parameter("flash_amount", amount)
	create_tween().tween_property(_effects, "shader_parameter/flash_amount", 0.0, duration)


func _shake() -> void:
	var tween := create_tween()
	for offset in [3, -3, 2, -1, 0]:
		tween.tween_property(_body, "position:x", float(offset), 0.03)


func _spawn_popup(text: String, color: Color, raise := 0.0) -> void:
	var popup := DamagePopup.new()
	popup.setup(text, color, position + Vector2(0, -body_size.y - 4 - raise))
	get_parent().add_child(popup)


## Mort : animation de mort, puis le corps part en cendres incandescentes.
func _on_died() -> void:
	AudioManager.play_death()
	if _name_label:
		_name_label.hide()
	queue_redraw()  # la barre de PV disparaît aussi
	if _effects == null:
		create_tween().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.2)
		return
	var delay := 0.3
	if has_anim(&"death"):
		play_anim(&"death")
		var frames := _sprite.sprite_frames
		delay = frames.get_frame_count(&"death") / frames.get_animation_speed(&"death")
	await get_tree().create_timer(delay).timeout
	FxLibrary.burst(get_parent(), center(), &"ash")
	var tween := create_tween()
	tween.tween_property(_effects, "shader_parameter/dissolve", 1.0, 1.0)
	tween.tween_callback(hide)


static func _noise_texture() -> NoiseTexture2D:
	if _dissolve_noise == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.08
		_dissolve_noise = NoiseTexture2D.new()
		_dissolve_noise.noise = noise
		_dissolve_noise.width = 64
		_dissolve_noise.height = 64
		_dissolve_noise.seamless = true
		_dissolve_noise.normalize = true
	return _dissolve_noise


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.material = FxLibrary.unshaded_material()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	return label
