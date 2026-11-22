class_name DamagePopup
extends Label
## Nombre qui s'envole au-dessus d'un combattant (dégâts, soins, PA...).


## À appeler avant d'ajouter le popup à la scène.
func setup(text_value: String, color: Color, at: Vector2) -> void:
	text = text_value
	size = Vector2(60, 16)
	position = at - Vector2(size.x / 2, size.y)
	z_index = 100
	material = FxLibrary.unshaded_material()
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)


func _ready() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 24, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tween.chain().tween_callback(queue_free)
