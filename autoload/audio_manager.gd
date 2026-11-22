extends Node
## Musiques et effets sonores.
## En attendant de vrais bruitages, les sons sont synthétisés en code (bruit + ondes),
## une seule fois puis gardés en mémoire.

const MIX_RATE := 22050
const PLAYER_COUNT := 10

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _sounds := {}  # nom -> AudioStreamWAV
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # les sons jouent aussi dans les menus (jeu en pause)
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Indice sonore juste avant un coup : petit « ting » clair.
func play_cue() -> void:
	_play("cue", 0.06, func(t: float) -> float: return sin(TAU * 1500.0 * t) * exp(-t * 60.0), -10.0)


## Sélection dans un menu : « tic » très court et discret.
func play_tick() -> void:
	_play("tick", 0.03, func(t: float) -> float: return sin(TAU * 2400.0 * t) * exp(-t * 160.0) * 0.5, -20.0)


## Coup qui porte : choc sourd + bruit.
func play_hit() -> void:
	_play("hit", 0.18, func(t: float) -> float:
		return (sin(TAU * 90.0 * t) * 0.8 + _rng.randf_range(-1.0, 1.0) * 0.6) * exp(-t * 25.0), -4.0, true)


## Parade : tintement métallique (fréquences non harmoniques, comme une lame).
func play_parry() -> void:
	_play("parry", 0.4, func(t: float) -> float:
		var ring := sin(TAU * 1850.0 * t) + sin(TAU * 2770.0 * t) * 0.6 + sin(TAU * 4120.0 * t) * 0.4
		return ring * 0.4 * exp(-t * 9.0) + _rng.randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.5, -5.0)


## Esquive : souffle d'air.
func play_dodge() -> void:
	_play("dodge", 0.2, func(t: float) -> float:
		return _rng.randf_range(-1.0, 1.0) * sin(PI * t / 0.2) * 0.5, -10.0)


## Coup parfait : carillon brillant en deux notes.
func play_perfect() -> void:
	_play("perfect", 0.3, func(t: float) -> float:
		var note := 1320.0 if t < 0.07 else 1760.0
		return sin(TAU * note * t) * exp(-fmod(t, 0.07) * 4.0 - t * 8.0) * 0.6, -8.0)


## Soin : arpège montant et doux.
func play_heal() -> void:
	_play("heal", 0.45, func(t: float) -> float:
		var note := 660.0 if t < 0.12 else (880.0 if t < 0.24 else 1320.0)
		return sin(TAU * note * t) * exp(-fmod(t, 0.12) * 6.0) * 0.45, -10.0)


## Mort : grondement qui s'éteint, comme des cendres qui s'effondrent.
func play_death() -> void:
	_play("death", 0.6, func(t: float) -> float:
		return (_rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 55.0 * t) * 0.5) * exp(-t * 6.0), -8.0, true)


func _play(sound_name: String, duration: float, wave: Callable, volume_db: float, low_pass := false) -> void:
	if not _sounds.has(sound_name):
		_sounds[sound_name] = _synthesize(duration, wave, low_pass)
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % PLAYER_COUNT
	player.stream = _sounds[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(0.94, 1.06)  # légère variation à chaque fois
	player.play()


## `wave(t)` donne l'échantillon (entre -1 et 1) au temps t en secondes.
## `low_pass` adoucit le bruit (sons graves).
func _synthesize(duration: float, wave: Callable, low_pass: bool) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var previous := 0.0
	for i in sample_count:
		var sample: float = wave.call(float(i) / MIX_RATE)
		if low_pass:
			sample = lerpf(previous, sample, 0.25)
			previous = sample
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
