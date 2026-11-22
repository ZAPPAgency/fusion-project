extends CanvasLayer
## Fiches de tutoriel (accessible partout sous le nom « Tutorial »).
## Chaque fiche s'affiche UNE fois par partie, la première fois que le joueur fait l'action :
##   await Tutorial.show_tip(&"attack")
## Le jeu est en pause pendant la fiche. Espace / clic : page suivante ; Échap : fermer.
## Les fiches vues sont gardées dans GameState.seen_tips (et donc dans la sauvegarde).
## Rien ne s'affiche pendant les démos et les tests automatiques.

signal _next(skip: bool)

## Contenu des fiches : titre de chaque page, lignes de texte, touches à mettre en valeur.
## Les textes sont des clés de traduction ; {confirm}, {parry}... sont remplacés par les touches.
## Une touche s'écrit "action" (légende ACTION_<ACTION>) ou "action:CLE_DE_LEGENDE".
const TIPS := {
	&"map": [
		{"title": "TUTO_MAP_TITLE", "lines": ["TUTO_MAP_1", "TUTO_MAP_2", "TUTO_MAP_3"], "keys": ["confirm", "menu", "switch_leader"]},
		{"title": "TUTO_MAP_ENEMIES_TITLE", "lines": ["TUTO_MAP_ENEMIES_1", "TUTO_MAP_ENEMIES_2"]},
	],
	&"battle": [
		{"title": "TUTO_BATTLE_TITLE", "lines": ["TUTO_BATTLE_1", "TUTO_BATTLE_2"]},
		{"title": "TUTO_AP_TITLE", "lines": ["TUTO_AP_1", "TUTO_AP_2"]},
		{"title": "TUTO_SETTINGS_TITLE", "lines": ["TUTO_SETTINGS_1", "TUTO_SETTINGS_2", "TUTO_SETTINGS_3"]},
	],
	&"attack": [
		{"title": "TUTO_ATTACK_TITLE", "lines": ["TUTO_ATTACK_1", "TUTO_ATTACK_2", "TUTO_ATTACK_3"], "keys": ["confirm:ACTION_HIT"]},
	],
	&"defense": [
		{"title": "TUTO_DEFENSE_TITLE", "lines": ["TUTO_DEFENSE_1", "TUTO_DEFENSE_2", "TUTO_DEFENSE_3"], "keys": ["parry", "dodge"]},
		{"title": "TUTO_COUNTER_TITLE", "lines": ["TUTO_COUNTER_1", "TUTO_COUNTER_2"]},
	],
	&"skills": [
		{"title": "TUTO_SKILLS_TITLE", "lines": ["TUTO_SKILLS_1", "TUTO_SKILLS_2"]},
	],
	&"items": [
		{"title": "TUTO_ITEMS_TITLE", "lines": ["TUTO_ITEMS_1", "TUTO_ITEMS_2"]},
	],
	&"victory": [
		{"title": "TUTO_VICTORY_TITLE", "lines": ["TUTO_VICTORY_1", "TUTO_VICTORY_2"]},
	],
	&"defeat": [
		{"title": "TUTO_DEFEAT_TITLE", "lines": ["TUTO_DEFEAT_1", "TUTO_DEFEAT_2"]},
	],
	&"cards": [
		{"title": "TUTO_CARDS_TITLE", "lines": ["TUTO_CARDS_1", "TUTO_CARDS_2", "TUTO_CARDS_3"]},
	],
	&"team": [
		{"title": "TUTO_TEAM_TITLE", "lines": ["TUTO_TEAM_1", "TUTO_TEAM_2"]},
	],
	&"forge": [
		{"title": "TUTO_FORGE_TITLE", "lines": ["TUTO_FORGE_1", "TUTO_FORGE_2"]},
		{"title": "TUTO_FORGE_CARDS_TITLE", "lines": ["TUTO_FORGE_UPGRADE", "TUTO_FORGE_FUSION", "TUTO_FORGE_EVOLVE", "TUTO_FORGE_CRAFT"]},
		{"title": "TUTO_FORGE_HEROES_TITLE", "lines": ["TUTO_FORGE_HEROES_1", "TUTO_FORGE_HEROES_2"]},
	],
}

const PANEL_WIDTH := 400.0
const INPUT_DELAY := 0.25  ## L'appui qui a ouvert la fiche ne la fait pas défiler

var _open := false
var _opened_at := 0
var _root: Control
var _panel: PanelContainer
var _title: Label
var _lines: VBoxContainer
var _keys: HBoxContainer
var _footer: Label
## Démos et tests automatiques : jamais de fiche.
var _disabled := "--autoplay" in OS.get_cmdline_user_args() or "--autobattle" in OS.get_cmdline_user_args() \
	or DisplayServer.get_name() == "headless"


func _ready() -> void:
	layer = 70  # au-dessus des menus et des dialogues
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_open() -> bool:
	return _open


## Affiche la fiche `id` si elle n'a pas encore été vue dans cette partie. À attendre (await).
func show_tip(id: StringName) -> void:
	if _disabled or _open or GameState.seen_tips.has(id) or not TIPS.has(id):
		return
	GameState.seen_tips[id] = true
	_open = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	_root.show()
	var pages: Array = TIPS[id]
	for i in pages.size():
		_show_page(pages[i], i, pages.size())
		var skip: bool = await _next
		if skip:
			break
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.12)
	await tween.finished
	_root.hide()
	get_tree().paused = was_paused
	await get_tree().process_frame  # l'appui qui ferme ne déclenche rien d'autre
	_open = false


## Remplace {confirm}, {parry}... par les touches (clavier / manette / souris).
static func format_keys(text: String) -> String:
	return text.format({
		"confirm": Controls.prompt("confirm"),
		"parry": Controls.prompt("parry"),
		"dodge": Controls.prompt("dodge"),
		"menu": Controls.prompt("menu"),
		"switch": Controls.prompt("switch_leader"),
		"move": move_keys(),
	})


## Les quatre touches de déplacement (ZQSD en AZERTY, WASD en QWERTY) et les flèches.
static func move_keys() -> String:
	var letters := ""
	for action in ["move_up", "move_left", "move_down", "move_right"]:
		var keycode: Key = Controls.KEYS[action][0]
		if DisplayServer.get_name() != "headless":
			keycode = DisplayServer.keyboard_get_keycode_from_physical(keycode)
		letters += OS.get_keycode_string(keycode)
	return "%s / %s" % [letters, TranslationServer.translate("KEY_ARROWS")]


func _show_page(page: Dictionary, index: int, count: int) -> void:
	_opened_at = Time.get_ticks_msec()
	_title.text = tr(page.title)
	UiTheme.clear(_lines)
	for line in page.lines:
		var label := UiTheme.label(format_keys(tr(line)), Color(0.92, 0.9, 0.85), 10)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 0)
		_lines.add_child(label)
	UiTheme.clear(_keys)
	for action in page.get("keys", []):
		_keys.add_child(_key_badge(action))
	_keys.visible = _keys.get_child_count() > 0
	var more := tr("TUTO_NEXT") if index < count - 1 else tr("TUTO_CLOSE")
	_footer.text = "%s   %d / %d" % [more, index + 1, count] if count > 1 else more
	# Petite apparition : fondu et léger grossissement.
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.96
	_panel.pivot_offset = _panel.size / 2
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_center_panel.call_deferred()


## Touche dessinée comme une petite plaque dorée, avec ce qu'elle fait.
func _key_badge(entry: String) -> Control:
	var action := entry.get_slice(":", 0)
	var caption := entry.get_slice(":", 1) if ":" in entry else "ACTION_" + action.to_upper()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.13, 0.07)
	style.border_color = UiTheme.GOLD
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(2)
	style.set_content_margin_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	plate.add_theme_stylebox_override("panel", style)
	plate.add_child(UiTheme.label(Controls.prompt(action), UiTheme.GOLD, 10))
	box.add_child(plate)
	box.add_child(UiTheme.label(tr(caption), UiTheme.DIM, 9))
	return box


func _center_panel() -> void:
	_panel.reset_size()
	_panel.position = (Vector2(640, 360) - _panel.size) / 2
	_panel.pivot_offset = _panel.size / 2


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Pendant une fiche, rien d'autre ne reçoit les touches ni les clics.
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_at < INPUT_DELAY * 1000.0:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		_next.emit(true)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		_next.emit(false)


func _build() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.size = Vector2(640, 360)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.size = _root.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_title = UiTheme.label("", UiTheme.GOLD, 13)
	box.add_child(_title)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 5)
	box.add_child(_lines)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 12)
	box.add_child(_keys)
	_footer = UiTheme.label("", UiTheme.DIM, 8)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_footer)
