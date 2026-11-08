extends BaseUI

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@export_multiline var message: String = "这次旅程暂时结束。\n确认后返回家园，重新出发。"
@export_file("*.tscn") var return_scene_path: String = SceneLoading.HOME_SCENE_PATH

@onready var prompt_label: Label = $CenterContainer/Panel/MarginContainer/Layout/Prompt
@onready var confirm_button: Button = $CenterContainer/Panel/MarginContainer/Layout/ConfirmButton

var _confirmed := false


func _ready() -> void:
	begin()
	prompt_label.text = message


func _on_confirm_pressed() -> void:
	if _confirmed:
		return
	_confirmed = true
	confirm_button.disabled = true
	var error := SceneLoading.load_next_scene(return_scene_path, false)
	if error != OK:
		_on_return_failed()
		return
	var loading_ui = UIManager.get_ui(UIId.LOADING)
	loading_ui.loading_failed.connect(_on_return_failed, CONNECT_ONE_SHOT)


func _on_return_failed() -> void:
	_confirmed = false
	confirm_button.disabled = false
	prompt_label.text = "返回家园失败，请再次确认重试。"
	var loading_ui = UIManager.get_ui(UIId.LOADING)
	if loading_ui != null and loading_ui._failed:
		UIManager.close(UIId.LOADING)
