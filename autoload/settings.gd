extends Node
## Réglages du joueur : difficulté, fenêtres de timing des QTE, latence, langue, plein écran,
## qualité des effets. Sauvegardés dans user://settings.cfg.

signal quality_changed

enum Difficulty { EASY, NORMAL, HARD }
## Qualité des effets du décor (brume, rayons de lune, particules). Le combat et ses effets
## d'impact restent identiques ; seul le décor s'allège pour les petites machines.
enum Quality { LOW, MEDIUM, HIGH }

const SETTINGS_PATH := "user://settings.cfg"

## Taille de l'image du jeu. La fenêtre en est un multiple (×2, ×3, ×4...) ;
## le texte et les effets sont dessinés à la vraie résolution de l'écran, donc restent nets.
const BASE_SIZE := Vector2i(640, 360)

## Fenêtres de timing en millisecondes AVANT l'impact.
## Après l'impact, elles sont deux fois plus courtes (voir TimingJudge.LATE_RATIO).
## Exemple : "parry": 80 → la parade réussit entre 80 ms avant et 40 ms après l'impact.
const TIMING_WINDOWS := {
	Difficulty.EASY: {"perfect": 90, "good": 180, "parry": 120, "dodge": 220},
	Difficulty.NORMAL: {"perfect": 60, "good": 130, "parry": 80, "dodge": 160},
	Difficulty.HARD: {"perfect": 40, "good": 90, "parry": 50, "dodge": 110},
}

## Indice visuel avant chaque coup : délai avant l'impact (ms) et taille du reflet.
const CUES := {
	Difficulty.EASY: {"lead_ms": 400, "size": 1.6},
	Difficulty.NORMAL: {"lead_ms": 300, "size": 1.0},
	Difficulty.HARD: {"lead_ms": 250, "size": 0.7},
}

const DIFFICULTY_NAMES := ["DIFF_EASY", "DIFF_NORMAL", "DIFF_HARD"]
const QUALITY_NAMES := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]
## Part des particules du décor gardée à chaque qualité.
const PARTICLE_FACTOR := [0.35, 0.7, 1.0]

var difficulty := Difficulty.NORMAL

## Décalage pour compenser la latence de l'écran ou de la manette (mesuré par la calibration).
## Positif = le joueur appuie naturellement en retard.
var latency_offset_ms := 0

var fullscreen := false

## Par défaut : moyenne dans un navigateur (souvent un ordinateur portable), haute sinon.
var quality := Quality.MEDIUM if OS.has_feature("web") else Quality.HIGH

var _toast: CanvasLayer

var language := "fr":
	set(value):
		language = value
		TranslationServer.set_locale(value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # F11 marche aussi quand le jeu est en pause
	_load_settings()
	TranslationServer.set_locale(language)
	apply_window()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		fullscreen = not fullscreen
		apply_window()
		save_settings()
	elif event.is_action_pressed("graphics_quality"):
		cycle_quality()
		_show_toast(tr("QUALITY_LABEL").format({"name": quality_name()}))


func quality_name() -> String:
	return tr(QUALITY_NAMES[quality])


func cycle_quality() -> void:
	quality = (quality + 1) % Quality.size() as Quality
	save_settings()
	quality_changed.emit()


## Nombre de particules d'un effet de décor selon la qualité (au moins 1).
func particles(amount: int) -> int:
	return maxi(1, roundi(amount * PARTICLE_FACTOR[quality]))


## Petit message en bas de l'écran (ex. après F3), qui s'efface tout seul.
func _show_toast(text: String) -> void:
	if _toast:
		_toast.queue_free()
	_toast = CanvasLayer.new()
	_toast.layer = 90
	add_child(_toast)
	var label := Label.new()
	label.text = text
	label.size = Vector2(640, 20)
	label.position = Vector2(0, 326)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_toast.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)


## Plein écran, ou la plus grande fenêtre (multiple de 640×360) qui tient dans l'écran.
func apply_window() -> void:
	# Pas de fenêtre à régler : tests sans écran, jeu intégré à l'éditeur, enregistrement vidéo.
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor() or Engine.get_write_movie_path() != "":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if OS.has_feature("web"):  # dans un navigateur, le jeu remplit déjà la page
		return
	var screen := DisplayServer.screen_get_usable_rect()
	var room := Vector2i(screen.size * 0.9)  # garde de la place pour la barre de titre
	var factor := maxi(1, mini(room.x / BASE_SIZE.x, room.y / BASE_SIZE.y))
	var size := BASE_SIZE * factor
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func current_windows() -> Dictionary:
	return TIMING_WINDOWS[difficulty]


func cue_lead_ms() -> float:
	return CUES[difficulty].lead_ms


func cue_size() -> float:
	return CUES[difficulty].size


func difficulty_name() -> String:
	return tr(DIFFICULTY_NAMES[difficulty])


func cycle_difficulty() -> void:
	difficulty = (difficulty + 1) % Difficulty.size() as Difficulty
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "latency_offset_ms", latency_offset_ms)
	config.set_value("game", "language", language)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "quality", quality)
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	difficulty = config.get_value("game", "difficulty", difficulty)
	latency_offset_ms = config.get_value("game", "latency_offset_ms", latency_offset_ms)
	language = config.get_value("game", "language", language)
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	quality = clampi(config.get_value("display", "quality", quality), 0, Quality.size() - 1) as Quality
