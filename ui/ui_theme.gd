class_name UiTheme
extends RefCounted
## Thème commun des menus : panneaux sombres bordés d'or, boutons compacts,
## bouton sélectionné surligné en doré.

const GOLD := Color(1.0, 0.85, 0.3)
const DIM := Color(0.65, 0.65, 0.7)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 10

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.05, 0.09, 0.95)
	panel.border_color = Color(0.55, 0.47, 0.3)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(2)
	panel.set_content_margin_all(8)
	_theme.set_stylebox("panel", "PanelContainer", panel)

	var button := StyleBoxEmpty.new()
	button.set_content_margin_all(2)
	button.content_margin_left = 6
	var focused := StyleBoxFlat.new()
	focused.bg_color = Color(GOLD, 0.2)
	focused.border_color = GOLD
	focused.border_width_left = 2
	focused.set_content_margin_all(2)
	focused.content_margin_left = 6
	for state in ["normal", "pressed", "disabled"]:
		_theme.set_stylebox(state, "Button", button)
	for state in ["hover", "focus"]:
		_theme.set_stylebox(state, "Button", focused)
	_theme.set_color("font_focus_color", "Button", GOLD)
	_theme.set_color("font_hover_color", "Button", GOLD)
	_theme.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	return _theme


static func label(text: String, color := Color.WHITE, font_size := 10) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override("font_color", color)
	result.add_theme_font_size_override("font_size", font_size)
	return result


static func button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var result := Button.new()
	result.text = text
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.disabled = not enabled
	result.pressed.connect(on_pressed)
	return result


## Donne le focus au premier bouton actif de `container`.
static func focus_first(container: Node) -> void:
	for child in container.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
