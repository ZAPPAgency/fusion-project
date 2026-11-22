class_name Player
extends CharacterBody2D
## Le joueur sur la carte : déplacement 8 directions, interaction (Espace), caméra qui suit.
## Le personnage affiché est le héros en tête (GameState.leader), avec l'apparence de son stade
## d'évolution. R / bouton Y : le héros suivant prend la tête.

const SPEED := 120.0
const INTERACT_RANGE := 40.0

var frozen := false  ## Bloqué pendant les transitions
var auto_path: Array[Vector2] = []  ## Points à rejoindre automatiquement (démo, cinématiques)

var _sprite: AnimatedSprite2D
var _camera: Camera2D
var _highlighted: Interactable
var _look: HeroLook


func _ready() -> void:
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -4)
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
	var size := leader.data.sprite_scale * (stage.sprite_scale if stage else 1.0)
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
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	var direction := _input_direction()
	velocity = direction * SPEED
	move_and_slide()
	_animate(direction)
	_update_highlight()


func _input_direction() -> Vector2:
	if _is_blocked():
		return Vector2.ZERO
	if not auto_path.is_empty():
		if global_position.distance_to(auto_path[0]) < 4.0:
			auto_path.pop_front()
			GameState.autoplay_step += 1
			return Vector2.ZERO
		return global_position.direction_to(auto_path[0])
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _is_blocked() -> bool:
	return frozen or Dialogue.is_open() or SceneRouter.is_busy()


func _unhandled_input(event: InputEvent) -> void:
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
