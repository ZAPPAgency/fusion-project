class_name ForgeMenu
extends CanvasLayer
## Forge de Gorm : améliorer, fusionner, faire évoluer et fabriquer des cartes,
## et faire évoluer les héros. Le jeu est en pause tant que la forge est ouverte.
## À gauche la liste (cartes ou recettes), à droite le détail, le coût et les boutons d'action.
## Les règles sont dans Forge ; les animations dans ForgeFx.

signal closed

enum Tab { UPGRADE, FUSION, EVOLVE, CRAFT, HEROES }

const TAB_KEYS := ["FORGE_TAB_UPGRADE", "FORGE_TAB_FUSION", "FORGE_TAB_EVOLVE", "FORGE_TAB_CRAFT", "FORGE_TAB_HEROES"]
const GRID_COLUMNS := 4
const LIST_SIZE := Vector2(318, 280)
const RED := Color(1.0, 0.45, 0.4)

var _tabs: HBoxContainer
var _gold: Label
var _left: VBoxContainer
var _right: VBoxContainer
var _fx: ForgeFx
var _tab := Tab.UPGRADE
var _back: Callable  ## Que faire sur Échap (revenir à la liste, aux onglets, ou fermer)
var _busy := false  ## Une animation est en cours
var _list_buttons: Array[Button] = []  ## Boutons de la liste de gauche (pour y revenir)


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
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = root.size
	root.add_child(shade)

	var top := _panel(root, Rect2(16, 8, 608, 30))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	top.add_child(header)
	header.add_child(UiTheme.label(tr("FORGE_TITLE"), UiTheme.GOLD, 12))
	_tabs = HBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(_tabs)
	for tab in Tab.values():
		_tabs.add_child(UiTheme.button(tr(TAB_KEYS[tab]), _show_tab.bind(tab)))
	_gold = UiTheme.label("", UiTheme.GOLD)
	header.add_child(_gold)

	_left = VBoxContainer.new()
	_panel(root, Rect2(16, 44, 334, 300)).add_child(_left)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 4)
	_panel(root, Rect2(356, 44, 268, 300)).add_child(_right)

	_fx = ForgeFx.new()
	root.add_child(_fx)

	_show_tab(Tab.UPGRADE)


func close() -> void:
	get_tree().paused = false
	FxLibrary.set_scene_glow(get_tree(), true)
	get_tree().call_group("player", "refresh_look")  # le héros a peut-être évolué
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_back.call()


func _panel(root: Control, rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	root.add_child(panel)
	return panel


# --- Onglets --------------------------------------------------------------------------

func _show_tab(tab: Tab, keep_focus_on: Variant = null) -> void:
	_tab = tab
	_gold.text = "%s : %d" % [tr("GOLD"), GameState.gold]
	for i in _tabs.get_child_count():
		var button: Button = _tabs.get_child(i)
		button.add_theme_color_override("font_color", UiTheme.GOLD if i == tab else Color.WHITE)
	UiTheme.clear(_left)
	UiTheme.clear(_right)
	_list_buttons.clear()
	match tab:
		Tab.UPGRADE:
			_fill_card_list(_sorted(GameState.cards), _describe_upgrade)
		Tab.FUSION:
			_fill_recipe_list(false)
		Tab.EVOLVE:
			_fill_card_list(_sorted(GameState.cards.filter(func(card: CardInstance) -> bool: return card.data.evolves_into != null)), _describe_evolution)
		Tab.CRAFT:
			_fill_recipe_list(true)
		Tab.HEROES:
			_fill_hero_list()
	_back = _focus_tabs
	if _list_buttons.is_empty():
		_left.add_child(UiTheme.label(tr("FORGE_NOTHING"), UiTheme.DIM))
		_focus_tabs()
		return
	_focus_list(keep_focus_on)


func _focus_tabs() -> void:
	_back = close
	_tabs.get_child(_tab).grab_focus()


## Remet le focus dans la liste, sur l'élément `target` (carte, recette ou héros) s'il y est.
func _focus_list(target: Variant = null) -> void:
	_back = _focus_tabs
	for button in _list_buttons:
		if target != null and button.get_meta("target") == target:
			button.grab_focus()
			return
	_list_buttons[0].grab_focus()


## Après une action : on recharge l'onglet et on garde la sélection.
func _refresh(target: Variant) -> void:
	_show_tab(_tab, target)


# --- Listes de gauche -----------------------------------------------------------------

func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(scroll)
	return scroll


## Grille de cartes (exemplaires identiques regroupés). `describe(card)` remplit la droite.
func _fill_card_list(cards: Array, describe: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_scroll().add_child(grid)
	for same_cards in CardButton.group(cards):
		var card: CardInstance = same_cards[0]
		var button := CardButton.new(card, 0, same_cards.size())
		button.view.dimmed = GameState.owner_of(card) != null
		button.set_meta("target", card)
		button.focused.connect(func(_card: CardInstance) -> void: describe.call(card))
		button.pressed.connect(_focus_actions)
		grid.add_child(button)
		_list_buttons.append(button)


func _fill_recipe_list(crafting: bool) -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll().add_child(list)
	for recipe in Forge.recipes():
		if recipe.is_crafting() != crafting:
			continue
		var text := tr(recipe.result.display_name)
		if not crafting:
			text = "%s + %s" % [tr(recipe.card_a.display_name), tr(recipe.card_b.display_name)]
		var button := UiTheme.button(text, _focus_actions)
		if not Forge.can_fuse(recipe):
			button.add_theme_color_override("font_color", UiTheme.DIM)
		button.set_meta("target", recipe)
		button.focus_entered.connect(_describe_recipe.bind(recipe))
		list.add_child(button)
		_list_buttons.append(button)


func _fill_hero_list() -> void:
	for progress in GameState.heroes:
		var stage_text := tr("FORGE_STAGE").format({"stage": progress.stage + 1, "max": progress.data.stages.size()})
		var button := UiTheme.button("%s\n   %s" % [progress.full_title(), stage_text], _focus_actions)
		button.set_meta("target", progress)
		button.focus_entered.connect(_describe_hero.bind(progress))
		_left.add_child(button)
		_list_buttons.append(button)


## Le joueur a choisi un élément : le focus passe sur le premier bouton d'action à droite.
func _focus_actions() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	for child in _right.find_children("*", "Button", true, false):
		if not child.disabled:
			_back = _return_to_list.bind(focused)
			child.grab_focus()
			return


## Échap depuis les boutons d'action : retour sur l'élément choisi dans la liste.
func _return_to_list(previous: Control) -> void:
	_back = _focus_tabs
	if is_instance_valid(previous):
		previous.grab_focus()
	else:
		_focus_list()


func _sorted(cards: Array) -> Array:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if a.data.rarity != b.data.rarity:
			return a.data.rarity > b.data.rarity
		if a.data.id != b.data.id:
			return tr(a.data.display_name) < tr(b.data.display_name)
		return a.rank > b.rank)
	return sorted


# --- Détails à droite -------------------------------------------------------------------

func _describe_upgrade(card: CardInstance) -> void:
	UiTheme.clear(_right)
	var top := _card_and_text(card, _upgrade_text(card))
	_right.add_child(top)
	var duplicates := Forge.duplicates_of(card)
	if card.is_max_rank():
		_right.add_child(UiTheme.label(tr("FORGE_MAX_RANK"), UiTheme.GOLD))
		return
	_add_cost(Forge.upgrade_cost(card))
	_add_action(tr("FORGE_UPGRADE").format({"rank": card.rank + 1}), Forge.can_upgrade(card), _do_upgrade.bind(card))
	_add_action(tr("FORGE_MERGE").format({"count": duplicates.size()}), not duplicates.is_empty(), _do_merge.bind(card))


func _upgrade_text(card: CardInstance) -> String:
	var lines: Array[String] = [tr(card.data.display_name), "   ".join(card.effect_lines())]
	if not card.is_max_rank():
		var next := CardInstance.new(card.data, 0, card.rank + 1)
		lines.append("")
		lines.append(tr("FORGE_NEXT_RANK").format({"from": card.rank, "to": card.rank + 1}))
		lines.append("   ".join(next.effect_lines()))
	return "\n".join(lines)


func _describe_evolution(card: CardInstance) -> void:
	UiTheme.clear(_right)
	var evolved := CardInstance.new(card.data.evolves_into, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(CardView.new(card))
	row.add_child(_arrow())
	row.add_child(CardView.new(evolved))
	_right.add_child(row)
	_right.add_child(_text("%s\n%s" % [tr(evolved.data.display_name), "   ".join(evolved.effect_lines())]))
	if not card.is_max_rank():
		_right.add_child(UiTheme.label(tr("FORGE_NEEDS_MAX_RANK").format({"rank": CardData.MAX_RANK, "current": card.rank}), RED, 9))
	_add_cost(Forge.evolution_cost(card))
	_add_action(tr("FORGE_EVOLVE"), Forge.can_evolve(card), _do_evolve.bind(card))


func _describe_recipe(recipe: FusionRecipe) -> void:
	UiTheme.clear(_right)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	if not recipe.is_crafting():
		var found := Forge.ingredients(recipe)
		for i in 2:
			var wanted: CardData = recipe.card_a if i == 0 else recipe.card_b
			var view := CardView.new(found[i] if found.size() == 2 else CardInstance.new(wanted, 0))
			view.dimmed = found.size() < 2 and not GameState.cards.any(func(card: CardInstance) -> bool: return card.data == wanted)
			row.add_child(view)
			row.add_child(UiTheme.label("+" if i == 0 else "=", UiTheme.GOLD, 12))
	row.add_child(CardView.new(CardInstance.new(recipe.result, 0)))
	_right.add_child(row)
	var result := CardInstance.new(recipe.result, 0)
	_right.add_child(_text("%s   %s\n%s" % [tr(recipe.result.display_name), tr(CardData.RARITY_NAMES[recipe.result.rarity]), "   ".join(result.effect_lines())]))
	_add_cost(Forge.recipe_cost(recipe))
	_add_action(tr("FORGE_CRAFT" if recipe.is_crafting() else "FORGE_FUSE"), Forge.can_fuse(recipe), _do_fuse.bind(recipe))


func _describe_hero(progress: HeroProgress) -> void:
	UiTheme.clear(_right)
	var next := progress.next_stage_data()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_portrait(progress, progress.stage))
	if next:
		row.add_child(_arrow())
		row.add_child(_portrait(progress, progress.stage + 1))
	_right.add_child(row)
	if next == null:
		_right.add_child(_text("%s\n%s" % [progress.full_title(), tr("FORGE_STAGE_MAX")]))
		return
	var current := progress.stage_data()
	var gains: Array[String] = []
	for stat in [["max_hp", "HP_SHORT"], ["attack", "STAT_ATK"], ["defense", "STAT_DEF"], ["speed", "STAT_SPD"]]:
		var gain: int = next.get(stat[0]) - current.get(stat[0])
		if gain != 0:
			gains.append("%+d %s" % [gain, tr(stat[1])])
	var lines := [tr(next.title), "   ".join(gains)]
	if next.skill:
		lines.append(tr("FORGE_NEW_SKILL").format({"skill": tr(next.skill.display_name)}))
	_right.add_child(_text("\n".join(lines)))
	if progress.level < next.required_level:
		_right.add_child(UiTheme.label(tr("FORGE_LEVEL_REQUIRED").format({"level": next.required_level, "current": progress.level}), RED, 9))
	_add_cost(Forge.hero_evolution_cost(progress))
	_add_action(tr("FORGE_EVOLVE"), Forge.can_evolve_hero(progress), _do_evolve_hero.bind(progress))


# --- Actions (avec animation) -------------------------------------------------------------

func _do_upgrade(card: CardInstance) -> void:
	if Forge.upgrade(card):
		await _animate(_fx.play_upgrade.bind(card))
	_refresh(card)


func _do_merge(card: CardInstance) -> void:
	var duplicates := Forge.duplicates_of(card)
	if not duplicates.is_empty() and Forge.merge_duplicates(card, duplicates[0]):
		await _animate(_fx.play_merge.bind(card))
	_refresh(card)


func _do_fuse(recipe: FusionRecipe) -> void:
	# Copie des ingrédients pour l'animation (ils disparaissent de la collection).
	var shown: Array[CardInstance] = []
	for card in Forge.ingredients(recipe):
		shown.append(CardInstance.new(card.data, card.uid, card.rank))
	var result := Forge.fuse(recipe)
	if result:
		await _animate(_fx.play_fusion.bind(shown, result))
	_refresh(recipe)


func _do_evolve(card: CardInstance) -> void:
	var before := CardInstance.new(card.data, card.uid, card.rank)
	if Forge.evolve(card):
		await _animate(_fx.play_card_evolution.bind(before, card))
	_refresh(card)


func _do_evolve_hero(progress: HeroProgress) -> void:
	var old_stage := progress.stage
	if Forge.evolve_hero(progress):
		await _animate(_fx.play_hero_evolution.bind(progress, old_stage))
	_refresh(progress)


## Joue une animation en bloquant le menu (pas de navigation pendant ce temps).
func _animate(animation: Callable) -> void:
	_busy = true
	get_viewport().gui_release_focus()
	await animation.call()
	_busy = false


# --- Petits éléments d'interface ------------------------------------------------------------

func _card_and_text(card: CardInstance, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(CardView.new(card))
	var label := _text(text)
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	return row


func _text(text: String) -> Label:
	var label := UiTheme.label(text, Color.WHITE, 9)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	return label


## Lignes de coût : or puis matériaux, en rouge s'il en manque.
func _add_cost(cost: Dictionary) -> void:
	_right.add_child(UiTheme.label(tr("FORGE_COST"), UiTheme.GOLD, 9))
	var gold: int = cost.get("gold", 0)
	if gold > 0:
		_right.add_child(UiTheme.label("%s  %d / %d" % [tr("GOLD"), gold, GameState.gold], Color.WHITE if GameState.gold >= gold else RED, 9))
	var materials: Dictionary = cost.get("materials", {})
	for material_id in materials:
		var line := HBoxContainer.new()
		line.add_child(MaterialIcon.new(GameState.material_data(material_id)))
		var have := GameState.material_count(material_id)
		var need: int = materials[material_id]
		line.add_child(UiTheme.label("%s  %d / %d" % [tr(GameState.material_data(material_id).display_name), need, have],
			Color.WHITE if have >= need else RED, 9))
		_right.add_child(line)


func _add_action(text: String, enabled: bool, action: Callable) -> void:
	_right.add_child(UiTheme.button(text, action, enabled))


## Flèche dessinée (les polices n'ont pas toutes le caractère « → »).
func _arrow() -> Control:
	var arrow := Control.new()
	arrow.custom_minimum_size = Vector2(18, 100)
	arrow.draw.connect(func() -> void:
		var c := Vector2(9, 50)
		arrow.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -3), c + Vector2(1, -3), c + Vector2(1, -7),
			c + Vector2(8, 0), c + Vector2(1, 7), c + Vector2(1, 3), c + Vector2(-6, 3)]), UiTheme.GOLD))
	return arrow


## Portrait animé d'un héros à un stade donné, dans une case de la taille d'une carte.
func _portrait(progress: HeroProgress, stage_index: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(110, 100)
	var portrait := HeroPortrait.new(progress, 1.4)
	portrait.refresh(stage_index)
	portrait.position = Vector2(55, 92)
	box.add_child(portrait)
	return box
