extends BaseUI

const SceneLoading = preload("res://Script/Gameplay/System/SceneLoader.gd")

@export_multiline var message: String = "这次旅程暂时结束。\n确认后返回家园，重新出发。"
@export_file("*.tscn") var return_scene_path: String = SceneLoading.HOME_SCENE_PATH

@onready var prompt_label: Label = $CenterContainer/Panel/MarginContainer/Layout/Prompt
@onready var confirm_button: Button = $CenterContainer/Panel/MarginContainer/Layout/ConfirmButton

var _confirmed := false


func _ready() -> void:
	begin()
	UIManager.ui_add_to_list(self)
	prompt_label.text = message
	confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	if _confirmed:
		return
	_confirmed = true
	confirm_button.disabled = true
	var error := SceneLoading.load_next_scene(return_scene_path, false)
	if error != OK:
		_on_return_failed()
		return
	var loading_ui := get_tree().current_scene.get_node("SceneLoadingLayer").get_child(0)
	if loading_ui._failed:
		_on_return_failed()
		return
	loading_ui.loading_failed.connect(_on_return_failed, CONNECT_ONE_SHOT)
	# 让加载界面覆盖死亡界面；失败时仍可回到此处重试。
	if get_parent() is CanvasLayer:
		get_parent().layer = 98


func _on_return_failed() -> void:
	_confirmed = false
	confirm_button.disabled = false
	prompt_label.text = "返回家园失败，请再次确认重试。"
	if get_parent() is CanvasLayer:
		get_parent().layer = 110
	var loading_layer := get_tree().current_scene.get_node_or_null("SceneLoadingLayer")
	if loading_layer != null:
		loading_layer.queue_free()
	confirm_button.grab_focus()


func _exit_tree() -> void:
	UIManager.ui_remove_from_list(self)
