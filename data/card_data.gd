class_name CardData
extends Resource
## Une carte à équiper sur un héros : bonus de stats, compétence, effet passif, aide au timing.
## Le joueur possède des exemplaires de cartes (CardInstance) qui ont chacun un rang (1 à 5).

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Effets passifs. Ils se branchent sur des règles de combat qui existent déjà
## (voir BattleManager) : ils ne font que renforcer des gains ou des multiplicateurs.
enum Passive {
	NONE,
	PARRY_AP,  ## PA en plus à chaque parade réussie
	PERFECT_AP,  ## PA en plus quand tous les coups d'une attaque sont parfaits
	COUNTER_POWER,  ## Puissance en plus pour la contre-attaque (ex. 0.5 = +50 %)
	PERFECT_POWER,  ## Dégâts en plus sur un coup parfait (ex. 0.2 = +20 %)
	START_AP,  ## PA en plus au début du combat
}

const MAX_RANK := 5
const STATS := ["max_hp", "attack", "defense", "speed"]
const RARITY_NAMES := ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY"]
const RARITY_COLORS := [Color("9a8f7d"), Color("4f8fd6"), Color("a05ad6"), Color("e8b33c")]

@export var id: StringName
@export var display_name := ""  ## Clé de traduction, ex. "CARD_EPEE_ACIER"
@export var rarity := Rarity.COMMON
@export var for_hero: StringName  ## Réservée à un héros (id), vide = tout le monde
@export var price := 0  ## Prix chez la marchande (0 = pas en vente)
## Illustration : dessin de la carte. Vide = on utilise le sprite de `art_source`, sinon une icône.
@export var art: Texture2D
@export var art_source: CombatantData

@export_group("Stats")
## Bonus au rang 1, puis gain par rang supplémentaire (arrondi vers le bas).
@export var max_hp := 0
@export var attack := 0
@export var defense := 0
@export var speed := 0
@export var max_hp_per_rank := 0.0
@export var attack_per_rank := 0.0
@export var defense_per_rank := 0.0
@export var speed_per_rank := 0.0

@export_group("Effets")
@export var skill: SkillData  ## Compétence donnée au héros qui porte la carte
@export var passive := Passive.NONE
@export var passive_value := 0.0
## Fenêtres de timing élargies de ce nombre de millisecondes (attaque et défense).
@export var timing_bonus_ms := 0.0
@export var timing_bonus_per_rank := 0.0

@export_group("Évolution")
@export var evolves_into: CardData  ## Carte obtenue en faisant évoluer celle-ci au rang max
@export var evolution_material: StringName  ## Matériau nécessaire pour l'évolution


func can_be_used_by(hero_id: StringName) -> bool:
	return for_hero == &"" or for_hero == hero_id


## Bonus d'une stat ("attack", "max_hp"...) au rang donné.
func stat_at_rank(stat: String, rank: int) -> int:
	return floori(get(stat) + get(stat + "_per_rank") * (rank - 1))


func timing_bonus_at_rank(rank: int) -> float:
	return timing_bonus_ms + timing_bonus_per_rank * (rank - 1)


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]
