class_name ShopMenu
extends CanvasLayer
## Boutique : liste des articles avec leur prix ; Espace pour acheter, Échap pour partir.
## Utilisation : var shop := ShopMenu.new(); shop.stock = [...]; add_child(shop); await shop.closed

signal closed

var stock: PackedStringArray = []  ## Identifiants des objets / équipements en vente
var shop_name := ""  ## Clé de traduction du titre

var _list: VBoxContainer
var _gold: Label
var _details: Label


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

	var panel := PanelContainer.new()
	panel.position = Vector2(110, 30)
	panel.custom_minimum_size = Vector2(420, 300)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiTheme.label(tr(shop_name), UiTheme.GOLD, 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold = UiTheme.label("", UiTheme.GOLD)
	header.add_child(_gold)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_list)
	_details = UiTheme.label("", UiTheme.DIM)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(400, 28)
	box.add_child(_details)
	box.add_child(UiTheme.label(tr("SHOP_HINT"), UiTheme.DIM))

	_fill()
	UiTheme.focus_first(_list)


func _fill() -> void:
	_gold.text = "%s : %d" % [tr("GOLD"), GameState.gold]
	UiTheme.clear(_list)
	for loot_id in stock:
		var loot: Resource = GameState.loot_data(loot_id)
		var line := "%s   %d %s" % [tr(loot.display_name), loot.price, tr("GOLD_SHORT")]
		var button := UiTheme.button(line, _buy.bind(StringName(loot_id)), GameState.gold >= loot.price)
		button.focus_entered.connect(_describe.bind(loot))
		_list.add_child(button)


## Détail de l'article sélectionné : effet et quantité déjà possédée.
func _describe(loot: Resource) -> void:
	var owned := 0
	var effect := ""
	if loot is EquipmentData:
		owned = GameState.equipment_bag.get(loot.id, 0)
		effect = loot.bonus_text()
		if loot.for_hero != &"":
			effect += "   (%s)" % tr(GameState.progress_of(load("res://data/characters/%s.tres" % loot.for_hero)).data.display_name)
	else:
		owned = GameState.inventory.get(loot.id, 0)
		if loot.heal_amount > 0:
			effect = "+%d %s" % [loot.heal_amount, tr("HP_SHORT")]
		if loot.ap_amount > 0:
			effect = "+%d %s" % [loot.ap_amount, tr("AP_SHORT")]
	_details.text = "%s\n%s : %d" % [effect, tr("SHOP_OWNED"), owned]


func _buy(loot_id: StringName) -> void:
	if not GameState.buy(loot_id):
		return
	AudioManager.play_perfect()
	var focused_index := 0
	for i in _list.get_child_count():
		if _list.get_child(i).has_focus():
			focused_index = i
	_fill()
	# Garde la sélection au même endroit (ou sur le premier article encore achetable).
	var button: Button = _list.get_child(focused_index)
	if button.disabled:
		UiTheme.focus_first(_list)
	else:
		button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		FxLibrary.set_scene_glow(get_tree(), true)
		closed.emit()
		queue_free()
