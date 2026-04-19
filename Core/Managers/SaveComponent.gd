class_name SaveComponent
extends Node

const SAVE_PATH = "user://herd_save.tres"
var _save_pending: bool = false

func save_game(herd: Array[GoatData], gold: int, current_day: int) -> void:
	if _save_pending:
		return
	
	_save_pending = true
	# Use a Callable to pass multiple arguments to call_deferred correctly
	_perform_save_deferred.call_deferred(herd, gold, current_day)

func _perform_save_deferred(herd: Array[GoatData], gold: int, current_day: int) -> void:
	_save_pending = false
	var save = GoatSaveData.new()
	save.herd = herd
	save.gold = gold
	save.current_day = current_day
	var err = ResourceSaver.save(save, SAVE_PATH)
	if err != OK:
		print("Error saving herd: ", err)

func load_game() -> GoatSaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	
	var save = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	if save is GoatSaveData:
		return save
	return null
