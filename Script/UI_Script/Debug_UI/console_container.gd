extends BaseUI
class_name DebugConsoleContainer

## 控制调试控制台的显示状态。
## 命令执行和输出逻辑由 DebugTool/DebugConsoleUI 负责，本节点只管理可见性和输入焦点。

@onready var _input_line: LineEdit = $ConsolePanel/Layout/Input


## 初始隐藏控制台，并确保它在场景树暂停时仍可接收显示状态更新。
func _ready() -> void:
	begin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_console()


## 显示控制台并将键盘焦点交给命令输入框。
func show_console() -> void:
	show()
	SignalBus.input_control.emit(true)
	UIManager.ban_ui_input()
	_input_line.grab_focus()


## 隐藏整个控制台容器。
func hide_console() -> void:
	SignalBus.input_control.emit(false)
	UIManager.use_ui_input()
	hide()


## 在显示和隐藏控制台之间切换。
func toggle_console() -> void:
	if visible:
		hide_console()
	else:
		show_console()


## 返回控制台容器当前是否可见。
func is_console_visible() -> bool:
	return visible
