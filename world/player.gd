class_name Player
extends CharacterBody2D
## Le joueur sur la carte : déplacement 8 directions, interaction (Espace), caméra qui suit.
## Souris (comme dans Diablo) : clic = aller à cet endroit (chemin autour des obstacles) ;
## bouton maintenu = suivre le curseur ; clic sur un PNJ ou un coffre = y aller et interagir.
## Le personnage affiché est le héros en tête (GameState.leader), avec l'apparence de son stade
## d'évolution. R / bouton Y : le héros suivant prend la tête.

const SPEED := 120.0
const INTERACT_RANGE := 40.0
const HOLD_DELAY := 0.25  ## Bouton gauche maintenu plus longtemps : on suit le curseur
const RADIUS := 7.0
const SHAPE_OFFSET := Vector2(0, -4)  ## Cercle de collision, un peu au-dessus des pieds

var frozen := false  ## Bloqué pendant les transitions
var auto_path: Array[Vector2] = []  ## Points à rejoindre automatiquement (démo, cinématiques)

var _sprite: AnimatedSprite2D
var _camera: Camera2D
var _highlighted: Interactable
var _look: HeroLook
var _bounds: Rect2  ## Limites de la carte (pour le calcul de chemin)
var _navigator: ClickNavigator  ## Créé au premier clic
var _click_path: Array[Vector2] = []
var _click_target: Interactable  ## PNJ ou coffre cliqué : on interagit en arrivant
var _pending_click: Variant = null  ## Clic à traiter pendant _physics_process (requêtes physiques)
var _mouse_held := false
var _held_time := 0.0
var _stuck_time := 0.0
var _hand_cursor := false


func _ready() -> void:
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = SHAPE_OFFSET
	add_child(collision)

	_sprite = AnimatedSprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	refresh_look()

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	add_child(_camera)


## Affiche le héros en tête avec l'apparence de son stade d'évolution
## (appelé aussi après un changement de héros ou une évolution à la forge).
func refresh_look() -> void:
	var leader := GameState.leader()
	var facing := signf(_sprite.scale.x) if _sprite.scale.x != 0.0 else 1.0
	_sprite.sprite_frames = leader.data.sprite_frames
	_sprite.offset = leader.data.sprite_frames.get_meta("feet_offset", Vector2.ZERO)
	_sprite.play(&"idle")
	var stage := leader.stage_data() if leader.stage > 0 else null
	_sprite.material = HeroLook.make_material(stage)
	var size := leader.data.sprite_scale * leader.data.map_scale * (stage.sprite_scale if stage else 1.0)
	_sprite.scale = Vector2(facing, 1.0) * size
	if _look:
		_look.queue_free()
	var body_size: Vector2 = leader.data.sprite_frames.get_meta("body_size", Vector2(20, 40)) * size
	_look = HeroLook.attach(_sprite, stage, body_size)


## Le héros suivant prend la tête, avec un petit nuage de lumière.
func switch_leader() -> void:
	GameState.cycle_leader()
	refresh_look()
	FxLibrary.burst(get_parent(), global_position + Vector2(0, -14), &"arcane", Vector2.UP, 0.8)
	AudioManager.play_cue()
	var size := absf(_sprite.scale.y)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale:y", size * 1.2, 0.06)
	tween.tween_property(_sprite, "scale:y", size, 0.15).set_trans(Tween.TRANS_BACK)


## Empêche la caméra de montrer l'extérieur de la carte.
func set_camera_limits(bounds: Rect2) -> void:
	_bounds = bounds
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	if _pending_click != null:
		_start_click(_pending_click)
		_pending_click = null
	if _mouse_held:
		_held_time += delta
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_mouse_held = false
	var direction := _input_direction()
	velocity = direction * SPEED
	move_and_slide()
	_check_stuck(delta, direction)
	_animate(direction)
	_update_highlight()


func _process(_delta: float) -> void:
	# Curseur en forme de main au-dessus de ce qui est interactif.
	var hovering := _interactable_at(get_global_mouse_position()) != null
	if hovering != _hand_cursor:
		_hand_cursor = hovering
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovering else Input.CURSOR_ARROW)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _input_direction() -> Vector2:
	if _is_blocked():
		return Vector2.ZERO
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys != Vector2.ZERO:  # le clavier reprend la main sur la souris
		_cancel_click()
		return keys
	if not auto_path.is_empty():
		if global_position.distance_to(auto_path[0]) < 4.0:
			auto_path.pop_front()
			GameState.autoplay_step += 1
			return Vector2.ZERO
		return global_position.direction_to(auto_path[0])
	if _mouse_held and _held_time > HOLD_DELAY:
		_cancel_click()
		var to_mouse := get_global_mouse_position() - global_position
		return to_mouse.normalized() if to_mouse.length() > 6.0 else Vector2.ZERO
	return _follow_click_path()


# --- Souris ----------------------------------------------------------------------------

func _start_click(point: Vector2) -> void:
	if _navigator == null:
		_navigator = ClickNavigator.new(_bounds, self, RADIUS, SHAPE_OFFSET)
	_click_target = _interactable_at(point)
	var goal := point if _click_target == null else _click_target.global_position
	_click_path = _navigator.path(global_position, goal)
	_stuck_time = 0.0
	if _click_target == null:
		var marker := ClickMarker.new()
		marker.position = point
		get_parent().add_child(marker)


func _follow_click_path() -> Vector2:
	if _click_target and is_instance_valid(_click_target):
		var distance := global_position.distance_to(_click_target.global_position)
		if distance < INTERACT_RANGE * 0.8 or (_click_path.is_empty() and distance < INTERACT_RANGE):
			var target := _click_target
			_cancel_click()
			target.interact(self)
			return Vector2.ZERO
	if _click_path.is_empty():
		return Vector2.ZERO
	if global_position.distance_to(_click_path[0]) < 3.0:
		_click_path.pop_front()
		if _click_path.is_empty():
			return Vector2.ZERO
	return global_position.direction_to(_click_path[0])


func _cancel_click() -> void:
	_click_path.clear()
	_click_target = null


## Bloqué contre un obstacle (ex. un ennemi qui passe) : on abandonne le trajet.
func _check_stuck(delta: float, direction: Vector2) -> void:
	if direction == Vector2.ZERO or _click_path.is_empty() or get_real_velocity().length() > SPEED * 0.25:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time > 0.4:
		_cancel_click()


## PNJ ou coffre dessiné sous ce point (zone de leur corps, au-dessus de leurs pieds).
func _interactable_at(point: Vector2) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactable"):
		if Rect2(node.global_position + Vector2(-14, -36), Vector2(28, 42)).has_point(point):
			return node
	return null


func _is_blocked() -> bool:
	return frozen or Dialogue.is_open() or SceneRouter.is_busy()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Clic gauche sur la carte : déplacement (le dialogue ouvert garde la priorité).
		if event.pressed and not _is_blocked() and auto_path.is_empty():
			get_viewport().set_input_as_handled()
			_mouse_held = true
			_held_time = 0.0
			_pending_click = get_global_mouse_position()
		elif not event.pressed:
			_mouse_held = false
		return
	if event.is_action_pressed("confirm") and not _is_blocked() and _highlighted:
		get_viewport().set_input_as_handled()
		_highlighted.interact(self)
	elif event.is_action_pressed("switch_leader") and not _is_blocked():
		get_viewport().set_input_as_handled()
		switch_leader()


## Interaction possible avec l'objet le plus proche à portée.
func _update_highlight() -> void:
	var nearest: Interactable = null
	var best := INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		var distance := global_position.distance_to(node.global_position)
		if distance < best:
			best = distance
			nearest = node
	if nearest != _highlighted:
		if _highlighted and is_instance_valid(_highlighted):
			_highlighted.set_highlighted(false)
		_highlighted = nearest
		if _highlighted:
			_highlighted.set_highlighted(true)


func _animate(direction: Vector2) -> void:
	_sprite.play(&"run" if direction != Vector2.ZERO else &"idle")
	if absf(direction.x) > 0.1:
		_sprite.scale.x = signf(direction.x) * absf(_sprite.scale.y)  # garde la taille du stade d'évolution


## Ombre au sol.
func _draw() -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * 11, sin(angle) * 4))
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
