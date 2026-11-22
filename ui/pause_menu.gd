class_name PauseMenu
extends CanvasLayer
## Menu de pause (Tab / Start) : équipe, cartes équipées, collection, objets.
## Le jeu est en pause tant que le menu est ouvert. Échap revient en arrière, puis ferme.
## Dans la barre de gauche, la page de droite change dès qu'un onglet est sélectionné
## (aperçu) ; Espace entre dans la page pour y naviguer.

signal closed

const GRID_COLUMNS := 5
const GRID_SIZE := Vector2(454, 212)  ## Zone défilante des grilles de cartes (2 rangées visibles)

var _tabs: VBoxContainer
var _content: VBoxContainer
var _gold: Label
var _back: Callable  ## Que faire sur Échap (revenir en arrière ou fermer)
var _details: Label  ## Détails de la carte sélectionnée
var _pages: Array[Callable] = []  ## Construction de la page de chaque onglet : page(entrer: bool)
var _current_tab := 0
var _deck_preview: VBoxContainer  ## Page Cartes : deck du héros sélectionné
var _swap_in: HeroProgress  ## Page Équipe : héros de la réserve qui va entrer (on choisit qui sort)


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
	_pages = [_show_team, _show_card_heroes, _show_collection, _show_items]
	for i in _pages.size():
		var tab := UiTheme.button(tr(["MENU_TEAM", "MENU_CARDS", "MENU_COLLECTION", "MENU_ITEMS"][i]), _enter_tab.bind(i))
		tab.focus_entered.connect(_preview_tab.bind(i))
		_tabs.add_child(tab)
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

	_focus_tabs()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Souris : survoler la page de droite y fait entrer (Échap / clic droit ramène aux onglets).
func _on_focus_changed(control: Control) -> void:
	if _content.is_ancestor_of(control) and _back == close:
		_back = _focus_tabs


func close() -> void:
	get_tree().call_group("player", "refresh_look")  # le héros en tête a peut-être changé
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


## Retour dans la barre de gauche, sur l'onglet de la page affichée (la page est rafraîchie).
func _focus_tabs() -> void:
	_back = close
	_refresh_gold()
	var tab: Button = _tabs.get_child(_current_tab)
	if tab.has_focus():
		_preview_tab(_current_tab)
	else:
		tab.grab_focus()  # déclenche l'aperçu de la page


## Onglet sélectionné avec les flèches : la page s'affiche, le focus reste dans la barre.
func _preview_tab(index: int) -> void:
	_current_tab = index
	_back = close
	_swap_in = null
	_pages[index].call(false)
	# Petit fondu de la nouvelle page.
	_content.modulate.a = 0.0
	_content.create_tween().tween_property(_content, "modulate:a", 1.0, 0.12)


## Espace sur un onglet : on entre dans la page (s'il y a quelque chose à choisir).
func _enter_tab(index: int) -> void:
	_current_tab = index
	_pages[index].call(true)


func _refresh_gold() -> void:
	_gold.text = "%s : %d" % [tr("GOLD"), GameState.gold]


# --- Équipe ---------------------------------------------------------------------

## Équipe : un portrait animé par héros recruté. Espace sur un héros de l'équipe : il marche
## en tête sur la carte. Espace sur un héros en réserve : on choisit ensuite qui lui laisse
## sa place (seuls GameState.MAX_PARTY héros combattent).
func _show_team(enter := false, focus_index := 0) -> void:
	UiTheme.clear(_content)
	var compact := GameState.heroes.size() > GameState.MAX_PARTY  # 4 lignes : un peu moins hautes
	var rows: Array[Button] = []
	for i in GameState.heroes.size():
		rows.append(_team_row(GameState.heroes[i], i, 60.0 if compact else 66.0))
		_content.add_child(rows[i])
	var hint := tr("TEAM_HINT").format({"key": Controls.prompt("switch_leader")})
	if _swap_in:
		hint = tr("TEAM_SWAP_HINT").format({"hero": tr(_swap_in.data.display_name)})
	elif compact:
		hint += "\n" + tr("TEAM_BENCH_HINT").format({"count": GameState.MAX_PARTY})
	_content.add_child(UiTheme.label(hint, UiTheme.GOLD if _swap_in else UiTheme.DIM, 8))
	if enter:
		_back = _cancel_swap if _swap_in else _focus_tabs
		rows[focus_index].grab_focus()
		if compact:
			Tutorial.show_tip(&"team")  # première fois avec un héros en réserve


func _team_row(progress: HeroProgress, index: int, height: float) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(450, height)
	row.pressed.connect(_on_team_row_pressed.bind(index))
	var in_party := GameState.in_party(progress)
	if _swap_in and not in_party:
		row.modulate = Color(1, 1, 1, 0.4)  # pendant un échange, seuls ceux de l'équipe peuvent sortir
	UiFeedback.attach(row)
	var line := HBoxContainer.new()
	line.position = Vector2(8, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(64, height - 4)
	portrait_box.clip_contents = true  # les ailes ne débordent pas sur le texte
	line.add_child(portrait_box)
	var portrait := HeroPortrait.new(progress, HeroPortrait.zoom_to_fit(progress, height - 16))
	portrait.position = Vector2(32, height - 8)
	if not in_party:
		portrait.modulate = Color(0.6, 0.6, 0.7)  # en réserve
	portrait_box.add_child(portrait)
	# Sélectionné : le héros fait son attaque, comme pour dire « présent ! ».
	row.focus_entered.connect(func() -> void: portrait.play_once(&"attack1"))
	var info := _hero_card(progress)
	if index == GameState.leader_index:
		info.add_child(UiTheme.label("%s  ·  %s" % [tr("TEAM_IN_PARTY"), tr("TEAM_LEADER")], UiTheme.GOLD, 8))
	elif in_party:
		info.add_child(UiTheme.label(tr("TEAM_IN_PARTY"), UiTheme.GOLD, 8))
	else:
		info.add_child(UiTheme.label(tr("TEAM_BENCH"), UiTheme.DIM, 8))
	line.add_child(info)
	return row


func _on_team_row_pressed(index: int) -> void:
	var progress := GameState.heroes[index]
	if _swap_in:
		if not GameState.in_party(progress):
			return
		var incoming := _swap_in
		_swap_in = null
		GameState.swap_party(incoming, progress)
		_team_changed(GameState.heroes.find(incoming))
	elif GameState.in_party(progress):
		GameState.leader_index = index
		_team_changed(index)
	else:
		# Héros en réserve : on choisit maintenant qui sort de l'équipe.
		_swap_in = progress
		AudioManager.play_cue()
		_show_team(true, GameState.heroes.find(GameState.progress_of(GameState.party[0])))


## Échap pendant un échange : on l'annule et on revient sur le héros de la réserve.
func _cancel_swap() -> void:
	var index := GameState.heroes.find(_swap_in)
	_swap_in = null
	_show_team(true, index)


func _team_changed(index: int) -> void:
	AudioManager.play_cue()
	_show_team(true, index)
	# La page est reconstruite : on fait trembler la nouvelle ligne une fois placée.
	UiFeedback.shake.call_deferred(_content.get_child(index))


func _hero_card(progress: HeroProgress) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var xp_text := tr("XP_MAX") if progress.level == HeroProgress.MAX_LEVEL \
		else "%d / %d" % [progress.xp, HeroProgress.xp_to_next(progress.level)]
	box.add_child(UiTheme.label("%s   %s %d   XP %s" % [progress.full_title(), tr("LEVEL_SHORT"), progress.level, xp_text],
		progress.data.placeholder_color.lightened(0.3), 11))
	box.add_child(UiTheme.label(_stats_text(progress)))
	var names: Array[String] = []
	for card in progress.equipped_cards():
		names.append(tr(card.data.display_name))
	var cards_text := ", ".join(names) if not names.is_empty() else "-"
	box.add_child(UiTheme.label("%s : %s" % [tr("MENU_CARDS"), cards_text], UiTheme.DIM))
	return box


func _stats_text(progress: HeroProgress) -> String:
	return "%s %d / %d    %s %d    %s %d    %s %d" % [
		tr("HP_SHORT"), progress.hp, progress.max_hp(), tr("STAT_ATK"), progress.attack(),
		tr("STAT_DEF"), progress.defense(), tr("STAT_SPD"), progress.speed()]


# --- Cartes ------------------------------------------------------------------------

## Choix du héros à équiper ; en dessous, aperçu du deck du héros sélectionné.
func _show_card_heroes(enter := false, hero_index := 0) -> void:
	UiTheme.clear(_content)
	_content.add_child(UiTheme.label(tr("MENU_CHOOSE_HERO"), UiTheme.GOLD))
	var buttons: Array[Button] = []
	var row_height := 40.0 if GameState.heroes.size() <= GameState.MAX_PARTY else 30.0
	for progress in GameState.heroes:
		var button := _hero_pick_row(progress, row_height)
		button.pressed.connect(_show_card_slots.bind(progress))
		button.focus_entered.connect(_preview_deck.bind(progress))
		_content.add_child(button)
		buttons.append(button)
	_deck_preview = VBoxContainer.new()
	_deck_preview.add_theme_constant_override("separation", 4)
	_content.add_child(_deck_preview)
	_preview_deck(GameState.heroes[hero_index])
	if enter:
		_back = _focus_tabs
		buttons[hero_index].grab_focus()
		Tutorial.show_tip(&"cards")


## Ligne compacte « portrait + nom » pour choisir un héros (page Cartes).
func _hero_pick_row(progress: HeroProgress, height: float) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(450, height)
	UiFeedback.attach(row)
	var line := HBoxContainer.new()
	line.position = Vector2(8, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(44, height)
	portrait_box.clip_contents = true  # les ailes ne débordent pas sur le texte
	line.add_child(portrait_box)
	var portrait := HeroPortrait.new(progress, HeroPortrait.zoom_to_fit(progress, height - 8.0))
	portrait.position = Vector2(22, height - 3.0)
	portrait_box.add_child(portrait)
	row.focus_entered.connect(func() -> void: portrait.play_once(&"attack1"))
	var name_label := UiTheme.label("%s   %s %d" % [progress.full_title(), tr("LEVEL_SHORT"), progress.level],
		progress.data.placeholder_color.lightened(0.3), 10)
	name_label.custom_minimum_size = Vector2(380, height)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	return row


## Aperçu du deck d'un héros : son résumé et ses 5 emplacements (non sélectionnables).
func _preview_deck(progress: HeroProgress) -> void:
	UiTheme.clear(_deck_preview)
	_deck_preview.add_child(_hero_card(progress))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_deck_preview.add_child(row)
	for slot in HeroProgress.SLOT_UNLOCK_LEVELS.size():
		var locked_level: int = 0 if slot < progress.card_slots() else HeroProgress.SLOT_UNLOCK_LEVELS[slot]
		row.add_child(CardView.new(progress.slots[slot], locked_level))


## Les 5 emplacements du héros (verrouillés tant que son niveau est trop bas).
## Renvoie le bouton de l'emplacement sélectionné.
func _show_card_slots(progress: HeroProgress, focus_slot := 0) -> CardButton:
	UiTheme.clear(_content)
	_content.add_child(_hero_card(progress))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)
	for slot in HeroProgress.SLOT_UNLOCK_LEVELS.size():
		var locked_level: int = 0 if slot < progress.card_slots() else HeroProgress.SLOT_UNLOCK_LEVELS[slot]
		var button := CardButton.new(progress.slots[slot], locked_level)
		button.pressed.connect(_show_card_choices.bind(progress, slot))
		button.focused.connect(_describe_card)
		row.add_child(button)
	_add_details()
	_back = _show_card_heroes.bind(true, GameState.heroes.find(progress))
	var focused: CardButton = row.get_child(focus_slot)
	focused.grab_focus()
	return focused


## Cartes de la collection qui peuvent aller dans cet emplacement.
func _show_card_choices(progress: HeroProgress, slot: int) -> void:
	UiTheme.clear(_content)
	var header := HBoxContainer.new()
	_content.add_child(header)
	var title := UiTheme.label(tr(progress.data.display_name), UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if progress.slots[slot]:
		header.add_child(UiTheme.button(tr("MENU_UNEQUIP"), _equip_card.bind(progress, slot, null)))

	var choices := GameState.cards.filter(func(card: CardInstance) -> bool:
		return card != progress.slots[slot] and progress.can_equip(slot, card))
	# Cartes libres d'abord, puis les plus rares.
	choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var a_free := GameState.owner_of(a) == null
		var b_free := GameState.owner_of(b) == null
		if a_free != b_free:
			return a_free
		return _rarer_first(a, b))
	var grid := _card_grid(choices, func(card: CardInstance) -> void: _equip_card(progress, slot, card))
	if choices.is_empty():
		_content.add_child(UiTheme.label(tr("MENU_NOTHING_TO_EQUIP"), UiTheme.DIM))
	_add_details()
	_back = _show_card_slots.bind(progress, slot)
	if grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()
	else:
		UiTheme.focus_first(header)


func _equip_card(progress: HeroProgress, slot: int, card: CardInstance) -> void:
	GameState.equip_card(progress, slot, card)
	AudioManager.play_cue()
	var button := _show_card_slots(progress, slot)
	UiFeedback.shake.call_deferred(button.view)  # la carte posée tremble dans son emplacement


# --- Collection ---------------------------------------------------------------------

func _show_collection(enter := false) -> void:
	UiTheme.clear(_content)
	_content.add_child(_materials_line())
	var cards := GameState.cards.duplicate()
	cards.sort_custom(_rarer_first)
	var grid := _card_grid(cards, func(_card: CardInstance) -> void: pass)
	if cards.is_empty():
		_content.add_child(UiTheme.label(tr("MENU_COLLECTION_EMPTY"), UiTheme.DIM))
	_add_details()
	if enter and grid.get_child_count() > 0:
		_back = _focus_tabs
		grid.get_child(0).grab_focus()


## Matériaux de forge possédés : icône et quantité.
func _materials_line() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.add_child(UiTheme.label(tr("MENU_MATERIALS") + " :", UiTheme.GOLD, 9))
	for file in ResourceLoader.list_directory("res://data/materials"):
		var data: MaterialData = load("res://data/materials/" + file)
		line.add_child(MaterialIcon.new(data))
		line.add_child(UiTheme.label("%d  " % GameState.material_count(data.id), Color.WHITE, 9))
	return line


# --- Outils des pages de cartes -------------------------------------------------------

## Grille défilante de cartes ; `on_pressed(card)` est appelé quand on en choisit une.
func _card_grid(cards: Array, on_pressed: Callable) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = GRID_SIZE
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for same_cards in CardButton.group(cards):
		var card: CardInstance = same_cards[0]
		var button := CardButton.new(card, 0, same_cards.size())
		button.view.dimmed = GameState.owner_of(card) != null
		button.pressed.connect(on_pressed.bind(card))
		button.focused.connect(_describe_card)
		grid.add_child(button)
	return grid


func _add_details() -> void:
	_details = UiTheme.label("", Color.WHITE, 9)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(450, 40)
	_content.add_child(_details)


## Détails de la carte : nom, rareté, rang, effets, à qui elle est réservée ou qui la porte.
func _describe_card(card: CardInstance) -> void:
	if card == null:
		_details.text = ""
		return
	var lines: Array[String] = []
	lines.append("%s   %s   %s" % [tr(card.data.display_name), tr(CardData.RARITY_NAMES[card.data.rarity]),
		tr("CARD_RANK").format({"rank": card.rank})])
	lines.append("   ".join(card.effect_lines()))
	var notes: Array[String] = []
	if card.data.for_hero != &"":
		notes.append(tr("CARD_FOR_HERO").format({"hero": tr("HERO_" + String(card.data.for_hero).to_upper())}))
	var holder := GameState.owner_of(card)
	if holder:
		notes.append(tr("CARD_EQUIPPED_BY").format({"hero": tr(holder.data.display_name)}))
	if not notes.is_empty():
		lines.append("   ".join(notes))
	_details.text = "\n".join(lines)


func _rarer_first(a: CardInstance, b: CardInstance) -> bool:
	if a.data.rarity != b.data.rarity:
		return a.data.rarity > b.data.rarity
	if a.data.id != b.data.id:
		return tr(a.data.display_name) < tr(b.data.display_name)
	return a.rank > b.rank


# --- Objets -------------------------------------------------------------------------

func _show_items(enter := false) -> void:
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
	if enter:
		_back = _focus_tabs
		UiTheme.focus_first(_content)


func _choose_item_target(item: ItemData) -> void:
	UiTheme.clear(_content)
	_content.add_child(UiTheme.label(tr(item.display_name), UiTheme.GOLD))
	for progress in GameState.heroes:
		var text := "%s   %s %d / %d" % [tr(progress.data.display_name), tr("HP_SHORT"), progress.hp, progress.max_hp()]
		_content.add_child(UiTheme.button(text, _use_item.bind(item, progress), progress.hp < progress.max_hp()))
	_back = _show_items.bind(true)
	UiTheme.focus_first(_content)


func _use_item(item: ItemData, progress: HeroProgress) -> void:
	progress.hp = mini(progress.hp + item.heal_amount, progress.max_hp())
	GameState.remove_item(item.id)
	AudioManager.play_heal()
	if GameState.inventory.get(item.id, 0) > 0:
		_choose_item_target(item)
	else:
		_show_items(true)
