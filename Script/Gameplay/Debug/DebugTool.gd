extends Node

## 运行时调试控制台。
##
## 业务模块不应在这里添加硬引用。需要扩展时，在模块初始化时调用：
## DebugTool.register_command(&"feature.action", _on_debug_action, "说明", "feature.action <arg>", self)
## 处理函数接收 PackedStringArray，并返回 String 或
## { "success": bool, "message": String }。
##
## 服务也可以由模块主动注册：
## DebugTool.register_service(&"quest", self)
## DebugTool 的内建命令通过服务名和公共方法与游戏系统通信，因此不依赖具体脚本类型。

signal output_emitted(message: String, level: StringName)
signal output_clear_requested
signal command_executed(command_line: String, result: Dictionary)
signal console_toggle_requested

const CONSOLE_TOGGLE_KEY := KEY_QUOTELEFT
const DEBUG_CONSOLE_UI_SCENE: PackedScene = preload(Path.DEBUG_CONSOLE_UI_SCENE)

const SERVICE_AUTOLOADS := {
	&"ui": &"UIManager",
	&"resources": &"ResourceManager",
}


class DebugCommand extends RefCounted:
	var name: StringName
	var description: String
	var usage: String
	var handler: Callable
	var aliases: PackedStringArray
	var owner_ref: WeakRef

	## 保存命令元数据、执行回调、别名及所属模块的弱引用。
	func _init(
		command_name: StringName,
		command_handler: Callable,
		command_description: String,
		command_usage: String,
		command_aliases: PackedStringArray,
		owner: Object
	) -> void:
		name = command_name
		handler = command_handler
		description = command_description
		usage = command_usage
		aliases = command_aliases
		if owner != null:
			owner_ref = weakref(owner)

	## 判断此命令是否由指定模块注册，用于模块卸载时批量清理。
	func belongs_to(owner: Object) -> bool:
		return owner_ref != null and owner_ref.get_ref() == owner


var _commands: Dictionary = {}
var _services: Dictionary = {}


## 注册调试工具自带的帮助、场景、UI、物品和玩家命令。
func _register_builtin_commands() -> void:
	register_command(&"help", _command_help, "显示命令列表或指定命令的帮助。", "help [command]", self, PackedStringArray(["?"]))
	register_command(&"clear", _command_clear, "清空控制台输出。", "clear", self)
	register_command(&"echo", _command_echo, "输出文本，用于验证控制台是否可用。", "echo <text>", self)
	register_command(&"services", _command_services, "显示当前已连接的调试服务。", "services", self)
	register_command(&"game.pause", _command_game_pause, "暂停或恢复场景树。", "game.pause [on|off|toggle]", self)
	register_command(&"scene.current", _command_scene_current, "显示当前场景路径。", "scene.current", self)
	register_command(&"scene.load", _command_scene_load, "切换到指定场景。", "scene.load <res://scene.tscn>", self)
	register_command(&"ui.toggle", _command_ui_toggle, "切换游戏 UI。", "ui.toggle <equipment|map|pause>", self)
	register_command(&"item.drop", _command_item_drop, "在玩家位置生成掉落物。", "item.drop <item_id> [amount]", self)
	register_command(&"player.info", _command_player_info, "显示玩家生命和法力。", "player.info", self)
	register_command(&"player.hp", _command_player_hp, "设置玩家当前生命值。", "player.hp <value>", self)
	register_command(&"player.heal", _command_player_heal, "恢复玩家生命值。", "player.heal [amount]", self)
	register_command(&"player.god", _command_player_god, "触发玩家无敌状态。", "player.god [duration]", self)



## 初始化命令注册表、独立的控制台 UI，并延迟发现 Autoload 服务。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_builtin_commands()
	_create_console_ui()
	_write_output("调试控制台已就绪。输入 help 查看命令。")
	call_deferred("_discover_autoload_services")


## 监听全局反引号快捷键，切换控制台可见状态且阻止事件继续传播。
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.pressed and not event.echo and event.keycode == CONSOLE_TOGGLE_KEY:
		console_toggle_requested.emit()
		get_viewport().set_input_as_handled()


## 注册命令。命令名和别名不区分大小写，推荐使用 "模块.动作" 的命名方式。
func register_command(
	command_name: StringName,
	handler: Callable,
	description: String = "",
	usage: String = "",
	owner: Object = null,
	aliases: PackedStringArray = PackedStringArray()
) -> bool:
	var normalized_name := _normalize_command_name(str(command_name))
	if str(normalized_name).is_empty():
		push_warning("DebugTool: command name cannot be empty.")
		return false
	if not handler.is_valid():
		push_warning("DebugTool: handler for '%s' is invalid." % normalized_name)
		return false
	if _commands.has(normalized_name):
		push_warning("DebugTool: command '%s' is already registered." % normalized_name)
		return false

	var normalized_aliases := PackedStringArray()
	for alias in aliases:
		var normalized_alias := _normalize_command_name(alias)
		if str(normalized_alias).is_empty() or normalized_alias == normalized_name:
			continue
		if _commands.has(normalized_alias):
			push_warning("DebugTool: alias '%s' is already registered." % normalized_alias)
			return false
		normalized_aliases.append(normalized_alias)

	var command := DebugCommand.new(
		normalized_name,
		handler,
		description,
		usage,
		normalized_aliases,
		owner
	)
	_commands[normalized_name] = command
	for alias in normalized_aliases:
		_commands[alias] = command
	return true


## 同时移除命令和它的全部别名。
func unregister_command(command_name: StringName) -> bool:
	var normalized_name := _normalize_command_name(str(command_name))
	var command: DebugCommand = _commands.get(normalized_name)
	if command == null:
		return false
	for registered_name in _commands.keys():
		if _commands[registered_name] == command:
			_commands.erase(registered_name)
	return true


## 适合模块在 _exit_tree 中调用，避免保留已经失效的命令入口。
func unregister_commands_by_owner(owner: Object) -> int:
	if owner == null:
		return 0
	var removed_count := 0
	var visited: Array[DebugCommand] = []
	for command in _commands.values():
		if command in visited:
			continue
		visited.append(command)
		if command.belongs_to(owner) and unregister_command(command.name):
			removed_count += 1
	return removed_count


## 注册可选服务。服务可以是 Autoload、场景节点或任何 Object。
func register_service(service_name: StringName, service: Object) -> bool:
	var normalized_name := _normalize_command_name(str(service_name))
	if str(normalized_name).is_empty() or service == null:
		return false
	_services[normalized_name] = weakref(service)
	return true


## 解除一个服务名和业务对象之间的映射。
func unregister_service(service_name: StringName) -> void:
	_services.erase(_normalize_command_name(str(service_name)))


## 获取有效服务对象；若弱引用已失效，会自动清理失效映射。
func get_service(service_name: StringName) -> Object:
	var normalized_name := _normalize_command_name(str(service_name))
	var service_ref: WeakRef = _services.get(normalized_name)
	if service_ref == null:
		return null
	var service: Object = service_ref.get_ref()
	if not is_instance_valid(service):
		_services.erase(normalized_name)
		return null
	return service


## 执行一行命令。该接口也可供测试、按钮或网络调试面板复用。
func execute_command(command_line: String, print_result: bool = true) -> Dictionary:
	var parsed := _parse_command_line(command_line)
	if not parsed.success:
		if print_result:
			_write_output(parsed.message, &"error")
		command_executed.emit(command_line, parsed)
		return parsed

	var tokens: PackedStringArray = parsed.tokens
	var command_name := _normalize_command_name(tokens[0])
	var command: DebugCommand = _commands.get(command_name)
	if command == null:
		var unknown_result := _result(false, "未知命令：%s。输入 help 查看可用命令。" % tokens[0])
		if print_result:
			_write_output(unknown_result.message, &"error")
		command_executed.emit(command_line, unknown_result)
		return unknown_result
	if not command.handler.is_valid():
		var invalid_result := _result(false, "命令 '%s' 的处理函数已失效。" % command.name)
		if print_result:
			_write_output(invalid_result.message, &"error")
		command_executed.emit(command_line, invalid_result)
		return invalid_result

	var arguments := PackedStringArray()
	for index in range(1, tokens.size()):
		arguments.append(tokens[index])
	var result := _normalize_handler_result(command.handler.call(arguments))
	if print_result and not result.message.is_empty():
		_write_output(result.message, &"info" if result.success else &"error")
	command_executed.emit(command_line, result)
	return result


## 返回去重并按字母排序后的正式命令名，不包含别名。
func get_command_names() -> PackedStringArray:
	var names := PackedStringArray()
	for command in _commands.values():
		if not names.has(command.name):
			names.append(command.name)
	names.sort()
	return names


## 将已存在的项目 Autoload 按预设服务名自动接入调试工具。
func _discover_autoload_services() -> void:
	for service_name in SERVICE_AUTOLOADS:
		if get_service(service_name) != null:
			continue
		var autoload_name: StringName = SERVICE_AUTOLOADS[service_name]
		var service := get_tree().root.get_node_or_null(NodePath(autoload_name))
		if service != null:
			register_service(service_name, service)


## 显示全部命令摘要，或显示指定命令的用法、说明及别名。
func _command_help(arguments: PackedStringArray) -> Dictionary:
	if arguments.is_empty():
		var lines := PackedStringArray(["可用命令："])
		for command_name in get_command_names():
			var command: DebugCommand = _commands[command_name]
			lines.append("  %-20s %s" % [command.name, command.description])
		return _result(true, "\n".join(lines))

	var command: DebugCommand = _commands.get(_normalize_command_name(arguments[0]))
	if command == null:
		return _result(false, "没有名为 '%s' 的命令。" % arguments[0])
	var alias_text := ""
	if not command.aliases.is_empty():
		alias_text = "\n别名：%s" % ", ".join(command.aliases)
	return _result(true, "%s\n%s%s" % [command.usage if not command.usage.is_empty() else command.name, command.description, alias_text])


## 请求 UI 清空控制台输出，不影响命令注册表和历史记录。
func _command_clear(_arguments: PackedStringArray) -> Dictionary:
	output_clear_requested.emit()
	return _result(true, "")


## 原样回显参数，用于测试命令解析和输出链路。
func _command_echo(arguments: PackedStringArray) -> Dictionary:
	return _result(true, " ".join(arguments))


## 列出当前成功连接且仍然有效的调试服务。
func _command_services(_arguments: PackedStringArray) -> Dictionary:
	var lines := PackedStringArray(["已连接服务："])
	var service_names := PackedStringArray()
	for service_name in _services.keys():
		service_names.append(service_name)
	service_names.sort()
	for service_name in service_names:
		var service := get_service(service_name)
		if service != null:
			var service_location := service.get_class()
			if service is Node:
				service_location = str((service as Node).get_path())
			lines.append("  %s -> %s" % [service_name, service_location])
	return _result(true, "\n".join(lines))


## 按 on、off 或 toggle 参数暂停、恢复或切换场景树状态。
func _command_game_pause(arguments: PackedStringArray) -> Dictionary:
	var mode := arguments[0].to_lower() if not arguments.is_empty() else "toggle"
	match mode:
		"on":
			get_tree().paused = true
		"off":
			get_tree().paused = false
		"toggle":
			get_tree().paused = not get_tree().paused
		_:
			return _result(false, "用法：game.pause [on|off|toggle]")
	return _result(true, "游戏已%s。" % ("暂停" if get_tree().paused else "恢复"))


## 输出当前活动场景的资源路径。
func _command_scene_current(_arguments: PackedStringArray) -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null:
		return _result(false, "当前没有活动场景。")
	return _result(true, "当前场景：%s" % scene.scene_file_path)


## 校验目标场景后切换到指定 PackedScene。
func _command_scene_load(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() != 1:
		return _result(false, "用法：scene.load <res://scene.tscn>")
	var scene_path := arguments[0]
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return _result(false, "场景不存在或不是 PackedScene：%s" % scene_path)
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		return _result(false, "切换场景失败，错误码：%s" % error)
	return _result(true, "正在切换到：%s" % scene_path)


## 根据 UI 名称调用 UI 服务公开的开关方法。
func _command_ui_toggle(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() != 1:
		return _result(false, "用法：ui.toggle <equipment|map|pause>")
	var ui_methods := {
		"equipment": &"ui_open_equipment_enhancement",
		"map": &"ui_open_map",
		"pause": &"open_pause_menu",
	}
	var ui_name := arguments[0].to_lower()
	if not ui_methods.has(ui_name):
		return _result(false, "未知 UI：%s" % arguments[0])
	var response := _call_service(&"ui", ui_methods[ui_name], [])
	if not response.success:
		return response
	return _result(true, "已切换 UI：%s" % ui_name)


## 在 Hero 分组玩家的当前位置生成指定数量的掉落物。
func _command_item_drop(arguments: PackedStringArray) -> Dictionary:
	var parsed := _parse_item_arguments(arguments, "item.drop <item_id> [amount]")
	if not parsed.success:
		return parsed
	if not _is_known_item(parsed.item_id):
		return _result(false, "不存在物品 ID：%s" % parsed.item_id)
	var player := _get_player()
	if player == null:
		return _result(false, "找不到玩家节点（Hero 分组）。")
	var player_position: Vector2 = player.get("global_position")
	var response := _call_service(&"dropped_items", &"create_dropped_item", [[{"id": parsed.item_id, "amount": parsed.amount}], Vector2i(player_position)])
	if not response.success:
		return response
	return _result(true, "已在玩家位置生成物品 %s x%s。" % [parsed.item_id, parsed.amount])


## 查询 Hero 分组玩家的当前/最大生命值和法力值。
func _command_player_info(_arguments: PackedStringArray) -> Dictionary:
	var player := _get_player()
	if player == null:
		return _result(false, "找不到玩家节点（Hero 分组）。")
	if not player.has_method(&"get_character_current_health"):
		return _result(false, "玩家没有角色属性接口。")
	return _result(true, "生命：%s / %s\n法力：%s / %s" % [
		player.call(&"get_character_current_health"),
		player.call(&"get_character_max_health"),
		player.call(&"get_character_current_mana"),
		player.call(&"get_character_max_mana"),
	])


## 将 Hero 分组玩家的当前生命值设为指定数值。
func _command_player_hp(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() != 1 or not arguments[0].is_valid_float():
		return _result(false, "用法：player.hp <value>")
	var player := _get_player()
	if player == null:
		return _result(false, "找不到玩家节点（Hero 分组）。")
	var response := _call_object(player, &"set_character_current_health", [arguments[0].to_float()])
	if not response.success:
		return response
	return _result(true, "玩家当前生命已设为：%s" % arguments[0])


## 治疗指定生命值；不传数量时直接恢复到最大生命值。
func _command_player_heal(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() > 1 or (arguments.size() == 1 and not arguments[0].is_valid_float()):
		return _result(false, "用法：player.heal [amount]")
	var player := _get_player()
	if player == null:
		return _result(false, "找不到玩家节点（Hero 分组）。")
	var current_response := _call_object(player, &"get_character_current_health", [])
	var max_response := _call_object(player, &"get_character_max_health", [])
	if not current_response.success:
		return current_response
	if not max_response.success:
		return max_response
	var amount: float = float(max_response.value) if arguments.is_empty() else arguments[0].to_float()
	var new_health: float = minf(float(current_response.value) + amount, float(max_response.value))
	var set_response := _call_object(player, &"set_character_current_health", [new_health])
	if not set_response.success:
		return set_response
	return _result(true, "玩家生命：%s / %s" % [new_health, max_response.value])


## 可选地设置无敌时长，并触发玩家的 god_mode 信号。
func _command_player_god(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() > 1 or (arguments.size() == 1 and not arguments[0].is_valid_int()):
		return _result(false, "用法：player.god [duration]")
	var player := _get_player()
	if player == null:
		return _result(false, "找不到玩家节点（Hero 分组）。")
	if not player.has_signal(&"god_mode"):
		return _result(false, "当前玩家不支持 god_mode 信号。")
	if not arguments.is_empty():
		player.set("GodModeTimer", arguments[0].to_int())
	player.emit_signal(&"god_mode")
	return _result(true, "已触发无敌状态。")


## 校验物品 ID 与数量参数，并确认物品存在后返回结构化结果。
func _parse_item_arguments(arguments: PackedStringArray, usage: String) -> Dictionary:
	if arguments.is_empty() or arguments.size() > 2 or not arguments[0].is_valid_int():
		return _result(false, "用法：%s" % usage)
	var amount := 1
	if arguments.size() == 2:
		if not arguments[1].is_valid_int():
			return _result(false, "数量必须是正整数。")
		amount = arguments[1].to_int()
	var item_id := arguments[0].to_int()
	if item_id < 0 or amount <= 0:
		return _result(false, "物品 ID 和数量必须为正整数。")
	if not _is_known_item(item_id):
		return _result(false, "不存在物品 ID：%s" % item_id)
	return {"success": true, "item_id": item_id, "amount": amount}


## 通过资源服务判断指定物品 ID 是否为有效配置。
func _is_known_item(item_id: int) -> bool:
	var resources := get_service(&"resources")
	return resources != null and resources.has_method(&"get_item_config") and resources.call(&"get_item_config", item_id) != null


## 从 Hero 分组中获取当前场景的第一个玩家节点。
func _get_player() -> Node:
	return get_tree().get_first_node_in_group(&"Hero")


## 查找命名服务并调用其公开方法，将结果转换为统一响应结构。
func _call_service(service_name: StringName, method: StringName, arguments: Array) -> Dictionary:
	var service := get_service(service_name)
	if service == null:
		return _result(false, "调试服务 '%s' 未连接。" % service_name)
	return _call_object(service, method, arguments)


## 在确认对象和方法有效后使用 callv 调用，避免直接依赖业务类型。
func _call_object(target: Object, method: StringName, arguments: Array) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return _result(false, "目标对象已失效。")
	if not target.has_method(method):
		return _result(false, "目标对象不支持方法：%s" % method)
	return {"success": true, "value": target.callv(method, arguments), "message": ""}


## 将命令行拆分为令牌；支持单双引号包裹参数和反斜杠转义。
func _parse_command_line(command_line: String) -> Dictionary:
	var tokens := PackedStringArray()
	var current := ""
	var quote := ""
	var escaping := false
	for character in command_line.strip_edges():
		if escaping:
			current += character
			escaping = false
		elif character == "\\":
			escaping = true
		elif not quote.is_empty():
			if character == quote:
				quote = ""
			else:
				current += character
		elif character == "\"" or character == "'":
			quote = character
		elif character == " " or character == "\t":
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += character
	if escaping:
		current += "\\"
	if not quote.is_empty():
		return _result(false, "命令包含未闭合的引号。")
	if not current.is_empty():
		tokens.append(current)
	if tokens.is_empty():
		return _result(false, "请输入命令。")
	return {"success": true, "tokens": tokens, "message": ""}


## 将命令处理器的 String、Dictionary 或空返回值统一为结果字典。
func _normalize_handler_result(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {
			"success": bool(value.get("success", true)),
			"message": str(value.get("message", "")),
			"value": value.get("value"),
		}
	if value == null:
		return _result(true, "")
	return _result(true, str(value))


## 创建包含 success、message 和 value 字段的统一命令响应。
func _result(success: bool, message: String, value: Variant = null) -> Dictionary:
	return {"success": success, "message": message, "value": value}


## 去除首尾空格并转为小写，生成不区分大小写的命令或服务键。
func _normalize_command_name(value: String) -> StringName:
	return StringName(value.strip_edges().to_lower())


## 发出 UI 可订阅的输出事件，并同步写入 Godot 的调试输出。
func _write_output(message: String, level: StringName = &"info") -> void:
	output_emitted.emit(message, level)
	match level:
		&"error":
			push_warning("DebugTool: %s" % message)
		_:
			print("DebugTool: %s" % message)


## 实例化独立 UI 场景并注入当前 DebugTool 作为命令后端。
func _create_console_ui() -> void:
	var console_ui: Node = DEBUG_CONSOLE_UI_SCENE.instantiate()
	add_child(console_ui)
	if console_ui.has_method(&"bind_debug_tool"):
		console_ui.call(&"bind_debug_tool", self)
	else:
		push_error("DebugTool: DebugConsoleUI 缺少 bind_debug_tool() 接口。")
