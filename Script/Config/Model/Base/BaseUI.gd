extends Control
class_name BaseUI
## 只有由管理器登记的窗口根节点参与管理；HUD 与内部组件不会自动入栈。
signal close_requested
var _interactive := true
var _saved_controls: Array[Dictionary] = []


func begin() -> void:
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	UIManager.sync_visibility(self)


func on_open(_payload: Dictionary) -> bool:
	return true


func on_close(_reason: StringName) -> void:
	pass


func cancel_local_interaction() -> bool:
	return false


func request_close() -> void:
	close_requested.emit()


## 屏蔽下层鼠标、焦点和脚本处理；透明遮罩负责阻止穿透世界。
func set_interactive(enabled: bool) -> void:
	if _interactive == enabled:
		return
	_interactive = enabled
	if enabled:
		for saved in _saved_controls:
			var control = saved.ref.get_ref()
			if is_instance_valid(control):
				control.mouse_filter = saved.mouse_filter
				control.focus_mode = saved.focus_mode
		_saved_controls.clear()
	else:
		var controls: Array[Node] = [self]
		controls.append_array(find_children("*", "Control", true, false))
		for control: Control in controls:
			_saved_controls.append({"ref": weakref(control), "mouse_filter": control.mouse_filter, "focus_mode": control.focus_mode})
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			control.focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_DISABLED
