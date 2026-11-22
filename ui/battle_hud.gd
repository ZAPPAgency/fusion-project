class_name BattleHud
extends CanvasLayer
## Interface du combat : frise des tours, messages, panneau de l'équipe, menu d'actions.

const SCREEN := Vector2(640, 360)
const GOLD := Color(1.0, 0.85, 0.3)

var action_menu: ActionMenu
var _timeline_box: HBoxContainer
var _message: Label
var _hint: Label
var _difficulty: Label
var _party_box: HBoxContainer
var _banner: Label
var _banner_details: Label
var _banner_backdrop: ColorRect
var _hero_panels := {}  # BattleUnit -> PanelContainer


func _ready() -> void:
	var root := Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	_timeline_box = HBoxContainer.new()
	_timeline_box.position = Vector2(8, 6)
	_timeline_box.add_theme_constant_override("separation", 3)
	root.add_child(_timeline_box)

	_message = Label.new()
	_message.position = Vector2(0, 34)
	_message.size = Vector2(SCREEN.x, 16)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 12)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 4)
	root.add_child(_message)

	_hint = Label.new()
	_hint.position = Vector2(0, 52)
	_hint.size = Vector2(SCREEN.x, 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 3)
	root.add_child(_hint)

	_difficulty = Label.new()
	_difficulty.position = Vector2(SCREEN.x - 248, 8)
	_difficulty.size = Vector2(240, 14)
	_difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_difficulty.add_theme_font_size_override("font_size", 8)
	_difficulty.modulate = Color(1, 1, 1, 0.7)
	root.add_child(_difficulty)
	show_difficulty()
	Settings.quality_changed.connect(show_difficulty)

	action_menu = ActionMenu.new()
	action_menu.position = Vector2(8, 290)
	action_menu.custom_minimum_size = Vector2(172, 62)
	root.add_child(action_menu)

	_party_box = HBoxContainer.new()
	_party_box.position = Vector2(188, 290)
	_party_box.add_theme_constant_override("separation", 4)
	root.add_child(_party_box)

	_banner_backdrop = ColorRect.new()
	_banner_backdrop.size = SCREEN
	_banner_backdrop.color = Color(0, 0, 0, 0.6)
	_banner_backdrop.hide()
	root.add_child(_banner_backdrop)

	var banner_box := VBoxContainer.new()
	banner_box.size = SCREEN
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.add_theme_constant_override("separation", 10)
	_banner_backdrop.add_child(banner_box)
	_banner = _centered_label(20, 6)
	banner_box.add_child(_banner)
	_banner_details = _centered_label(11, 4)
	banner_box.add_child(_banner_details)


## Crée un panneau par héros (nom, PV, PA), mis à jour automatiquement.
func setup(heroes: Array[BattleUnit]) -> void:
	for hero in heroes:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # simple affichage : laisse passer les clics
		panel.custom_minimum_size = Vector2(144, 62)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		panel.add_child(box)

		var name_label := Label.new()
		name_label.text = "%s  %s %d" % [hero.display_name, tr("LEVEL_SHORT"), hero.level]
		name_label.add_theme_color_override("font_color", hero.data.placeholder_color.lightened(0.3))
		var hp_label := Label.new()
		var ap_label := Label.new()
		box.add_child(name_label)
		box.add_child(hp_label)
		box.add_child(ap_label)

		var update_hp := func(hp: int, max_hp: int) -> void:
			hp_label.text = "%s  %d / %d" % [tr("HP_SHORT"), hp, max_hp]
		var update_ap := func(ap: int) -> void:
			ap_label.text = "%s  %d / %d" % [tr("AP_SHORT"), ap, BattleUnit.MAX_AP]
		update_hp.call(hero.hp, hero.max_hp)
		update_ap.call(hero.ap)
		hero.hp_changed.connect(update_hp)
		hero.ap_changed.connect(update_ap)

		_party_box.add_child(panel)
		_hero_panels[hero] = panel


## Met en valeur le panneau du héros qui joue (les autres sont assombris).
func set_active(unit: BattleUnit) -> void:
	for hero: BattleUnit in _hero_panels:
		var panel: PanelContainer = _hero_panels[hero]
		if not hero.is_alive():
			panel.modulate = Color(0.4, 0.4, 0.4)
		elif hero == unit:
			panel.modulate = Color.WHITE
		else:
			panel.modulate = Color(0.65, 0.65, 0.65)


## Affiche le combattant actuel puis les prochains tours.
func show_timeline(current: BattleUnit, upcoming: Array[BattleUnit]) -> void:
	for child in _timeline_box.get_children():
		child.queue_free()
	_timeline_box.add_child(_timeline_icon(current, true))
	for unit in upcoming:
		_timeline_box.add_child(_timeline_icon(unit, false))


func show_message(text: String) -> void:
	_message.text = text


## Rappel des touches pendant un QTE (vide pour cacher).
func show_hint(text: String) -> void:
	_hint.text = text


func show_difficulty() -> void:
	_difficulty.text = tr("DIFFICULTY_LABEL").format({"name": Settings.difficulty_name(), "quality": Settings.quality_name()})


## Fin de combat : titre (Victoire / Défaite) et détails (gains, niveaux...).
func show_banner(title: String, details: String) -> void:
	_banner.text = title
	_banner_details.text = details
	_timeline_box.hide()
	_banner_backdrop.show()


func _centered_label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline)
	return label


func _timeline_icon(unit: BattleUnit, is_current: bool) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = unit.data.placeholder_color.darkened(0.3)
	style.set_border_width_all(2 if is_current else 1)
	if is_current:
		style.border_color = GOLD
	elif unit.is_enemy:
		style.border_color = Color(0.9, 0.3, 0.3)
	else:
		style.border_color = Color(0.9, 0.9, 0.9)

	var icon := PanelContainer.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", style)
	icon.custom_minimum_size = Vector2(24, 24) if is_current else Vector2(18, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var label := Label.new()
	label.text = unit.short_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	icon.add_child(label)
	return icon


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 10
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	panel.border_color = Color(0.55, 0.47, 0.3)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(2)
	panel.set_content_margin_all(5)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Boutons compacts ; celui qui a le focus est surligné en doré.
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
		theme.set_stylebox(state, "Button", button)
	for state in ["hover", "focus"]:
		theme.set_stylebox(state, "Button", focused)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_hover_color", "Button", GOLD)
	return theme
