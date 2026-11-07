extends BaseUI
class_name DebugConsoleUI

## 调试控制台的显示层。
## 该脚本只处理输入、历史记录和展示；命令解析与业务调用由 DebugTool 负责。

const MAX_HISTORY_SIZE := 100

@onready var _console_container: DebugConsoleContainer = $ConsoleContainer
@onready var _output_label: RichTextLabel = $ConsoleContainer/ConsolePanel/Layout/Output
@onready var _input_line: LineEdit = $ConsoleContainer/ConsolePanel/Layout/Input
var _debug_tool: Object
var _history: PackedStringArray = PackedStringArray()
var _history_index := -1


## 初始化 UI 节点，并连接文本输入和键盘事件。
func _ready() -> void:
	begin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input_line.text_submitted.connect(_on_command_submitted)
	_input_line.gui_input.connect(_on_input_gui_input)


## 输入框未聚焦时也允许 Esc 关闭控制台。
func _unhandled_key_input(event: InputEvent) -> void:
	if UIManager.is_open(UIId.DEBUG) and event.is_action_pressed("ui_cancel") and not event.is_echo():
		UIManager.close(UIId.DEBUG)
		get_viewport().set_input_as_handled()


## 由 DebugTool 注入命令后端，避免 UI 依赖具体的命令实现类型。
func bind_debug_tool(debug_tool: Object) -> void:
	if _debug_tool != null:
		_disconnect_debug_tool()
	_debug_tool = debug_tool
	_debug_tool.connect(&"output_emitted", _on_output_emitted)
	_debug_tool.connect(&"output_clear_requested", _on_output_clear_requested)
	_debug_tool.connect(&"console_toggle_requested", _console_container.toggle_console)


## 场景移除前断开信号，避免后端向无效 UI 发送回调。
func _exit_tree() -> void:
	_disconnect_debug_tool()


## 将用户输入交给 DebugTool 执行，并把有效命令保存到本地历史记录。
func _on_command_submitted(command_line: String) -> void:
	if command_line.strip_edges().is_empty() or _debug_tool == null:
		return
	_append_output("> %s" % command_line)
	_history.append(command_line)
	if _history.size() > MAX_HISTORY_SIZE:
		_history.remove_at(0)
	_history_index = -1
	_debug_tool.call(&"execute_command", command_line)
	_input_line.clear()


## 处理输入框中的快捷键：上下键浏览历史记录，Esc 关闭控制台。
func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_UP:
		_navigate_history(-1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DOWN:
		_navigate_history(1)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ESCAPE, KEY_QUOTELEFT]:
		_console_container.hide_console()
		get_viewport().set_input_as_handled()


## 根据方向选择一条历史命令；索引为 -1 时恢复空输入框。
func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + direction, -1, _history.size() - 1)
	if _history_index == -1:
		_input_line.clear()
	else:
		_input_line.text = _history[_history_index]
		_input_line.caret_column = _input_line.text.length()


## 接收 DebugTool 的输出信号，并追加到控制台文本区域。
func _on_output_emitted(message: String, _level: StringName) -> void:
	if not message.is_empty():
		_append_output(message)


## 接收清屏信号并删除所有已显示的输出内容。
func _on_output_clear_requested() -> void:
	_output_label.clear()


## 向输出区域追加一行文本，并自动滚动到最新一行。
func _append_output(message: String) -> void:
	_output_label.append_text("%s\n" % message)
	_output_label.scroll_to_line(_output_label.get_line_count())


## 安全断开与 DebugTool 建立的全部信号连接。
func _disconnect_debug_tool() -> void:
	if _debug_tool == null or not is_instance_valid(_debug_tool):
		return
	if _debug_tool.is_connected(&"output_emitted", _on_output_emitted):
		_debug_tool.disconnect(&"output_emitted", _on_output_emitted)
	if _debug_tool.is_connected(&"output_clear_requested", _on_output_clear_requested):
		_debug_tool.disconnect(&"output_clear_requested", _on_output_clear_requested)
	if _debug_tool.is_connected(&"console_toggle_requested", _console_container.toggle_console):
		_debug_tool.disconnect(&"console_toggle_requested", _console_container.toggle_console)
