class_name HeroStage
extends Resource
## Un stade d'évolution d'un héros (1 = forme de départ, puis 2 et 3 après la forge).
## Les bonus sont comptés depuis la forme de départ (pas cumulés d'un stade à l'autre).

## Élément de l'aura du dernier stade : lumière, feu, foudre (ailes, sol, particules)
## ou glas (le Gardien : ondes de cloche, sans ailes).
enum AuraElement { NONE, LIGHT, FIRE, LIGHTNING, BELL }

@export var title := ""  ## Clé de traduction, ex. "STAGE_ALDRIC_2" (« Paladin de cendre »)

@export_group("Bonus")
@export var max_hp := 0
@export var attack := 0
@export var defense := 0
@export var speed := 0
@export var skill: SkillData  ## Compétence apprise en atteignant ce stade

@export_group("Conditions")
@export var required_level := 1
@export var gold := 0
@export var materials := {}  # id de matériau (StringName) -> quantité

@export_group("Apparence")
## Recoloration des couleurs vives dont la teinte est entre hue_min et hue_max (0 à 1).
@export var recolor_hue_min := 0.0
@export var recolor_hue_max := 0.0
@export var recolor_hue_target := 0.0
@export var recolor_saturation := 1.0
@export var recolor_value := 1.0
## Teinte des parties grises (armure, métal) : 0 = inchangé, 1 = entièrement teinté.
@export var metal_tint := Color.WHITE
@export var metal_amount := 0.0
## Contour lumineux (alpha = force) et aura : 0 = aucune, 1 = étincelles, 2 = ailes et auréole.
@export var outline_color := Color(0, 0, 0, 0)
@export var aura_color := Color.WHITE
@export var aura_level := 0
@export var aura_element := AuraElement.NONE
@export var sprite_scale := 1.0
