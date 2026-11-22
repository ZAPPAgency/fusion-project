class_name MapExit
extends Area2D
## Zone de sortie : quand le joueur y entre, il part sur une autre carte.

@export_file("*.tscn") var target_map := ""
@export var target_spawn := ""  ## Nom du point d'arrivée sur la carte de destination
@export var size := Vector2(64, 32)


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not SceneRouter.is_busy():
		body.frozen = true
		SceneRouter.change_map(target_map, target_spawn)
