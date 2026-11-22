class_name PauseMenu
extends CanvasLayer
## Menu de pause (Tab / Start) : équipe, cartes équipées, collection, objets.
## Le jeu est en pause tant que le menu est ouvert. Échap revient en arrière, puis ferme.

signal closed

const GRID_COLUMNS := 5
const GRID_SIZE := Vector2(454, 212)  ## Zone défilante des grilles de cartes (2 rangées visibles)

var _tabs: VBoxContainer
var _content: VBoxContainer
var _gold: Label
var _back: Callable  ## Que faire sur Échap (revenir en arrière ou fermer)
var _details: Label  ## Détails de la carte sélectionnée


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
	_tabs.add_child(UiTheme.button(tr("MENU_CARDS"), _show_card_heroes))
	_tabs.add_child(UiTheme.button(tr("MENU_COLLECTION"), _show_collection))
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

func _show_card_heroes() -> void:
	UiTheme.clear(_content)
	_content.add_child(UiTheme.label(tr("MENU_CHOOSE_HERO"), UiTheme.GOLD))
	for progress in GameState.heroes:
		_content.add_child(UiTheme.button(tr(progress.data.display_name), _show_card_slots.bind(progress)))
	_back = _focus_tabs
	UiTheme.focus_first(_content)


## Les 5 emplacements du héros (verrouillés tant que son niveau est trop bas).
func _show_card_slots(progress: HeroProgress, focus_slot := 0) -> void:
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
	_back = _show_card_heroes
	row.get_child(focus_slot).grab_focus()


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
	_show_card_slots(progress, slot)


# --- Collection ---------------------------------------------------------------------

func _show_collection() -> void:
	UiTheme.clear(_content)
	var cards := GameState.cards.duplicate()
	cards.sort_custom(_rarer_first)
	var grid := _card_grid(cards, func(_card: CardInstance) -> void: pass)
	if cards.is_empty():
		_content.add_child(UiTheme.label(tr("MENU_COLLECTION_EMPTY"), UiTheme.DIM))
	_add_details()
	_back = _focus_tabs
	if grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()


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
	for card: CardInstance in cards:
		var button := CardButton.new(card)
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
