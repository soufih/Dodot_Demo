extends BaseUI

const SceneLoading = preload("res://Script/Gameplay/System/SceneLoader.gd")


func _ready() -> void:
	begin()
	hide()

func _on_button_button_down() -> void:
	UIManager.ui_close_all()

	SceneLoading.load_next_scene(SceneLoading.LEVEL_SCENE_PATH)
