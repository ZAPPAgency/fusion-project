extends Node2D
## Vitrine des effets : rejoue tous les effets de combat l'un après l'autre,
## pour les régler sans lancer de vrai combat.
## Lancer : Godot --path . res://tests/visual/fx_showcase.tscn

const STEP := 0.9  ## Pause entre deux effets (s)

@onready var _fx: BattleFx = $Fx
@onready var _units: Node2D = $Units

var _hero: UnitView
var _enemy: UnitView
var _label: Label


func _ready() -> void:
	_hero = _spawn("res://data/characters/aldric.tres", Vector2(250, 240))
	_enemy = _spawn("res://data/enemies/squelette.tres", Vector2(390, 240))
	_label = Label.new()
	_label.position = Vector2(0, 40)
	_label.size = Vector2(640, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Hud.add_child(_label)
	_play_all()


func _play_all() -> void:
	await _wait(0.5)
	for preset in [&"slash", &"fire", &"arcane", &"dark", &"poison"]:
		_show("Impact : %s" % preset)
		_fx.impact(_enemy.center(), preset, 1.15)
		_enemy.show_hit(12, FxLibrary.tint(preset))
		await _wait(STEP)

	_show("Coup parfait")
	_fx.impact(_enemy.center(), &"slash", 1.5)
	_fx.big_hit(_enemy.center())
	_enemy.show_hit(30)
	await _wait(STEP)

	_show("Parade")
	_hero.play_parry()
	_fx.parry(_hero.center(), _enemy.center())
	await _wait(STEP)

	_show("Esquive")
	_hero.play_dodge()
	await _wait(STEP)

	_show("Héros touché")
	_fx.impact(_hero.center(), &"dark", 1.1)
	_fx.hero_hurt()
	_hero.show_hit(15, FxLibrary.tint(&"dark"))
	await _wait(STEP)

	_show("Soin")
	_hero.show_heal(20)
	await _wait(STEP)

	_show("Mort (cendres)")
	_enemy.unit.take_damage(9999)
	await _wait(3.0)
	get_tree().quit()


func _spawn(data_path: String, at: Vector2) -> UnitView:
	var view := UnitView.new()
	_units.add_child(view)
	view.setup(BattleUnit.new(load(data_path)), at)
	return view


func _show(text: String) -> void:
	_label.text = text


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
