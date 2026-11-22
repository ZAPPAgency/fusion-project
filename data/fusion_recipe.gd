class_name FusionRecipe
extends Resource
## Recette de la forge : deux cartes (fusion) ou seulement des matériaux (fabrication)
## donnent une nouvelle carte, au rang 1.

@export var card_a: CardData  ## Vide = fabrication à partir de matériaux seuls
@export var card_b: CardData
@export var materials := {}  # id de matériau (StringName) -> quantité
@export var gold := 0
@export var result: CardData


func is_crafting() -> bool:
	return card_a == null
