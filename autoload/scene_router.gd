extends CanvasLayer
## Changements de scène avec transition (losanges pixelisés).
## - change_map : passer d'une carte à une autre (point d'arrivée nommé) ;
## - start_battle_transition / transition_to : entrer en combat ou en sortir.

const COVER_TIME := 0.45

var _material: ShaderMaterial
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = preload("res://fx/transition.gdshader")
	var rect := ColorRect.new()
	rect.size = Vector2(640, 360)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _material
	add_child(rect)


func is_busy() -> bool:
	return _busy


## Changement immédiat, sans transition.
func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


## Couvre l'écran, change de scène, puis découvre la nouvelle scène.
func transition_to(scene_path: String, flash := false) -> void:
	if _busy:
		return
	_busy = true
	if flash:
		await _flash()
	await _animate(0.0, 1.0)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate(1.0, 0.0)
	_busy = false


## Va sur une autre carte, au point d'arrivée `spawn` (un Marker2D du nœud Spawns).
func change_map(map_path: String, spawn: String) -> void:
	GameState.arrive_at(map_path, spawn)
	transition_to(map_path)


## Flash blanc bref avant d'entrer en combat.
func _flash() -> void:
	_material.set_shader_parameter("cover_color", Color(1, 1, 1, 1))
	_material.set_shader_parameter("progress", 1.0)
	await get_tree().create_timer(0.06, true, false, true).timeout
	_material.set_shader_parameter("progress", 0.0)
	await get_tree().create_timer(0.06, true, false, true).timeout
	_material.set_shader_parameter("cover_color", Color(0, 0, 0, 1))


func _animate(from: float, to: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("progress", value), from, to, COVER_TIME)
	await tween.finished
