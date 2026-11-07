extends BaseUI

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@export_file("*.tscn") var return_scene_path: String = SceneLoading.HOME_SCENE_PATH

@onready var level_label: Label = %LevelName
@onready var prompt_label: Label = %Prompt
@onready var return_button: Button = %ReturnButton
@onready var materials_content: VBoxContainer = %MaterialsContent
@onready var statistics_content: VBoxContainer = %StatisticsContent

var _returning := false


func _ready() -> void:
	begin()
	var info := CurrentLevel.get_level_info()
	level_label.text = info.levelName if not info.levelName.is_empty() else "关卡 %d" % (info.level + 1)


func _on_return_pressed() -> void:
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	var error := SceneLoading.load_next_scene(return_scene_path, false)
	if error != OK:
		_on_return_failed()
		return
	var loading_ui = UIManager.get_ui(UIId.LOADING)
	loading_ui.loading_failed.connect(_on_return_failed, CONNECT_ONE_SHOT)


func _on_return_failed() -> void:
	_returning = false
	return_button.disabled = false
	prompt_label.text = "返回城镇失败，请重试。"
	var loading_ui = UIManager.get_ui(UIId.LOADING)
	if loading_ui != null and loading_ui._failed:
		UIManager.close(UIId.LOADING)
