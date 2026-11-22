extends Node
## Déclare les actions du jeu pour le clavier et la manette.
## Les touches du clavier sont « physiques » : elles gardent la même position
## en AZERTY et en QWERTY (KEY_W = la touche Z sur un clavier AZERTY, KEY_Q = la touche A).
## Les menus utilisent les actions intégrées de Godot (ui_accept, ui_cancel, ui_up...).

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"confirm": [KEY_SPACE, KEY_ENTER],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"parry": [KEY_E],
	"dodge": [KEY_Q],
	"menu": [KEY_TAB],
	"switch_leader": [KEY_R],
	"fullscreen": [KEY_F11],
}

const PAD_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"confirm": [JOY_BUTTON_A],
	"cancel": [JOY_BUTTON_B],
	"parry": [JOY_BUTTON_RIGHT_SHOULDER],
	"dodge": [JOY_BUTTON_LEFT_SHOULDER],
	"menu": [JOY_BUTTON_START],
	"switch_leader": [JOY_BUTTON_Y],
}

## Souris : clic gauche pour valider, attaquer au bon moment et parer ;
## clic droit pour esquiver et revenir en arrière dans les menus.
## (Sur la carte, le clic gauche sert aussi à se déplacer : voir Player.)
const MOUSE_BUTTONS := {
	"confirm": [MOUSE_BUTTON_LEFT],
	"parry": [MOUSE_BUTTON_LEFT],
	"dodge": [MOUSE_BUTTON_RIGHT],
	"ui_cancel": [MOUSE_BUTTON_RIGHT],
}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "MOUSE_LEFT", MOUSE_BUTTON_RIGHT: "MOUSE_RIGHT"}

## Stick gauche : [axe, direction].
const PAD_STICK := {
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
}

const STICK_DEADZONE := 0.3

## Noms des boutons de manette (style Xbox) pour les indications à l'écran.
const PAD_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_Y: "Y",
}


func _ready() -> void:
	for action in KEYS:
		_ensure_action(action)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

	for action in PAD_BUTTONS:
		_ensure_action(action)
		for button in PAD_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)

	for action in PAD_STICK:
		_ensure_action(action)
		var event := InputEventJoypadMotion.new()
		event.axis = PAD_STICK[action][0]
		event.axis_value = PAD_STICK[action][1]
		InputMap.action_add_event(action, event)

	for action in MOUSE_BUTTONS:
		_ensure_action(action)
		for button in MOUSE_BUTTONS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)

	# Sur Mac, le raccourci habituel du plein écran est Ctrl + Cmd + F.
	var mac_fullscreen := InputEventKey.new()
	mac_fullscreen.physical_keycode = KEY_F
	mac_fullscreen.ctrl_pressed = true
	mac_fullscreen.meta_pressed = true
	InputMap.action_add_event("fullscreen", mac_fullscreen)


## Texte à afficher pour une action, ex. "E / RB" (touche selon la disposition du clavier).
func prompt(action: String) -> String:
	var keycode: Key = KEYS[action][0]
	if DisplayServer.get_name() != "headless":  # sans fenêtre, la disposition du clavier est inconnue
		keycode = DisplayServer.keyboard_get_keycode_from_physical(keycode)
	var key_name := OS.get_keycode_string(keycode)
	var names: Array[String] = [key_name]
	var pad_name: String = PAD_NAMES.get(PAD_BUTTONS.get(action, [-1])[0], "")
	if pad_name:
		names.append(pad_name)
	if MOUSE_BUTTONS.has(action) and action != "confirm":  # « clic gauche » pour valider va de soi
		names.append(tr(MOUSE_NAMES[MOUSE_BUTTONS[action][0]]))
	return " / ".join(names)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
