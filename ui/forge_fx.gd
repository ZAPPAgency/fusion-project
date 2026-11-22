class_name ForgeFx
extends Control
## Animations de la forge, jouées par-dessus le menu (plein écran) :
## amélioration (coups de marteau), fusion de doublons (les cartes se percutent),
## recette (les cartes tourbillonnent et fusionnent), évolution d'une carte,
## et la cinématique d'évolution d'un héros.
## Chaque animation est une fonction à attendre (await) ; tout est nettoyé à la fin.

const CENTER := Vector2(320, 165)
const CARD_ZOOM := 2.0
const GOLD := Color(1.0, 0.85, 0.3)

var _shade: ColorRect
var _flash: ColorRect


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade = _rect(Color(0, 0, 0, 0))
	_flash = _rect(Color(1, 1, 1, 0))


# --- Animations ----------------------------------------------------------------------

## Amélioration : trois coups de marteau, puis la carte gagne son étoile.
func play_upgrade(card: CardInstance) -> void:
	await _open()
	var view := _card_view(CardInstance.new(card.data, card.uid, card.rank - 1), CENTER)
	await _pop_in(view)
	for strike in 3:
		await _wait(0.28)
		_hammer(view, 1.0 + strike * 0.3)
	await _wait(0.3)
	view.card = card
	view.refresh()
	_flash_screen(0.6)
	_rays(CENTER, card.data.rarity_color(), 0.9)
	FxLibrary.burst(self, CENTER, &"parry", Vector2.UP, 2.0)
	AudioManager.play_perfect()
	_pulse(view)
	_banner(tr("FORGE_RANK_UP").format({"rank": card.rank}), tr(card.data.display_name))
	await _wait(1.3)
	await _close()


## Deux exemplaires arrivent des côtés, tremblent l'un contre l'autre et n'en font qu'un.
func play_merge(card: CardInstance) -> void:
	await _open()
	var before := CardInstance.new(card.data, card.uid, card.rank - 1)
	var left := _card_view(before, Vector2(-120, CENTER.y))
	var right := _card_view(before, Vector2(760, CENTER.y))
	var tween := create_tween().set_parallel()
	tween.tween_property(left, "position:x", CENTER.x - 90 - CardView.SIZE.x / 2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(right, "position:x", CENTER.x + 90 - CardView.SIZE.x / 2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	AudioManager.play_cue()
	# Elles se rapprochent en tremblant de plus en plus.
	var glow := _light(CENTER, GOLD, 0.0)
	for i in 8:
		var gap := 90.0 * (1.0 - (i + 1) / 8.0)
		var jitter := Vector2(randf_range(-3, 3), randf_range(-3, 3)) * (i / 4.0)
		left.position = Vector2(CENTER.x - gap - CardView.SIZE.x / 2, CENTER.y - CardView.SIZE.y / 2) + jitter
		right.position = Vector2(CENTER.x + gap - CardView.SIZE.x / 2, CENTER.y - CardView.SIZE.y / 2) - jitter
		glow.scale = Vector2.ONE * (0.5 + i * 0.35)
		glow.modulate.a = i / 8.0
		await _wait(0.07)
	right.queue_free()
	left.position = CENTER - CardView.SIZE / 2
	left.card = card
	left.refresh()
	_flash_screen(1.0)
	AudioManager.play_parry()
	AudioManager.play_perfect()
	FxLibrary.burst(self, CENTER, &"parry", Vector2.UP, 2.4)
	_shockwave(CENTER, GOLD)
	_rays(CENTER, card.data.rarity_color(), 1.0)
	_pulse(left)
	_banner(tr("FORGE_RANK_UP").format({"rank": card.rank}), tr(card.data.display_name))
	await _wait(1.4)
	await _close()


## Recette : les ingrédients tourbillonnent vers le centre, éclair, la nouvelle carte se retourne.
## Sans ingrédients (fabrication), la lumière se rassemble seule.
func play_fusion(ingredients: Array[CardInstance], result: CardInstance) -> void:
	await _open()
	var views: Array[CardView] = []
	for i in ingredients.size():
		views.append(_card_view(ingredients[i], CENTER + Vector2(-130 if i == 0 else 130, 0)))
	var glow := _light(CENTER, result.data.rarity_color().lightened(0.3), 0.0)
	var swirl := _swirl(CENTER, result.data.rarity_color().lightened(0.4))
	AudioManager.play_heal()
	var spin := func(t: float) -> void:
		for i in views.size():
			var angle := PI * i + t * TAU * 1.3
			var radius := 130.0 * (1.0 - t)
			views[i].position = CENTER + Vector2(cos(angle), sin(angle) * 0.45) * radius - CardView.SIZE / 2
			views[i].scale = Vector2.ONE * lerpf(CARD_ZOOM, 0.3, t)
			views[i].rotation = t * TAU
		glow.scale = Vector2.ONE * lerpf(0.3, 3.0, t)
		glow.modulate.a = t
	var tween := create_tween()
	tween.tween_method(spin, 0.0, 1.0, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	for view in views:
		view.queue_free()
	swirl.emitting = false
	glow.queue_free()
	_flash_screen(1.0)
	AudioManager.play_parry()
	_shockwave(CENTER, result.data.rarity_color().lightened(0.3))
	await _reveal(result, tr("FORGE_NEW_CARD"))
	await _close()


## Évolution d'une carte : elle s'illumine par à-coups de plus en plus rapides, puis se transforme.
func play_card_evolution(before: CardInstance, after: CardInstance) -> void:
	await _open()
	var view := _card_view(before, CENTER)
	await _pop_in(view)
	var glow := _light(CENTER, after.data.rarity_color().lightened(0.3), 0.0)
	var white := _white_cover(view)
	var duration := 0.45
	for i in 6:
		AudioManager.play_cue()
		var tween := create_tween()
		tween.tween_property(white, "color:a", 0.85, duration * 0.5)
		tween.parallel().tween_property(glow, "scale", Vector2.ONE * (1.0 + i * 0.45), duration * 0.5)
		tween.parallel().tween_property(glow, "modulate:a", 0.25 + i * 0.12, duration * 0.5)
		tween.tween_property(white, "color:a", 0.1, duration * 0.5)
		await tween.finished
		duration *= 0.72
	view.queue_free()
	glow.queue_free()
	_flash_screen(1.0)
	AudioManager.play_parry()
	_shockwave(CENTER, after.data.rarity_color().lightened(0.3))
	await _reveal(after, tr("FORGE_CARD_EVOLVED"))
	await _close()


## Cinématique d'évolution d'un héros : colonne de lumière, énergie qui converge, le héros
## vire au blanc par pulsations, explosion de lumière, et sa nouvelle forme apparaît.
func play_hero_evolution(progress: HeroProgress, old_stage: int) -> void:
	var stage := progress.stage_data()
	var feet := Vector2(320, 262)
	await _open(0.94)
	var pillar := _pillar(feet.x, stage.aura_color)
	var portrait := HeroPortrait.new(progress, 3.0)
	portrait.position = feet
	portrait.refresh(old_stage)
	add_child(portrait)
	var energy := _converging_energy(feet + Vector2(0, -70), stage.aura_color)
	# Pulsations de plus en plus rapides vers le blanc.
	var duration := 0.7
	for i in 7:
		AudioManager.play_cue()
		var tween := create_tween()
		tween.tween_method(portrait.set_flash, 0.0, 0.9, duration * 0.5)
		tween.parallel().tween_property(pillar, "modulate:a", 0.4 + i * 0.08, duration * 0.5)
		tween.tween_method(portrait.set_flash, 0.9, 0.15, duration * 0.5)
		await tween.finished
		duration *= 0.75
	portrait.set_flash(1.0)
	AudioManager.play_death()
	await _wait(0.5)
	energy.emitting = false
	_flash_screen(1.2)
	AudioManager.play_parry()
	AudioManager.play_perfect()
	portrait.refresh()
	portrait.set_flash(1.0)
	var fade := create_tween()
	fade.tween_method(portrait.set_flash, 1.0, 0.0, 0.8)
	_shockwave(feet + Vector2(0, -60), stage.aura_color)
	_rays(feet + Vector2(0, -70), stage.aura_color, 1.6)
	FxLibrary.burst(self, feet + Vector2(0, -60), &"parry", Vector2.UP, 3.0)
	FxLibrary.burst(self, feet + Vector2(0, -60), &"heal", Vector2.UP, 3.0)
	var pillar_fade := create_tween()
	pillar_fade.tween_property(pillar, "modulate:a", 0.25, 1.0)
	await _wait(0.6)
	AudioManager.play_heal()

	var gains: Array[String] = []
	var previous: HeroStage = progress.data.stages[old_stage]
	for stat in [["max_hp", "HP_SHORT"], ["attack", "STAT_ATK"], ["defense", "STAT_DEF"], ["speed", "STAT_SPD"]]:
		var gain: int = stage.get(stat[0]) - previous.get(stat[0])
		if gain != 0:
			gains.append("%+d %s" % [gain, tr(stat[1])])
	var details := "   ".join(gains)
	if stage.skill:
		details += "\n" + tr("FORGE_NEW_SKILL").format({"skill": tr(stage.skill.display_name)})
	_banner(tr("FORGE_HERO_EVOLVED").format({"hero": tr(progress.data.display_name), "title": tr(stage.title)}), details, 282)
	var hint := _label(tr("FORGE_CONTINUE"), Color(0.75, 0.75, 0.8), 8, 344)
	hint.modulate.a = 0.0
	create_tween().tween_property(hint, "modulate:a", 1.0, 0.5).set_delay(1.0)
	await _wait(1.0)
	await _wait_confirm()
	await _close()


# --- Pièces des animations --------------------------------------------------------------

func _open(darkness := 0.8) -> void:
	_shade.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_shade, "color:a", darkness, 0.25)
	await tween.finished


func _close() -> void:
	var tween := create_tween().set_parallel()
	for child in get_children():
		if child != _shade and child != _flash and child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, 0.3)
	tween.tween_property(_shade, "color:a", 0.0, 0.3)
	await tween.finished
	for child in get_children():
		if child != _shade and child != _flash:
			child.queue_free()


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## Carte agrandie centrée sur `center`.
func _card_view(card: CardInstance, center: Vector2) -> CardView:
	var view := CardView.new(card)
	view.pivot_offset = CardView.SIZE / 2
	view.position = center - CardView.SIZE / 2
	view.scale = Vector2.ONE * CARD_ZOOM
	add_child(view)
	return view


func _pop_in(view: Control) -> void:
	view.scale = Vector2.ONE * CARD_ZOOM * 0.6
	view.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(view, "scale", Vector2.ONE * CARD_ZOOM, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "modulate:a", 1.0, 0.2)
	await tween.finished


## Petit rebond de la carte quand elle change.
func _pulse(view: Control) -> void:
	var tween := create_tween()
	tween.tween_property(view, "scale", Vector2.ONE * CARD_ZOOM * 1.12, 0.1)
	tween.tween_property(view, "scale", Vector2.ONE * CARD_ZOOM, 0.25).set_trans(Tween.TRANS_BACK)


## Coup de marteau : la carte tressaute, flash blanc, gerbe d'étincelles.
func _hammer(view: CardView, strength: float) -> void:
	var white := _white_cover(view)
	white.color.a = 0.8
	create_tween().tween_property(white, "color:a", 0.0, 0.2)
	var home := view.position
	var tween := create_tween()
	tween.tween_property(view, "position", home + Vector2(0, 6 * strength), 0.04)
	tween.tween_property(view, "position", home, 0.12).set_trans(Tween.TRANS_BACK)
	FxLibrary.burst(self, CENTER + Vector2(0, 40), &"slash", Vector2.UP, 1.2 * strength)
	AudioManager.play_parry()


## Rectangle blanc posé sur une carte (pour la faire briller), transparent au départ.
func _white_cover(view: CardView) -> ColorRect:
	var white := ColorRect.new()
	white.size = CardView.SIZE
	white.color = Color(1, 1, 1, 0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(white)
	return white


func _flash_screen(strength: float) -> void:
	move_child(_flash, -1)  # toujours par-dessus tout
	_flash.color.a = clampf(strength, 0.0, 1.0)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)


## Halo lumineux additif.
func _light(at: Vector2, color: Color, alpha: float) -> Sprite2D:
	var light := Sprite2D.new()
	light.texture = FxLibrary.light_texture()
	light.position = at
	light.modulate = Color(color, alpha)
	light.material = _additive()
	add_child(light)
	move_child(light, _shade.get_index() + 1)  # derrière les cartes
	return light


func _additive() -> CanvasItemMaterial:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return additive


## La nouvelle carte se retourne au centre, entourée de rayons, avec son nom.
func _reveal(card: CardInstance, title: String) -> void:
	_rays(CENTER, card.data.rarity_color(), 1.2)
	var view := _card_view(card, CENTER)
	view.scale = Vector2(0.0, CARD_ZOOM)
	var tween := create_tween()
	tween.tween_property(view, "scale", Vector2.ONE * CARD_ZOOM * 1.1, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector2.ONE * CARD_ZOOM, 0.15)
	FxLibrary.burst(self, CENTER, &"parry", Vector2.UP, 2.2)
	AudioManager.play_perfect()
	_banner(title, "%s   %s" % [tr(card.data.display_name), tr(CardData.RARITY_NAMES[card.data.rarity])])
	await _wait(1.8)


## Rayons de lumière qui tournent lentement derrière l'objet.
func _rays(at: Vector2, color: Color, strength: float) -> void:
	var rays := LightRays.new()
	rays.position = at
	rays.color = Color(color, 0.0)
	rays.material = _additive()
	add_child(rays)
	move_child(rays, _shade.get_index() + 1)
	var tween := rays.create_tween()
	tween.tween_property(rays, "color:a", 0.55 * strength, 0.25)
	tween.tween_property(rays, "color:a", 0.2 * strength, 1.2)


## Onde de choc : anneau qui s'élargit et s'efface.
func _shockwave(at: Vector2, color: Color) -> void:
	var ring := Shockwave.new()
	ring.position = at
	ring.color = color
	ring.material = _additive()
	add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "radius", 260.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.6)


## Colonne de lumière verticale derrière le héros.
func _pillar(x: float, color: Color) -> Pillar:
	var pillar := Pillar.new()
	pillar.position = Vector2(x, 0)
	pillar.color = color / maxf(1.0, maxf(color.r, maxf(color.g, color.b)))
	pillar.modulate.a = 0.0
	add_child(pillar)
	return pillar


## Énergie qui converge vers le héros depuis un grand cercle.
func _converging_energy(at: Vector2, color: Color) -> CPUParticles2D:
	var energy := CPUParticles2D.new()
	energy.position = at
	energy.material = _additive()
	energy.amount = 70
	energy.lifetime = 0.9
	energy.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	energy.emission_sphere_radius = 150.0
	energy.gravity = Vector2.ZERO
	energy.radial_accel_min = -260.0
	energy.radial_accel_max = -200.0
	energy.scale_amount_min = 1.5
	energy.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(color, 0.0), Color(color, 1.0), Color(Color.WHITE, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	energy.color_ramp = ramp
	add_child(energy)
	return energy


## Particules qui tournent autour du centre pendant une fusion.
func _swirl(at: Vector2, color: Color) -> CPUParticles2D:
	var swirl := CPUParticles2D.new()
	swirl.position = at
	swirl.material = _additive()
	swirl.amount = 60
	swirl.lifetime = 1.0
	swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	swirl.emission_sphere_radius = 110.0
	swirl.gravity = Vector2.ZERO
	swirl.tangential_accel_min = 160.0
	swirl.tangential_accel_max = 220.0
	swirl.radial_accel_min = -140.0
	swirl.radial_accel_max = -90.0
	swirl.scale_amount_min = 1.0
	swirl.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(color, 0.0), Color(color, 1.0), Color(Color.WHITE, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	swirl.color_ramp = ramp
	add_child(swirl)
	return swirl


## Titre doré + ligne de détails, qui apparaissent sous l'animation.
func _banner(title: String, details: String, y := 278) -> void:
	var big := _label(title, GOLD, 16, y)
	var small := _label(details, Color(0.95, 0.92, 0.85), 9, y + 22)
	for label in [big, small]:
		label.modulate.a = 0.0
		create_tween().tween_property(label, "modulate:a", 1.0, 0.3)


func _label(text: String, color: Color, font_size: int, y: float) -> Label:
	var label := UiTheme.label(text, color, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(640, 20)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Attend un appui sur Espace / A (après avoir laissé passer l'appui précédent).
func _wait_confirm() -> void:
	await get_tree().process_frame
	while not (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("confirm")):
		if "--autoplay" in OS.get_cmdline_user_args() or Engine.get_write_movie_path() != "":
			await _wait(1.5)  # démo et enregistrements : on continue tout seul
			return
		await get_tree().process_frame


## Rayons de lumière qui tournent (dessinés en triangles).
class LightRays:
	extends Node2D

	var color := Color.WHITE
	const COUNT := 14
	const LENGTH := 260.0

	func _process(delta: float) -> void:
		rotation += delta * 0.25
		queue_redraw()

	func _draw() -> void:
		for i in COUNT:
			var angle := TAU * i / COUNT
			var half_width := 0.07 if i % 2 == 0 else 0.04
			var tip_a := Vector2.from_angle(angle - half_width) * LENGTH
			var tip_b := Vector2.from_angle(angle + half_width) * LENGTH
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, tip_a, tip_b]),
				Color(color, color.a * (1.0 if i % 2 == 0 else 0.6)))


## Anneau d'onde de choc.
class Shockwave:
	extends Node2D

	var color := Color.WHITE
	var radius := 10.0:
		set(value):
			radius = value
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.8), 6.0)
		draw_arc(Vector2.ZERO, radius * 0.92, 0.0, TAU, 64, Color(color, 0.3), 12.0)


## Colonne de lumière : opaque au centre, transparente sur les bords.
## Le rendu HDR mélange en couleurs linéaires, où un faible alpha se voit beaucoup :
## l'alpha décroît donc au cube vers les bords (bandes fines) pour un fondu doux.
class Pillar:
	extends Node2D

	var color := Color.WHITE
	const HALF_WIDTH := 60.0
	const HEIGHT := 360.0
	const STRIPS := 12

	func _draw() -> void:
		for side in [-1.0, 1.0]:
			for i in STRIPS:
				var x0: float = side * HALF_WIDTH * i / STRIPS
				var x1: float = side * HALF_WIDTH * (i + 1) / STRIPS
				var alpha := 0.6 * pow(1.0 - (i + 0.5) / STRIPS, 3.0)
				draw_rect(Rect2(minf(x0, x1), 0, absf(x1 - x0), HEIGHT), Color(color.lightened(0.3), alpha))
