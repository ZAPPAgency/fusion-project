class_name BattleCamera
extends Camera2D
## Caméra du combat : tremblement (« trauma ») et recadrage sur les compétences.
## Le tremblement utilise le temps réel : il continue pendant les arrêts sur image (hit-stop).

const CENTER := Vector2(320, 180)
const MAX_SHAKE := Vector2(7, 5)  ## Décalage maximum en pixels
const TRAUMA_DECAY := 1.8  ## Trauma perdu par seconde

var _trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _focus_tween: Tween


func _ready() -> void:
	position = CENTER
	_noise.frequency = 0.5


## Ajoute du tremblement (0 = rien, 1 = maximum). Le ressenti est au carré : 0.5 reste léger.
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_time += real_delta
	_trauma = maxf(_trauma - TRAUMA_DECAY * real_delta, 0.0)
	var shake := _trauma * _trauma
	offset = (Vector2(
		_noise.get_noise_2d(_time * 60.0, 0.0),
		_noise.get_noise_2d(0.0, _time * 60.0)
	) * MAX_SHAKE * shake).round()


## Se rapproche d'un point (compétence) : léger zoom et recentrage partiel.
func focus(world_position: Vector2, zoom_amount := 1.12, duration := 0.25) -> void:
	_tween_to(CENTER.lerp(world_position, 0.35), Vector2.ONE * zoom_amount, duration)


func reset_focus(duration := 0.3) -> void:
	_tween_to(CENTER, Vector2.ONE, duration)


func _tween_to(target_position: Vector2, target_zoom: Vector2, duration: float) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "position", target_position, duration)
	_focus_tween.tween_property(self, "zoom", target_zoom, duration)
