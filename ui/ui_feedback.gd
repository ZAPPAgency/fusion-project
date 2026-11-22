class_name UiFeedback
extends RefCounted
## Petites animations de retour dans les menus (et sélection à la souris) :
## - sélection (flèches) : l'élément fait un petit saut et un « tic » discret ;
## - choix (Espace) : l'élément tremble et s'écrase légèrement.
## On n'anime que l'échelle, la rotation et (pour les cartes) la position dans leur bouton :
## les conteneurs (listes, grilles) ne touchent pas à ces valeurs.

## Branche les animations sur `control`. `visual` est ce qui bouge (par défaut le contrôle lui-même).
## `centered` : grossit depuis le centre (cartes) au lieu du bord gauche (lignes de texte).
static func attach(control: Control, visual: Control = null, centered := false) -> void:
	var target := visual if visual else control
	target.set_meta("feedback_centered", centered)
	control.focus_entered.connect(pop.bind(target))
	if control is BaseButton:
		control.pressed.connect(shake.bind(target))
	# Souris : survoler un élément le sélectionne, comme les flèches.
	control.mouse_entered.connect(func() -> void:
		var disabled: bool = control is BaseButton and control.disabled
		if control.focus_mode != Control.FOCUS_NONE and not disabled and not control.has_focus():
			control.grab_focus())


## Petit saut : grossit un instant puis revient avec un rebond.
static func pop(target: Control) -> void:
	if not target.is_inside_tree():
		return
	_set_pivot(target)
	var tween := _new_tween(target)
	tween.tween_property(target, "scale", Vector2.ONE * 1.07, 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_tick()


## Tremblement : petite rotation de gauche à droite, écrasement puis rebond.
## Les cartes (centrées) bougent aussi un peu sur le côté.
static func shake(target: Control) -> void:
	if not target.is_inside_tree():
		return
	_set_pivot(target)
	var tween := _new_tween(target)
	tween.tween_property(target, "scale", Vector2(1.06, 0.92), 0.05)
	tween.tween_property(target, "scale", Vector2(0.97, 1.05), 0.07)
	tween.tween_property(target, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	var wiggle := target.create_tween()
	for angle in [4.0, -3.5, 2.5, -1.5, 0.0]:
		wiggle.tween_property(target, "rotation_degrees", angle, 0.04)
	if target.get_meta("feedback_centered", false):
		if not target.has_meta("feedback_home"):  # position de repos, mémorisée une fois
			target.set_meta("feedback_home", target.position)
		var home: Vector2 = target.get_meta("feedback_home")
		var jiggle := target.create_tween()
		for offset in [3.0, -3.0, 2.0, -1.0, 0.0]:
			jiggle.tween_property(target, "position:x", home.x + offset, 0.035)


static func _set_pivot(target: Control) -> void:
	var centered: bool = target.get_meta("feedback_centered", false)
	target.pivot_offset = target.size / 2 if centered else Vector2(0, target.size.y / 2)


## Remplace l'animation en cours (évite que deux animations se battent).
static func _new_tween(target: Control) -> Tween:
	if target.has_meta("feedback_tween"):
		var previous: Tween = target.get_meta("feedback_tween")
		if previous and previous.is_valid():
			previous.kill()
	var tween := target.create_tween()
	target.set_meta("feedback_tween", tween)
	return tween
