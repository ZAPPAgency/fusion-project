class_name Chest
extends Interactable
## Coffre : donne un objet une seule fois (mémorisé dans GameState.opened_chests).

@export var chest_id := ""
@export var item_id: StringName = &"potion"  ## Objet ou équipement (id du fichier dans data/)
@export var amount := 1

var _opened := false


func _ready() -> void:
	super()
	_add_collision(Vector2(22, 12), Vector2(0, -6))
	_opened = GameState.opened_chests.has(chest_id)


func interact(_player: Node2D) -> void:
	if _opened:
		await Dialogue.say("", ["CHEST_EMPTY"])
		return
	_opened = true
	GameState.opened_chests[chest_id] = true
	GameState.add_loot(item_id, amount)
	queue_redraw()
	AudioManager.play_perfect()
	FxLibrary.burst(get_parent(), global_position + Vector2(0, -14), &"parry", Vector2.UP, 0.7)
	var loot: Resource = GameState.loot_data(item_id)
	await Dialogue.say("", [tr("CHEST_FOUND").format({"item": tr(loot.display_name), "count": amount})])


## Coffre en bois cerclé d'or ; ouvert, le couvercle est relevé.
func _draw() -> void:
	draw_rect(Rect2(-12, -2, 24, 3), Color(0, 0, 0, 0.35))
	var wood := Color("7a4a26")
	var gold := Color(1.6, 1.25, 0.5)  # brille légèrement avec le glow
	draw_rect(Rect2(-11, -12, 22, 12), wood)
	draw_rect(Rect2(-11, -12, 22, 2), wood.darkened(0.3))
	draw_rect(Rect2(-11, -7, 22, 1), gold)
	if _opened:
		draw_rect(Rect2(-11, -20, 22, 5), wood.lightened(0.1))
		draw_rect(Rect2(-9, -14, 18, 2), Color(0.1, 0.07, 0.05))
	else:
		draw_rect(Rect2(-11, -17, 22, 5), wood.lightened(0.15))
		draw_rect(Rect2(-2, -10, 4, 4), gold)
