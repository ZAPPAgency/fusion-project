class_name HeroPortrait
extends Node2D
## Héros animé (repos) avec l'apparence de son stade d'évolution, pour les menus.
## L'origine est aux pieds. `zoom` agrandit tout (sprite et aura).

var progress: HeroProgress
var sprite: AnimatedSprite2D
var look: HeroLook

var _stage_index := -1


func _init(hero: HeroProgress, zoom := 1.0) -> void:
	progress = hero
	scale = Vector2.ONE * zoom
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = hero.data.sprite_frames
	sprite.centered = false
	sprite.offset = hero.data.sprite_frames.get_meta("feet_offset", Vector2.ZERO)
	sprite.play(&"idle")
	add_child(sprite)
	refresh()


## Montre le stade `stage_index` (par défaut : le stade actuel du héros).
func refresh(stage_index := -1) -> void:
	_stage_index = progress.stage if stage_index < 0 else stage_index
	var stage: HeroStage = progress.data.stages[_stage_index] if _stage_index < progress.data.stages.size() else null
	sprite.material = HeroLook.make_material(stage)
	sprite.scale = Vector2.ONE * progress.data.sprite_scale * (stage.sprite_scale if stage else 1.0)
	if look:
		look.queue_free()
	var body: Vector2 = progress.data.sprite_frames.get_meta("body_size", Vector2(20, 40)) * sprite.scale
	look = HeroLook.attach(sprite, stage, body)


## Joue une animation une fois (ex. "attack1"), puis revient au repos.
func play_once(anim: StringName) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		return
	sprite.play(anim)
	await sprite.animation_finished
	if is_instance_valid(sprite):
		sprite.play(&"idle")


## Fait virer le sprite au blanc (0 à 1), pour la cinématique d'évolution.
func set_flash(amount: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", amount)
