extends Control
class_name DebugConsoleContainer

## 控制调试控制台的显示状态。
## 窗口状态交给 UIManager，命令执行交给 DebugTool 和 DebugConsoleUI。

## 显示控制台，输入框由用户手动选择。
func show_console() -> void:
	UIManager.open(UIId.DEBUG)


## 隐藏整个控制台容器。
func hide_console() -> void:
	UIManager.close(UIId.DEBUG)


## 在显示和隐藏控制台之间切换。
func toggle_console() -> void:
	UIManager.toggle(UIId.DEBUG)


## 返回控制台容器当前是否可见。
func is_console_visible() -> bool:
	return UIManager.is_open(UIId.DEBUG)
