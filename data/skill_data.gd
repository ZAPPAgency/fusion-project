class_name SkillData
extends Resource
## Une compétence (l'attaque de base en est une aussi).

## FOE = adversaire de celui qui utilise la compétence, ALLY = son camp.
enum Target { ONE_FOE, ALL_FOES, ONE_ALLY, ALL_ALLIES, SELF }
enum Effect { DAMAGE, HEAL }

@export var id: StringName
@export var display_name := ""  ## Clé de traduction, ex. "SKILL_FRAPPE_BOUCLIER"
@export_multiline var description := ""
@export var target := Target.ONE_FOE
@export var effect := Effect.DAMAGE
@export var power := 1.0  ## Multiplicateur appliqué à l'attaque du lanceur
@export var ap_cost := 0  ## Points d'action dépensés
@export var ap_gain := 0  ## Points d'action gagnés (attaque de base)
@export var unlock_level := 1  ## Niveau du héros à partir duquel la compétence est apprise

## Instants d'impact en secondes, depuis le début de l'animation du coup.
## Plusieurs valeurs = un combo (les dégâts sont répartis entre les coups).
## C'est sur ces instants que le joueur doit appuyer (attaque) ou parer/esquiver (défense).
@export var impact_times: PackedFloat32Array = [0.5]

## Animation jouée pour chaque coup (la liste se répète si le combo est plus long).
## L'animation est lancée pour que son image d'impact tombe pile sur l'instant d'impact.
@export var hit_animations: Array[StringName] = [&"attack1"]

## Vrai : le lanceur court jusqu'à sa cible. Faux : il reste à sa place (sorts, arcs).
@export var melee := true

@export_group("Effets")
## Particules à l'impact : slash, fire, arcane, dark, poison (voir FxLibrary.BURSTS).
@export var impact_fx: StringName = &"slash"
## Projectile lancé à chaque coup (flèche...). Vide = pas de projectile.
@export var projectile: Texture2D
## Durée du vol du projectile (s). Il part pour arriver pile à l'instant d'impact.
@export var projectile_travel := 0.25


func hit_animation(hit_index: int) -> StringName:
	if hit_animations.is_empty():
		return &"attack1"
	return hit_animations[hit_index % hit_animations.size()]
