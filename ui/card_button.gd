class_name CardButton
extends Button
## Bouton qui affiche une carte (CardView) : un cadre doré l'entoure quand il est sélectionné.
## `focused` est émis quand la carte est sélectionnée, pour afficher ses détails à côté.

signal focused(card: CardInstance)

var view: CardView


func _init(card: CardInstance = null, locked_level := 0) -> void:
	view = CardView.new(card, locked_level)
	view.position = Vector2(2, 2)
	add_child(view)
	custom_minimum_size = CardView.SIZE + Vector2(4, 4)
	focus_mode = Control.FOCUS_ALL
	disabled = locked_level > 0
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.draw_center = false
	outline.set_border_width_all(2)
	outline.border_color = UiTheme.GOLD
	add_theme_stylebox_override("focus", outline)
	focus_entered.connect(func() -> void: focused.emit(view.card))
