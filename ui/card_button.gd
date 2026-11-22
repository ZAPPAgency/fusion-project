class_name CardButton
extends Button
## Bouton qui affiche une carte (CardView) : un cadre doré l'entoure quand il est sélectionné.
## `focused` est émis quand la carte est sélectionnée, pour afficher ses détails à côté.

signal focused(card: CardInstance)

var view: CardView


func _init(card: CardInstance = null, locked_level := 0, count := 1) -> void:
	view = CardView.new(card, locked_level)
	view.position = Vector2(2, 2)
	add_child(view)
	custom_minimum_size = CardView.SIZE + Vector2(4, 4)
	focus_mode = Control.FOCUS_ALL
	disabled = locked_level > 0
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.draw_center = false
	outline.set_border_width_all(2)
	outline.border_color = UiTheme.GOLD
	add_theme_stylebox_override("focus", outline)
	focus_entered.connect(func() -> void: focused.emit(view.card))
	UiFeedback.attach(self, view, true)  # la carte saute quand on la sélectionne, tremble quand on la choisit
	if count > 1:
		var badge := Label.new()
		badge.text = "x%d" % count
		badge.add_theme_font_size_override("font_size", 8)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.position = Vector2(CardView.SIZE.x - 18, CardView.SIZE.y - 12)
		add_child(badge)


## Regroupe les exemplaires identiques et libres (même carte, même rang) pour n'afficher
## qu'un bouton « x3 ». Les cartes équipées restent seules. Renvoie une liste de groupes.
static func group(cards: Array) -> Array[Array]:
	var groups: Array[Array] = []
	var by_key := {}
	for card: CardInstance in cards:
		if GameState.owner_of(card) != null:
			groups.append([card])
			continue
		var key := "%s:%d" % [card.data.id, card.rank]
		if not by_key.has(key):
			by_key[key] = []
			groups.append(by_key[key])
		by_key[key].append(card)
	return groups
