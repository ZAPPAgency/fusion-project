class_name GameMap
extends Node2D
## Une carte d'exploration. Place le joueur (au point d'arrivée ou à sa position
## d'avant le combat), crée l'ambiance et affiche le nom du lieu.
##
## Structure attendue de la scène :
##   Ground (TileMapLayer) : le sol et les obstacles (eau, murs)
##   Objects (Node2D, tri en Y) : arbres, maisons, PNJ, coffres, ennemis ; le joueur y est ajouté
##   Spawns (Node2D) : points d'arrivée (Marker2D) ; "start" = arrivée par défaut

@export var map_name := ""  ## Clé de traduction affichée en arrivant, ex. "MAP_FOREST"
@export var ambience := Color(0.6, 0.64, 0.82)  ## Teinte de nuit
@export var fireflies := false  ## Lucioles (forêt)
@export var atmosphere := Atmosphere.Preset.VILLAGE  ## Brume, nuages, particules du lieu (voir Atmosphere)

@onready var _ground: TileMapLayer = $Ground
@onready var _objects: Node2D = $Objects
@onready var _spawns: Node2D = $Spawns


func _ready() -> void:
	GameState.current_map = scene_file_path
	FxLibrary.add_night_ambience(self, ambience)
	_add_atmosphere()

	var player := Player.new()
	player.position = _start_position()
	_objects.add_child(player)
	var tile_size := Vector2(_ground.tile_set.tile_size)
	var used := _ground.get_used_rect()
	player.set_camera_limits(Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size))
	_play_autoplay(player)

	if GameState.player_position == null:
		_show_map_name()
	_add_hud_buttons(player)
	_show_first_tip()


## Boutons cliquables en haut à droite : menu et changement de héros (pour jouer à la souris).
## Ils ne prennent jamais le focus : Espace sert toujours à parler aux PNJ.
func _add_hud_buttons(player: Player) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.theme = UiTheme.get_theme()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.position = Vector2(0, 4)
	bar.size = Vector2(634, 18)
	layer.add_child(bar)
	for entry in [["HUD_SWITCH", player.switch_leader], ["HUD_MENU", _open_menu]]:
		var button := UiTheme.button(tr(entry[0]), entry[1])
		button.focus_mode = Control.FOCUS_NONE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.05, 0.05, 0.09, 0.7)
		background.set_content_margin_all(3)
		background.content_margin_left = 6
		background.content_margin_right = 6
		button.add_theme_stylebox_override("normal", background)
		bar.add_child(button)


func _open_menu() -> void:
	if not Dialogue.is_open() and not SceneRouter.is_busy() and not get_tree().paused:
		add_child(PauseMenu.new())


## Tab / Start : menu de pause.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not Dialogue.is_open() and not SceneRouter.is_busy() and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_open_menu()


func _start_position() -> Vector2:
	if GameState.player_position != null:
		return GameState.player_position
	var marker := _spawns.get_node_or_null(GameState.spawn_name) as Marker2D
	if marker == null:
		marker = _spawns.get_node("start")
	return marker.position


func _show_map_name() -> void:
	if map_name == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var label := Label.new()
	label.text = tr(map_name)
	label.size = Vector2(640, 30)
	label.position = Vector2(0, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.6).set_delay(0.4)
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(layer.queue_free)


## Démo (`-- --autoplay`) : le joueur suit le chemin défini par les marqueurs "auto_1", "auto_2"...
func _play_autoplay(player: Player) -> void:
	if not "--autoplay" in OS.get_cmdline_user_args():
		return
	var index := GameState.autoplay_step + 1  # reprend là où la démo s'était arrêtée (après un combat)
	while _spawns.has_node("auto_%d" % index):
		player.auto_path.append(_spawns.get_node("auto_%d" % index).position)
		index += 1


## Première carte : comment se déplacer, parler, ouvrir le menu (une fois le nom du lieu affiché).
func _show_first_tip() -> void:
	if GameState.seen_tips.has(&"map"):
		return
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree() and not Dialogue.is_open() and not get_tree().paused:
		Tutorial.show_tip(&"map")


## Ambiance du lieu, placée juste après le sol : la brume passe sous les personnages.
func _add_atmosphere() -> void:
	var tile_size := Vector2(_ground.tile_set.tile_size)
	var used := _ground.get_used_rect()
	var look := Atmosphere.new()
	look.setup(atmosphere, Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size), _ground, fireflies)
	add_child(look)
	move_child(look, _ground.get_index() + 1)
