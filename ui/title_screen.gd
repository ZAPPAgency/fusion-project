extends Node2D
## Écran titre : Continuer (si une sauvegarde existe), Nouvelle partie, Quitter.
## Version simple ; l'étape 8 ajoutera les options.

@onready var _menu: VBoxContainer = $Ui/Menu


func _ready() -> void:
	FxLibrary.add_night_ambience(self, Color(0.6, 0.64, 0.85))
	# Démo automatique : on saute l'écran titre.
	if "--autoplay" in OS.get_cmdline_user_args():
		_new_game.call_deferred()
		return

	var title := UiTheme.label("VALBRUNE", Color(2.2, 1.7, 0.8), 40)  # > 1 : le titre brille
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
	title.add_theme_constant_override("outline_size", 8)
	title.size = Vector2(640, 60)
	title.position = Vector2(0, 70)
	$Ui.add_child(title)
	var subtitle := UiTheme.label(tr("TITLE_SUBTITLE"), Color(0.9, 0.85, 0.75), 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(640, 20)
	subtitle.position = Vector2(0, 128)
	$Ui.add_child(subtitle)

	_menu.theme = UiTheme.get_theme()
	_menu.add_child(UiTheme.button(tr("TITLE_CONTINUE"), _continue, SaveSystem.has_save()))
	_menu.add_child(UiTheme.button(tr("TITLE_NEW_GAME"), _new_game))
	if not OS.has_feature("web"):  # dans un navigateur, on ferme simplement l'onglet
		_menu.add_child(UiTheme.button(tr("TITLE_QUIT"), get_tree().quit))
	for button: Button in _menu.get_children():
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.focus_first(_menu)


func _continue() -> void:
	if SaveSystem.load_game():
		SceneRouter.transition_to(GameState.current_map)


func _new_game() -> void:
	GameState.new_game()
	SceneRouter.transition_to(GameState.START_MAP)
