extends SceneTree
## Construit les animations (SpriteFrames .tres) des personnages à partir de leurs images.
##
## Pour chaque dossier assets/sprites/<nom>/ qui contient un fichier sprite.json :
##   - lit les animations décrites (bandes horizontales d'images, ou dossiers d'images),
##   - mesure la silhouette sur la 1re image de "idle" (position des pieds, hauteur),
##   - écrit assets/sprites/<nom>/sprite_frames.tres.
##
## Lancer (après avoir importé les images dans Godot) :
##   Godot --headless --path . -s tools/build_sprite_frames.gd
##
## Exemple de sprite.json :
## {
##   "frame_size": [150, 150],            (facultatif : sinon images carrées de la hauteur de la bande)
##   "faces_left": false,                 (facultatif : le dessin original regarde à gauche)
##   "hover": 18,                         (facultatif : créature volante, hauteur au-dessus du sol)
##   "animations": {
##     "idle":    {"source": "Idle.png", "fps": 8, "loop": true},
##     "attack1": {"source": "Attack1.png", "fps": 12, "impact_frame": 4},
##     "hurt":    {"source": "Take Hit"}    (un dossier d'images numérotées marche aussi)
##   }
## }
## "impact_frame" = numéro (à partir de 0) de l'image où le coup touche : le QTE est calé dessus.

const SPRITES_DIR := "res://assets/sprites"


func _initialize() -> void:
	for folder in DirAccess.get_directories_at(SPRITES_DIR):
		var dir := SPRITES_DIR.path_join(folder)
		var config_path := dir.path_join("sprite.json")
		if FileAccess.file_exists(config_path):
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
			_build(dir, config)
	quit()


func _build(dir: String, config: Dictionary) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var impact_frames := {}

	for anim_name: String in config.animations:
		var anim: Dictionary = config.animations[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, anim.get("fps", 10))
		frames.set_animation_loop(anim_name, anim.get("loop", false))
		for texture in _load_frames(dir.path_join(anim.source), anim.get("frame_size", config.get("frame_size", []))):
			frames.add_frame(anim_name, texture)
		if anim.has("impact_frame"):
			impact_frames[anim_name] = int(anim.impact_frame)

	# La silhouette est mesurée sur l'image de repos : le sprite sera placé les pieds sur l'origine.
	var silhouette := frames.get_frame_texture(&"idle", 0).get_image().get_used_rect()
	var hover: float = config.get("hover", 0)  # créatures volantes : hauteur au-dessus du sol
	frames.set_meta("feet_offset", -Vector2(silhouette.get_center().x, silhouette.end.y + hover))
	frames.set_meta("body_size", Vector2(silhouette.size) + Vector2(0, hover))
	frames.set_meta("faces_left", config.get("faces_left", false))
	frames.set_meta("impact_frames", impact_frames)
	if config.has("weapon_point"):
		frames.set_meta("weapon_point", Vector2(config.weapon_point[0], config.weapon_point[1]))

	var output := dir.path_join("sprite_frames.tres")
	var error := ResourceSaver.save(frames, output)
	print("%s : %d animations, silhouette %s → %s" % [output, frames.get_animation_names().size(), silhouette.size, "OK" if error == OK else "ERREUR %d" % error])


## Une bande horizontale (fichier .png) ou un dossier d'images (triées par numéro).
func _load_frames(source: String, frame_size: Array) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if DirAccess.dir_exists_absolute(source):
		var files := Array(DirAccess.get_files_at(source)).filter(func(file: String) -> bool: return file.ends_with(".png"))
		files.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		for file in files:
			textures.append(load(source.path_join(file)))
		return textures

	var strip: Texture2D = load(source)
	var size := Vector2(strip.get_height(), strip.get_height())
	if frame_size.size() == 2:
		size = Vector2(frame_size[0], frame_size[1])
	var columns := int(strip.get_width() / size.x)
	var rows := int(strip.get_height() / size.y)
	for row in rows:
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = strip
			atlas.region = Rect2(Vector2(column, row) * size, size)
			if not _is_empty(atlas):
				textures.append(atlas)
	return textures


## Ignore les cases vides en fin de planche.
func _is_empty(texture: Texture2D) -> bool:
	return texture.get_image().get_used_rect().size == Vector2i.ZERO
