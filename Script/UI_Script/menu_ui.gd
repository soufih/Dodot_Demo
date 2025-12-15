extends Control

var setting_panel_instance: Control = null
const setting_panel : String = "res://UI/MainScene_UI/setting_panel.tscn"


func _on_setting_pressed() -> void:
	# 防止重复加载（避免多次点击创建多个设置界面）
	if setting_panel_instance != null:
		return

	# 加载设置场景并实例化
	var setting_scene: PackedScene = preload(setting_panel)
	setting_panel_instance = setting_scene.instantiate()

	# 将设置界面添加到主UI的根节点（或场景树根节点）
	add_child(setting_panel_instance)

	# 隐藏设置按钮
	$PanelContainer.visible = false


func _on_save_pressed() -> void:
	pass # Replace with function body.


func _on_load_pressed() -> void:
	pass # Replace with function body.


func _on_back_pressed() -> void:
	pass # Replace with function body.
