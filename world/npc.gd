class_name Npc
extends Interactable
## Personnage non joueur : parle quand on interagit. Dessiné en attendant de vrais sprites.

@export var speaker := ""  ## Clé de traduction du nom, ex. "NPC_ELDER"
@export var lines: Array[String] = []  ## Clés de traduction des répliques
@export var heals_party := false  ## L'aubergiste soigne l'équipe et propose de sauvegarder
@export var shop_stock: PackedStringArray = []  ## Marchand : objets et équipements en vente
@export var shop_name := "SHOP_TITLE"
@export var robe_color := Color("6b4a8a")
@export var hair_color := Color("d8d2c4")


func _ready() -> void:
	super()
	_add_collision(Vector2(14, 8), Vector2(0, -4))


func interact(_player: Node2D) -> void:
	await Dialogue.say(speaker, lines)
	if heals_party:
		GameState.heal_party()
		AudioManager.play_heal()
		FxLibrary.burst(get_parent(), _player.global_position + Vector2(0, -24), &"heal", Vector2.UP, 1.4)
		await Dialogue.say(speaker, ["DLG_INN_HEALED"])
		if await Dialogue.choose(speaker, "DLG_INN_SAVE", ["YES", "NO"]) == 0:
			var saved := SaveSystem.save_game(_player.global_position)
			await Dialogue.say(speaker, ["DLG_INN_SAVED" if saved else "DLG_INN_SAVE_FAILED"])
	if not shop_stock.is_empty():
		var shop := ShopMenu.new()
		shop.stock = shop_stock
		shop.shop_name = shop_name
		get_tree().current_scene.add_child(shop)
		await shop.closed


## Villageois en pixels : ombre, robe, ceinture, tête, cheveux.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	_ellipse(Vector2(0, 0), Vector2(9, 3), Color(0, 0, 0, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(5, -20), Vector2(-5, -20)]), robe_color)
	draw_rect(Rect2(-5, -12, 10, 2), robe_color.darkened(0.4))
	draw_rect(Rect2(-4, -28, 8, 8), Color("e0b48c"))
	draw_rect(Rect2(-5, -30, 10, 4), hair_color)
	draw_rect(Rect2(-5, -27, 2, 6), hair_color)
	draw_rect(Rect2(3, -27, 2, 6), hair_color)
	draw_rect(Rect2(-2, -25, 1, 1), Color.BLACK)
	draw_rect(Rect2(1, -25, 1, 1), Color.BLACK)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
