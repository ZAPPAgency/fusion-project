class_name CombatantData
extends Resource
## Fiche d'un combattant (héros ou ennemi). Modifiable dans l'inspecteur de Godot.

@export var id: StringName
@export var display_name := ""  ## Clé de traduction, ex. "HERO_ALDRIC"
@export var is_enemy := false
@export var placeholder_color := Color.WHITE  ## Couleur du rectangle s'il n'y a pas de sprite

@export_group("Sprite")
@export var sprite_frames: SpriteFrames  ## Généré par tools/build_sprite_frames.gd ; vide = rectangle
@export var sprite_scale := 1.0

@export_group("Stats")
@export var max_hp := 100
@export var attack := 10
@export var defense := 10
@export var speed := 10  ## Plus c'est élevé, plus le combattant joue souvent

@export_group("Progression (héros)")
## Gain de stats à chaque niveau (les décimales s'accumulent : 0.5 = +1 tous les 2 niveaux).
@export var hp_growth := 8.0
@export var attack_growth := 2.0
@export var defense_growth := 1.0
@export var speed_growth := 0.5
## Stades d'évolution (forge) : le premier est la forme de départ. Vide = n'évolue pas.
@export var stages: Array[HeroStage] = []

@export_group("Récompenses (ennemis)")
@export var xp_reward := 10
@export var gold_reward := 5

@export_group("Actions")
@export var basic_attack: SkillData
@export var skills: Array[SkillData] = []
@export_range(0.0, 1.0) var skill_chance := 0.3  ## Ennemis : probabilité d'utiliser une compétence
