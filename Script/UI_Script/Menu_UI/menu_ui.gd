extends BaseUI

var save_panel_instance: BaseUI = null
var load_panel_instance: BaseUI = null
var setting_panel_instance: BaseUI= null



func _ready() -> void:
	begin()
	# 加载设置场景并实例化
	setting_panel_instance = UIManager.load_ui(Path.SETTING_PANEL_SCENE, "UILayer") #加载设置面板

func _exit_tree() -> void:
	setting_panel_instance.queue_free()

## 设置
func _on_setting_pressed() -> void:	
	setting_panel_instance.show()

## 保存
func _on_save_pressed() -> void:
	save_panel_instance.show()

## 加载
func _on_load_pressed() -> void:
	load_panel_instance.show()

## 返回
func _on_back_pressed() -> void:
	hide()
