extends BaseUI

var save_panel_instance: BaseUI = null
var load_panel_instance: BaseUI = null



func _ready() -> void:
	begin()
	# 存档功能尚未接入，避免点击空实例。
	$PanelContainer/MarginContainer/VBoxContainer/Save_Button.disabled = true
	$PanelContainer/MarginContainer/VBoxContainer/Load_Button.disabled = true

## 设置
func _on_setting_pressed() -> void:	
	UIManager.open(UIId.SETTINGS, {}, UIManager.scene_owner(self))

## 保存
func _on_save_pressed() -> void:
	if is_instance_valid(save_panel_instance):
		save_panel_instance.show()

## 加载
func _on_load_pressed() -> void:
	if is_instance_valid(load_panel_instance):
		load_panel_instance.show()

## 返回
func _on_back_pressed() -> void:
	request_close()
