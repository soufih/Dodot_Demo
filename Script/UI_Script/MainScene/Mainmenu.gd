extends BaseUI

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@onready var start_button = $ButtonContainer/gamestart
@onready var setting_button = $ButtonContainer/setting
@onready var quit_button = $ButtonContainer/quit

var setting_panel_instance:BaseUI

func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	setting_button.pressed.connect(on_setting_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	setting_panel_instance = UIManager.load_ui(Path.SETTING_PANEL_SCENE, "UILayer")


func on_start_pressed():
	SceneLoading.load_next_scene(SceneLoading.HOME_SCENE_PATH)


func on_setting_pressed():
	setting_panel_instance.show()


func on_quit_pressed():
	get_tree().quit()
