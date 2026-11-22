class_name Forge
extends RefCounted
## Règles de la forge, sans affichage : améliorer, fusionner, fabriquer, faire évoluer.
## Chaque action vérifie qu'elle est possible, paie son coût (or + matériaux dans GameState)
## puis modifie la collection. Elle renvoie false / null si elle est impossible.
##
## Un coût est un dictionnaire : {"gold": 120, "materials": {&"eclat_cloche": 2}}.

const UPGRADE_GOLD := 15  ## Or par rang et par niveau de rareté pour une amélioration
const EVOLUTION_GOLD := 60  ## Or par niveau de rareté pour faire évoluer une carte

static var _recipes: Array[FusionRecipe] = []


# --- Coûts -------------------------------------------------------------------------

static func can_pay(cost: Dictionary) -> bool:
	if GameState.gold < cost.get("gold", 0):
		return false
	var materials: Dictionary = cost.get("materials", {})
	for material_id in materials:
		if GameState.material_count(material_id) < materials[material_id]:
			return false
	return true


static func pay(cost: Dictionary) -> void:
	GameState.gold -= cost.get("gold", 0)
	var materials: Dictionary = cost.get("materials", {})
	for material_id in materials:
		GameState.materials[material_id] = GameState.material_count(material_id) - materials[material_id]


# --- Amélioration avec des matériaux ------------------------------------------------

## Monter d'un rang coûte plus cher pour les rangs élevés et les cartes rares.
static func upgrade_cost(card: CardInstance) -> Dictionary:
	var rarity: int = card.data.rarity
	var materials := {&"fragment_cendre": card.rank + rarity * 2}
	if rarity > CardData.Rarity.COMMON:
		materials[&"minerai_fer"] = rarity * card.rank
	return {"gold": UPGRADE_GOLD * card.rank * (rarity + 1), "materials": materials}


static func can_upgrade(card: CardInstance) -> bool:
	return not card.is_max_rank() and can_pay(upgrade_cost(card))


static func upgrade(card: CardInstance) -> bool:
	if not can_upgrade(card):
		return false
	pay(upgrade_cost(card))
	card.rank += 1
	return true


# --- Fusion de doublons -------------------------------------------------------------

## Autres exemplaires de la même carte au même rang (les cartes libres d'abord).
static func duplicates_of(card: CardInstance) -> Array[CardInstance]:
	var found: Array[CardInstance] = []
	for other in GameState.cards:
		if other != card and other.data == card.data and other.rank == card.rank:
			found.append(other)
	found.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return GameState.owner_of(a) == null and GameState.owner_of(b) != null)
	return found


## Deux exemplaires identiques (même rang) → un seul, un rang au-dessus. Gratuit.
static func merge_duplicates(card: CardInstance, other: CardInstance) -> bool:
	if card == other or card.data != other.data or card.rank != other.rank or card.is_max_rank():
		return false
	GameState.remove_card(other)
	card.rank += 1
	return true


# --- Recettes : fusion de deux cartes et fabrication ------------------------------------

## Toutes les recettes du jeu (fichiers de data/recipes).
static func recipes() -> Array[FusionRecipe]:
	if _recipes.is_empty():
		for file in ResourceLoader.list_directory("res://data/recipes"):
			_recipes.append(load("res://data/recipes/" + file))
	return _recipes


static func recipe_cost(recipe: FusionRecipe) -> Dictionary:
	return {"gold": recipe.gold, "materials": recipe.materials}


## Cartes que la recette consommerait : un exemplaire de chaque, libre et de rang faible
## de préférence. Vide s'il en manque une (ou pour une fabrication).
static func ingredients(recipe: FusionRecipe) -> Array[CardInstance]:
	var chosen: Array[CardInstance] = []
	if recipe.is_crafting():
		return chosen
	for wanted in [recipe.card_a, recipe.card_b]:
		var best: CardInstance = null
		for card in GameState.cards:
			if card.data != wanted or card in chosen:
				continue
			if best == null or _cheaper_ingredient(card, best):
				best = card
		if best == null:
			chosen.clear()
			return chosen
		chosen.append(best)
	return chosen


static func can_fuse(recipe: FusionRecipe) -> bool:
	if not can_pay(recipe_cost(recipe)):
		return false
	return recipe.is_crafting() or ingredients(recipe).size() == 2


## Fusion (ou fabrication) : consomme les cartes et le coût, renvoie la nouvelle carte.
static func fuse(recipe: FusionRecipe) -> CardInstance:
	if not can_fuse(recipe):
		return null
	for card in ingredients(recipe):
		GameState.remove_card(card)
	pay(recipe_cost(recipe))
	return GameState.add_card(recipe.result.id)


static func _cheaper_ingredient(a: CardInstance, b: CardInstance) -> bool:
	var a_free := GameState.owner_of(a) == null
	var b_free := GameState.owner_of(b) == null
	if a_free != b_free:
		return a_free
	return a.rank < b.rank


# --- Évolution des cartes -----------------------------------------------------------

static func evolution_cost(card: CardInstance) -> Dictionary:
	var materials := {}
	if card.data.evolution_material != &"":
		materials[card.data.evolution_material] = card.data.evolution_material_count
	return {"gold": EVOLUTION_GOLD * (card.data.rarity + 1), "materials": materials}


static func can_evolve(card: CardInstance) -> bool:
	return card.data.evolves_into != null and card.is_max_rank() and can_pay(evolution_cost(card))


## La carte devient sa forme évoluée, au rang 1. Elle reste équipée là où elle était.
static func evolve(card: CardInstance) -> bool:
	if not can_evolve(card):
		return false
	pay(evolution_cost(card))
	card.data = card.data.evolves_into
	card.rank = 1
	return true


# --- Évolution des héros ------------------------------------------------------------

static func hero_evolution_cost(progress: HeroProgress) -> Dictionary:
	var next := progress.next_stage_data()
	if next == null:
		return {}
	return {"gold": next.gold, "materials": next.materials}


static func can_evolve_hero(progress: HeroProgress) -> bool:
	var next := progress.next_stage_data()
	return next != null and progress.level >= next.required_level and can_pay(hero_evolution_cost(progress))


static func evolve_hero(progress: HeroProgress) -> bool:
	if not can_evolve_hero(progress):
		return false
	pay(hero_evolution_cost(progress))
	progress.evolve()
	return true
