extends Control
class_name BaseUI

func begin():
	connect("visibility_changed",_on_visibility_changed)

## 当UI可见性改变时调用
func _on_visibility_changed():
	if visible:
		UIManager.ui_add_to_list(self)
	else:
		UIManager.ui_remove_from_list(self)

# ##从UI栈中移除
# func ui_remove_from_list() -> void:
# 	while UIManager.UIlist.size() > 0:
# 		var top_ui: BaseUI = UIManager.ui_get_top()
# 		if top_ui == self:
# 			UIManager.ui_pop_from_list()
# 			break
# 		else:
# 			if UIManager.ui_get_top():
# 				UIManager.ui_get_top().hide()
