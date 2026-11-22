extends CanvasLayer
## Boîte de dialogue (accessible partout sous le nom « Dialogue »).
## Utilisation : await Dialogue.say("NPC_ELDER", ["DLG_ELDER_1", "DLG_ELDER_2"])
## Les textes sont des clés de traduction (ou du texte déjà traduit).
## Espace : affiche toute la ligne, puis passe à la suivante.

signal _advanced
signal _typing_done
signal _chosen(index: int)

const CHARS_PER_SECOND := 45.0
const GOLD := Color(1.0, 0.85, 0.3)

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _arrow: Label
var _choices: HBoxContainer
var _open := false
var _typing := false
var _tween: Tween
## Démo automatique (`-- --autoplay`) : les lignes défilent toutes seules.
var _auto_advance := "--autoplay" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.hide()
	_arrow.hide()


func is_open() -> bool:
	return _open


func say(speaker: String, lines: Array) -> void:
	_open = true
	_panel.show()
	_name_label.text = tr(speaker) if speaker != "" else ""
	_name_label.visible = speaker != ""
	for line in lines:
		await _type(tr(line))
		if _auto_advance:
			await get_tree().create_timer(1.0).timeout
		else:
			await _advanced
	_panel.hide()
	await get_tree().process_frame  # évite que le même appui relance une interaction
	_open = false


## Pose une question avec plusieurs réponses. Renvoie l'index de la réponse choisie.
## Exemple : if await Dialogue.choose("NPC_INNKEEPER", "DLG_INN_SAVE", ["YES", "NO"]) == 0: ...
func choose(speaker: String, question: String, options: Array) -> int:
	_open = true
	_panel.show()
	_name_label.text = tr(speaker) if speaker != "" else ""
	_name_label.visible = speaker != ""
	await _type(tr(question))
	_arrow.hide()
	UiTheme.clear(_choices)
	for i in options.size():
		_choices.add_child(UiTheme.button(tr(options[i]), func() -> void: _chosen.emit(i)))
	_choices.show()
	var index := 0
	if _auto_advance:
		await get_tree().create_timer(0.8).timeout
	else:
		UiTheme.focus_first(_choices)
		index = await _chosen
	_choices.hide()
	UiTheme.clear(_choices)
	_panel.hide()
	await get_tree().process_frame
	_open = false
	return index


func _type(text: String) -> void:
	_text_label.text = text
	_text_label.visible_characters = 0
	_arrow.hide()
	_typing = true
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_characters", text.length(), text.length() / CHARS_PER_SECOND)
	_tween.finished.connect(_finish_typing)
	await _typing_done


func _finish_typing() -> void:
	if not _typing:
		return
	_typing = false
	_text_label.visible_characters = -1
	_arrow.show()
	_typing_done.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or _choices.visible or not event.is_action_pressed("confirm"):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_tween.kill()
		_finish_typing()
	elif _arrow.visible:
		_arrow.hide()
		_advanced.emit()


func _build() -> void:
	var theme := Theme.new()
	theme.default_font_size = 11
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.09, 0.94)
	style.border_color = Color(0.55, 0.47, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	theme.set_stylebox("panel", "PanelContainer", style)

	_panel = PanelContainer.new()
	_panel.theme = theme
	_panel.position = Vector2(40, 268)
	_panel.custom_minimum_size = Vector2(560, 80)
	_panel.size = Vector2(560, 80)
	add_child(_panel)

	var box := VBoxContainer.new()
	_panel.add_child(box)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", GOLD)
	box.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(540, 40)
	box.add_child(_text_label)
	_choices = HBoxContainer.new()
	_choices.theme = UiTheme.get_theme()
	_choices.add_theme_constant_override("separation", 16)
	_choices.hide()
	box.add_child(_choices)

	_arrow = Label.new()
	_arrow.text = ">"
	_arrow.add_theme_color_override("font_color", GOLD)
	_arrow.position = Vector2(582, 334)
	add_child(_arrow)
