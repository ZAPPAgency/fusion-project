extends Node
## Sauvegarde et chargement de la partie (un seul emplacement, au format JSON).
## On sauvegarde à l'auberge ; on reprend depuis l'écran titre.

const SAVE_PATH := "user://save.json"
const TEST_SAVE_PATH := "user://test_game.json"  ## Partie de test (GameState.test_mode)

## Chemin utilisé (modifiable par les tests pour ne pas écraser la vraie sauvegarde).
var save_path := SAVE_PATH


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game(player_position: Vector2) -> bool:
	GameState.player_position = player_position
	# La partie de test a son propre fichier, pour ne jamais écraser la vraie partie.
	var path := TEST_SAVE_PATH if GameState.test_mode else save_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible : %s" % path)
		return false
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	return true


## Charge la sauvegarde dans GameState. Renvoie false si elle est absente ou illisible.
func load_game() -> bool:
	if not has_save():
		return false
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not saved is Dictionary:
		push_error("Sauvegarde illisible : %s" % save_path)
		return false
	GameState.load_dict(saved)
	return true
