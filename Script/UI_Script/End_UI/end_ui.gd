extends BaseUI

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@export_file("*.tscn") var return_scene_path: String = SceneLoading.HOME_SCENE_PATH

@onready var level_label: Label = %LevelName
@onready var prompt_label: Label = %Prompt
@onready var return_button: Button = %ReturnButton
@onready var materials_content: VBoxContainer = %MaterialsContent
@onready var statistics_content: VBoxContainer = %StatisticsContent

var _returning := false
var _previous_tree_pause := false


func _ready() -> void:
	begin()
	UIManager.ui_add_to_list(self)
	_previous_tree_pause = get_tree().paused
	get_tree().paused = true
	var info := CurrentLevel.get_level_info()
	level_label.text = info.levelName if not info.levelName.is_empty() else "关卡 %d" % (info.level + 1)
	return_button.grab_focus()


func _on_return_pressed() -> void:
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	var error := SceneLoading.load_next_scene(return_scene_path, false)
	if error != OK:
		_on_return_failed()
		return
	var loading_ui := get_tree().current_scene.get_node("SceneLoadingLayer").get_child(0)
	if loading_ui._failed:
		_on_return_failed()
		return
	loading_ui.loading_failed.connect(_on_return_failed, CONNECT_ONE_SHOT)
	if get_parent() is CanvasLayer:
		get_parent().layer = 98


func _on_return_failed() -> void:
	_returning = false
	return_button.disabled = false
	prompt_label.text = "返回城镇失败，请重试。"
	if get_parent() is CanvasLayer:
		get_parent().layer = 110
	# ERR_BUSY 时不移除其他入口创建的加载界面。
	var loading_layer := get_tree().current_scene.get_node_or_null("SceneLoadingLayer")
	if loading_layer != null and loading_layer.get_child(0)._failed:
		loading_layer.queue_free()
	return_button.grab_focus()


func _exit_tree() -> void:
	get_tree().paused = _previous_tree_pause
	UIManager.ui_remove_from_list(self)
