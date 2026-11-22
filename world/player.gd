class_name Player
extends CharacterBody2D
## Le joueur sur la carte : déplacement 8 directions, interaction (Espace), caméra qui suit.
## Le personnage affiché est le chef de l'équipe (Aldric).

const SPEED := 120.0
const INTERACT_RANGE := 40.0

var frozen := false  ## Bloqué pendant les transitions
var auto_path: Array[Vector2] = []  ## Points à rejoindre automatiquement (démo, cinématiques)

var _sprite: AnimatedSprite2D
var _camera: Camera2D
var _highlighted: Interactable


func _ready() -> void:
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -4)
	add_child(collision)

	var leader := GameState.party[0]
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = leader.sprite_frames
	_sprite.centered = false
	_sprite.offset = leader.sprite_frames.get_meta("feet_offset", Vector2.ZERO)
	_sprite.play(&"idle")
	add_child(_sprite)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	add_child(_camera)


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
		_sprite.scale.x = signf(direction.x)


## Ombre au sol.
func _draw() -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * 11, sin(angle) * 4))
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
