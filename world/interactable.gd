class_name Interactable
extends StaticBody2D
## Base des objets avec lesquels le joueur peut interagir (PNJ, coffres, cloche...).
## Quand le joueur est assez près, un « ! » doré flotte au-dessus.
## Les classes filles redéfinissent interact().

const PROMPT_HEIGHT := 44.0

var _prompt: Label
var _time := 0.0


func _ready() -> void:
	add_to_group("interactable")
	_prompt = Label.new()
	_prompt.text = "!"
	_prompt.material = FxLibrary.unshaded_material()
	_prompt.add_theme_font_size_override("font_size", 14)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.z_index = 100
	_prompt.hide()
	add_child(_prompt)


func set_highlighted(value: bool) -> void:
	_prompt.visible = value


func _process(delta: float) -> void:
	if _prompt.visible:
		_time += delta
		_prompt.position = Vector2(-3, -PROMPT_HEIGHT - 6 + sin(_time * 6.0) * 2.0)


## Appelé quand le joueur appuie sur Espace à côté. À redéfinir.
func interact(_player: Node2D) -> void:
	pass


func _add_collision(size: Vector2, offset := Vector2.ZERO) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = offset
	add_child(collision)
