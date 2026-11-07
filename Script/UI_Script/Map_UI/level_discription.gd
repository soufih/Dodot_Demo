extends Control

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)


func _ready() -> void:
	hide()

func _on_button_button_down() -> void:
	SceneLoading.load_next_scene(SceneLoading.LEVEL_SCENE_PATH)
