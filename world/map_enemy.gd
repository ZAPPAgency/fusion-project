class_name MapEnemy
extends CharacterBody2D
## Ennemi visible sur la carte : erre près de son point de départ, poursuit le joueur
## quand il s'approche, et lance le combat au contact. Disparaît une fois vaincu.

@export var encounter_id := ""  ## Identifiant unique (mémorise la victoire)
@export var enemies: Array[CombatantData] = []  ## Le groupe affronté en combat
@export var chase_radius := 110.0  ## 0 = ne poursuit pas (boss)
@export var wander_radius := 40.0
@export var sprite_scale := 1.0

const WANDER_SPEED := 30.0
const CHASE_SPEED := 78.0  ## Plus lent que le joueur : on peut lui échapper
const CONTACT_DISTANCE := 20.0

var _home: Vector2
var _wander_target: Vector2
var _wander_timer := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	if GameState.defeated_encounters.has(encounter_id):
		queue_free()
		return
	_home = position
	_wander_target = position
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -4)
	add_child(collision)
	collision_layer = 0  # les ennemis ne bloquent pas le joueur : le contact lance le combat
	_make_sprite()
	_make_embers()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or Dialogue.is_open() or SceneRouter.is_busy() or GameState.encounters_paused():
		_animate(Vector2.ZERO)
		return

	var to_player := player.global_position - global_position
	if to_player.length() < CONTACT_DISTANCE:
		_start_battle(player)
		return

	var direction := Vector2.ZERO
	var speed := WANDER_SPEED
	if chase_radius > 0.0 and to_player.length() < chase_radius:
		direction = to_player.normalized()
		speed = CHASE_SPEED
	elif chase_radius > 0.0:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(1.5, 3.0)
			_wander_target = _home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * wander_radius
		if position.distance_to(_wander_target) > 4.0:
			direction = position.direction_to(_wander_target)
	velocity = direction * speed
	move_and_slide()
	_animate(direction)


func _start_battle(player: Player) -> void:
	set_physics_process(false)
	player.frozen = true
	AudioManager.play_parry()
	GameState.start_battle(enemies, encounter_id, player.global_position)


func _make_sprite() -> void:
	if enemies.is_empty() or enemies[0].sprite_frames == null:
		return
	var frames := enemies[0].sprite_frames
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.offset = frames.get_meta("feet_offset", Vector2.ZERO)
	_sprite.scale = Vector2(-1, 1) * sprite_scale  # les dessins regardent à droite : on les tourne vers le sud-ouest
	_sprite.play(&"idle")
	add_child(_sprite)


## Braises qui s'échappent des créatures de cendre : on les repère de loin.
func _make_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.material = FxLibrary.unshaded_material()
	embers.position = Vector2(0, -16)
	embers.amount = 8
	embers.lifetime = 1.2
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 10.0
	embers.direction = Vector2.UP
	embers.spread = 30.0
	embers.gravity = Vector2(0, -20)
	embers.initial_velocity_min = 5.0
	embers.initial_velocity_max = 15.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(3.0, 1.2, 0.3), Color(0.8, 0.2, 0.1, 0.0)])
	embers.color_ramp = ramp
	add_child(embers)


func _animate(direction: Vector2) -> void:
	if _sprite == null:
		return
	_sprite.play(&"run" if direction != Vector2.ZERO and _sprite.sprite_frames.has_animation(&"run") else &"idle")
	if absf(direction.x) > 0.1:
		_sprite.scale.x = signf(direction.x) * sprite_scale


func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * 12, sin(angle) * 4))
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
