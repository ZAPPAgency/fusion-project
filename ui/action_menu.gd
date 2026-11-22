class_name ActionMenu
extends PanelContainer
## Menu d'action d'un héros : Attaque / Compétences / Objets.
## Échap dans un sous-menu revient au menu principal.

## {"kind": "skill", "skill": SkillData} ou {"kind": "item", "item": ItemData}
signal action_chosen(action: Dictionary)

var _list: VBoxContainer
var _hero: BattleUnit
var _in_submenu := false


func _ready() -> void:
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	add_child(_list)
	hide()


func open(hero: BattleUnit) -> void:
	_hero = hero
	show()
	_show_main()


func _show_main() -> void:
	_in_submenu = false
	_clear()
	_add_button(tr("MENU_ATTACK"), _choose.bind({"kind": "skill", "skill": _hero.data.basic_attack}))
	_add_button(tr("MENU_SKILLS"), _show_skills, not _hero.skills.is_empty())
	_add_button(tr("MENU_ITEMS"), _show_items, GameState.has_items())
	_focus_first_enabled()


func _show_skills() -> void:
	_in_submenu = true
	_clear()
	for skill in _hero.skills:
		var text := "%s  (%d %s)" % [tr(skill.display_name), skill.ap_cost, tr("AP_SHORT")]
		_add_button(text, _choose.bind({"kind": "skill", "skill": skill}), _hero.can_pay(skill.ap_cost))
	_focus_first_enabled()


func _show_items() -> void:
	_in_submenu = true
	_clear()
	for item_id in GameState.inventory:
		var count: int = GameState.inventory[item_id]
		if count > 0:
			var item := GameState.item_data(item_id)
			var text := "%s  x%d" % [tr(item.display_name), count]
			_add_button(text, _choose.bind({"kind": "item", "item": item}))
	_focus_first_enabled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _in_submenu and event.is_action_pressed("ui_cancel"):
		_show_main()
		get_viewport().set_input_as_handled()


func _choose(action: Dictionary) -> void:
	hide()
	action_chosen.emit(action)


func _add_button(text: String, on_pressed: Callable, enabled := true) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not enabled
	button.pressed.connect(on_pressed)
	_list.add_child(button)


func _focus_first_enabled() -> void:
	for button: Button in _list.get_children():
		if not button.disabled:
			button.grab_focus()
			return


func _clear() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
