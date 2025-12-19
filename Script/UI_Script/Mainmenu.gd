extends BaseUI

@onready var start_button = $ButtonContainer/gamestart
@onready var setting_button = $ButtonContainer/setting
@onready var quit_button = $ButtonContainer/quit

func _ready() -> void:
	begin()
	start_button.pressed.connect(on_start_pressed)
	setting_button.pressed.connect(on_setting_pressed)
	quit_button.pressed.connect(on_quit_pressed)


func on_start_pressed():
	SceneLoader.next_scene = "res://Scene/MainScene/MainScene.tscn"
	get_tree().change_scene_to_packed(SceneLoader.loading_scene)
#跳转游戏界面

func on_setting_pressed():
	UIManager.setting_panel_instance.show()

func on_quit_pressed():
	get_tree().quit()
