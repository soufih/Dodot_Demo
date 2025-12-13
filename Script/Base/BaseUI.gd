extends Control
class_name BaseUI

func begin():
	visibility_changed.connect(_on_visibility_changed)


## 当UI可见性改变时调用
func _on_visibility_changed():
	if visible:
		UIManager.ui_add_to_stack(self)
	else:
		ui_remove_from_stack()

##从UI栈中移除
func ui_remove_from_stack() -> void:
	while UIManager.UIStack.size() > 0:
		var top_ui: BaseUI = UIManager.ui_get_top()
		if top_ui == self:
			UIManager.ui_pop_from_stack()
			break
		else:
			UIManager.ui_pop_from_stack()
