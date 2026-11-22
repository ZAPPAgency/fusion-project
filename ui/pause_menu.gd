class_name PauseMenu
extends CanvasLayer
## Menu de pause (Tab / Start) : équipe, équipement, objets.
## Le jeu est en pause tant que le menu est ouvert. Échap revient en arrière, puis ferme.

signal closed

const SLOT_NAMES := {
	EquipmentData.Slot.WEAPON: "SLOT_WEAPON",
	EquipmentData.Slot.ARMOR: "SLOT_ARMOR",
	EquipmentData.Slot.ACCESSORY: "SLOT_ACCESSORY",
}

var _tabs: VBoxContainer
var _content: VBoxContainer
var _gold: Label
var _back: Callable  ## Que faire sur Échap (revenir en arrière ou fermer)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	FxLibrary.set_scene_glow(get_tree(), false)

	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.size = Vector2(640, 360)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.size = root.size
	root.add_child(shade)

	var left := PanelContainer.new()
	left.position = Vector2(16, 16)
	left.custom_minimum_size = Vector2(130, 328)
	root.add_child(left)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	left_box.add_child(UiTheme.label(tr("MENU_TITLE"), UiTheme.GOLD, 12))
	_tabs = VBoxContainer.new()
	left_box.add_child(_tabs)
	_tabs.add_child(UiTheme.button(tr("MENU_TEAM"), _show_team))
	_tabs.add_child(UiTheme.button(tr("MENU_EQUIPMENT"), _show_equipment_heroes))
	_tabs.add_child(UiTheme.button(tr("MENU_ITEMS"), _show_items))
	_tabs.add_child(UiTheme.button(tr("MENU_CLOSE"), close))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(spacer)
	_gold = UiTheme.label("", UiTheme.GOLD)
	left_box.add_child(_gold)

	var right := PanelContainer.new()
	right.position = Vector2(154, 16)
	right.custom_minimum_size = Vector2(470, 328)
	root.add_child(right)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	right.add_child(_content)

	_show_team()
	_focus_tabs()


func close() -> void:
	get_tree().paused = false
	FxLibrary.set_scene_glow(get_tree(), true)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("menu"):
			close()
		else:
			_back.call()


func _focus_tabs() -> void:
	_back = close
	_refresh_gold()
	UiTheme.focus_first(_tabs)


func _refresh_gold() -> void:
	_gold.text = "%s : %d" % [tr("GOLD"), GameState.gold]


# --- Équipe ---------------------------------------------------------------------

func _show_team() -> void:
	UiTheme.clear(_content)
	for progress in GameState.heroes:
		_content.add_child(_hero_card(progress))
	_focus_tabs()


func _hero_card(progress: HeroProgress) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var xp_text := tr("XP_MAX") if progress.level == HeroProgress.MAX_LEVEL \
		else "%d / %d" % [progress.xp, HeroProgress.xp_to_next(progress.level)]
	box.add_child(UiTheme.label("%s   %s %d   XP %s" % [tr(progress.data.display_name), tr("LEVEL_SHORT"), progress.level, xp_text],
		progress.data.placeholder_color.lightened(0.3), 11))
	box.add_child(UiTheme.label(_stats_text(progress)))
	var gear: Array[String] = []
	for slot in SLOT_NAMES:
		var item := progress.equipped(slot)
		gear.append("%s : %s" % [tr(SLOT_NAMES[slot]), tr(item.display_name) if item else "-"])
	box.add_child(UiTheme.label("   ".join(gear), UiTheme.DIM))
	return box


func _stats_text(progress: HeroProgress) -> String:
	return "%s %d / %d    %s %d    %s %d    %s %d" % [
		tr("HP_SHORT"), progress.hp, progress.max_hp(), tr("STAT_ATK"), progress.attack(),
		tr("STAT_DEF"), progress.defense(), tr("STAT_SPD"), progress.speed()]


# --- Équipement -------------------------------------------------------------------

func _show_equipment_heroes() -> void:
	UiTheme.clear(_content)
	_content.add_child(UiTheme.label(tr("MENU_CHOOSE_HERO"), UiTheme.GOLD))
	for progress in GameState.heroes:
		_content.add_child(UiTheme.button(tr(progress.data.display_name), _show_slots.bind(progress)))
	_back = _focus_tabs
	UiTheme.focus_first(_content)


func _show_slots(progress: HeroProgress) -> void:
	UiTheme.clear(_content)
	_content.add_child(_hero_card(progress))
	for slot in SLOT_NAMES:
		var item := progress.equipped(slot)
		var text := "%s : %s" % [tr(SLOT_NAMES[slot]), tr(item.display_name) if item else "-"]
		if item:
			text += "   (%s)" % item.bonus_text()
		_content.add_child(UiTheme.button(text, _show_choices.bind(progress, slot)))
	_back = _show_equipment_heroes
	UiTheme.focus_first(_content)


func _show_choices(progress: HeroProgress, slot: EquipmentData.Slot) -> void:
	UiTheme.clear(_content)
	_content.add_child(_hero_card(progress))
	_content.add_child(UiTheme.label(tr(SLOT_NAMES[slot]), UiTheme.GOLD))
	for equipment_id in GameState.equipment_bag:
		var item := GameState.equipment_data(equipment_id)
		if item.slot != slot or not item.can_be_used_by(progress.data.id):
			continue
		var text := "%s  x%d   (%s)" % [tr(item.display_name), GameState.equipment_bag[equipment_id], item.bonus_text()]
		_content.add_child(UiTheme.button(text, _equip.bind(progress, slot, item)))
	if progress.equipped(slot):
		_content.add_child(UiTheme.button(tr("MENU_UNEQUIP"), _equip.bind(progress, slot, null)))
	if _content.get_child_count() == 2:
		_content.add_child(UiTheme.label(tr("MENU_NOTHING_TO_EQUIP"), UiTheme.DIM))
	_back = _show_slots.bind(progress)
	UiTheme.focus_first(_content)


func _equip(progress: HeroProgress, slot: EquipmentData.Slot, item: EquipmentData) -> void:
	GameState.equip(progress, slot, item)
	AudioManager.play_cue()
	_show_slots(progress)


# --- Objets -------------------------------------------------------------------------

func _show_items() -> void:
	UiTheme.clear(_content)
	for item_id in GameState.inventory:
		var count: int = GameState.inventory[item_id]
		if count <= 0:
			continue
		var item := GameState.item_data(item_id)
		# Hors combat, seuls les objets de soin servent.
		_content.add_child(UiTheme.button("%s  x%d" % [tr(item.display_name), count], _choose_item_target.bind(item), item.heal_amount > 0))
	if _content.get_child_count() == 0:
		_content.add_child(UiTheme.label(tr("MENU_NO_ITEMS"), UiTheme.DIM))
	_back = _focus_tabs
	UiTheme.focus_first(_content)


func _choose_item_target(item: ItemData) -> void:
	UiTheme.clear(_content)
	_content.add_child(UiTheme.label(tr(item.display_name), UiTheme.GOLD))
	for progress in GameState.heroes:
		var text := "%s   %s %d / %d" % [tr(progress.data.display_name), tr("HP_SHORT"), progress.hp, progress.max_hp()]
		_content.add_child(UiTheme.button(text, _use_item.bind(item, progress), progress.hp < progress.max_hp()))
	_back = _show_items
	UiTheme.focus_first(_content)


func _use_item(item: ItemData, progress: HeroProgress) -> void:
	progress.hp = mini(progress.hp + item.heal_amount, progress.max_hp())
	GameState.remove_item(item.id)
	AudioManager.play_heal()
	if GameState.inventory.get(item.id, 0) > 0:
		_choose_item_target(item)
	else:
		_show_items()
