extends Node
## 窗口注册、所属场景、返回顺序与暂停及输入请求的统一入口。
signal state_changed
signal window_opened(id: StringName)
signal window_closed(id: StringName)

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)
const SHARED_THEME = preload("res://UI/Themes/game_ui_theme.tres")
var _configs: Dictionary = {}
var _instances: Dictionary = {}
var _order: Array[String] = []
var _scopes: Dictionary = {}
var _requests: Dictionary = {}
var _next_token := 1
var _layers: Dictionary = {}
var _shield_layer: CanvasLayer
var _shield: Control
var _syncing := false
var _gameplay_blocked := false
var _shortcuts_blocked := false
var _paused := false

# 只读兼容查询，外部不能维护第二份栈或暂停状态。
var UIList: Array[BaseUI]:
	get:
		var result: Array[BaseUI] = []
		for key in _ordered_keys():
			if _instances[key].config.participates_in_back:
				result.append(_instances[key].ui)
		return result
var is_paused: bool:
	get: return _paused
var is_banned: bool:
	get: return _shortcuts_blocked
var gameplay_blocked: bool:
	get: return _gameplay_blocked
var death_ui: BaseUI:
	get: return get_ui(UIId.DEATH)
var end_ui: BaseUI:
	get: return get_ui(UIId.END)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_defaults()
	for layer in [10, 20, 30, 40, 50, 60]:
		var canvas := CanvasLayer.new()
		canvas.name = "UILayer%d" % layer
		canvas.layer = layer
		add_child(canvas)
		_layers[layer] = canvas
	_shield_layer = CanvasLayer.new()
	_shield_layer.name = "InputShield"
	add_child(_shield_layer)
	_shield = Control.new()
	_shield.name = "Blocker"
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.hide()
	_shield_layer.add_child(_shield)
	_connect_signals.call_deferred()


func _connect_signals() -> void:
	SignalBus.player_death.connect(show_death_screen)


func _register_defaults() -> void:
	for definition in [
		[UIId.PAUSE, Path.MENU_UI_SCENE, UIConfig.Layer.MODAL],
		[UIId.SETTINGS, Path.SETTING_PANEL_SCENE, UIConfig.Layer.MODAL],
		[UIId.MAP, Path.MAP_SCENE, UIConfig.Layer.WINDOW],
		[UIId.EQUIPMENT, Path.EQUIPMENT_ENHANCEMENT_UI_SCENE, UIConfig.Layer.WINDOW],
		[UIId.INVENTORY, "res://UI/Inventory/inventory_workspace.tscn", UIConfig.Layer.WINDOW],
		[UIId.DEATH, Path.DEATH_UI_SCENE, UIConfig.Layer.RESULT],
		[UIId.END, Path.END_UI_SCENE, UIConfig.Layer.RESULT],
		[UIId.LOADING, Path.LOADING_SCREEN_SCENE, UIConfig.Layer.LOADING],
		[UIId.DEBUG, Path.DEBUG_CONSOLE_UI_SCENE, UIConfig.Layer.DEBUG],
	]:
		var config := UIConfig.new()
		config.id = definition[0]
		config.scene_path = definition[1]
		config.layer = definition[2]
		config.modal = true
		config.pause_game = config.id in [UIId.PAUSE, UIId.SETTINGS, UIId.DEATH, UIId.END]
		config.follow_viewport = config.id == UIId.MAP
		if config.id in [UIId.DEATH, UIId.END, UIId.LOADING]:
			config.keep_alive = false
			config.close_on_cancel = false
			config.block_ui_shortcuts = true
		if config.id in [UIId.LOADING, UIId.DEBUG]:
			config.scope = UIConfig.Scope.GLOBAL
		if config.id == UIId.DEBUG:
			config.block_ui_shortcuts = true
		register_ui(config)


func register_ui(config: UIConfig) -> bool:
	if config == null or config.id.is_empty() or _configs.has(config.id) or config.scene_path.is_empty():
		return false
	if not UIConfig.Layer.values().has(config.layer):
		return false
	_configs[config.id] = config.duplicate()
	return true


func configure_scene(owner: Node, ids: Array) -> void:
	var owner_id := owner.get_instance_id()
	if not _scopes.has(owner_id):
		owner.tree_exiting.connect(_on_scope_exiting.bind(owner_id), CONNECT_ONE_SHOT)
	_scopes[owner_id] = {"ref": weakref(owner), "ids": ids.duplicate()}


func scene_owner(node: Node) -> Node:
	var current := node
	while current != null:
		var record := _record_for(current)
		if not record.is_empty():
			return record.owner.get_ref()
		if current.get_parent() == null or current.get_parent() == get_tree().root:
			return current
		current = current.get_parent()
	return null


func _key(id: StringName, instance_key: String) -> String:
	return "%s:%s" % [id, instance_key]


## 同步挂载保证返回时 @onready 控件已经可用。调用应在所属场景 ready 后执行。
func prepare(id: StringName, owner: Node = null, instance_key: String = "") -> BaseUI:
	if not _configs.has(id):
		push_warning("UIManager: 未注册的界面 %s" % id)
		return null
	var config: UIConfig = _configs[id]
	if not config.allow_multiple and not instance_key.is_empty():
		return null
	if config.scope == UIConfig.Scope.SCENE:
		if owner == null:
			owner = get_tree().current_scene
		if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion():
			return null
		var owner_id := owner.get_instance_id()
		if _scopes.has(owner_id) and not _scopes[owner_id].ids.has(id):
			return null
		if not _scopes.has(owner_id):
			configure_scene(owner, _configs.keys())
	else:
		owner = self
	var key := _key(id, instance_key)
	if _instances.has(key):
		var old: Dictionary = _instances[key]
		if is_instance_valid(old.ui) and not old.ui.is_queued_for_deletion() and old.owner.get_ref() == owner:
			return old.ui
		_dispose(key)
	var packed := SceneLoading.get_scene(config.scene_path)
	if packed == null:
		return null
	var node := packed.instantiate()
	if not node is BaseUI:
		node.free()
		push_warning("UIManager: 界面根节点必须继承 BaseUI")
		return null
	var ui := node as BaseUI
	ui.hide()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if ui.theme == null:
		ui.theme = SHARED_THEME
	var parent: Node = _layers[config.layer]
	if config.follow_viewport:
		var canvas := CanvasLayer.new()
		canvas.layer = config.layer
		canvas.follow_viewport_enabled = true
		add_child(canvas)
		parent = canvas
	_instances[key] = {"ui": ui, "config": config, "owner": weakref(owner), "active": false,
		"token": 0, "instance_key": instance_key, "canvas": parent if config.follow_viewport else null}
	ui.close_requested.connect(_close_requested.bind(key))
	ui.tree_exiting.connect(_on_ui_exiting.bind(key, ui.get_instance_id()), CONNECT_ONE_SHOT)
	parent.add_child(ui)
	ui.begin()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	return ui


func open(id: StringName, payload: Dictionary = {}, owner: Node = null, instance_key: String = "") -> BaseUI:
	var config: UIConfig = _configs.get(id)
	if config == null:
		return null
	if id == UIId.DEBUG and not is_open(id) and not can_open_debug():
		return null
	if config.layer < UIConfig.Layer.RESULT and (has_result_or_loading() or _shortcuts_blocked):
		return null
	if id in [UIId.DEATH, UIId.END] and has_result_or_loading():
		return null
	var ui := prepare(id, owner, instance_key)
	if ui == null:
		return null
	var key := _key(id, instance_key)
	var record: Dictionary = _instances[key]
	if record.active:
		activate(ui)
		return ui
	ui.set_interactive(true)
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if not ui.on_open(payload):
		_dispose(key)
		_sync()
		return null
	record.active = true
	record.token = acquire_request(ui, config.pause_game, config.block_gameplay, config.block_ui_shortcuts)
	ui.show()
	activate(ui)
	window_opened.emit(id)
	return ui


func activate(ui: BaseUI) -> void:
	var key := _find_key(ui)
	if key.is_empty() or not _instances[key].active:
		return
	_order.erase(key)
	_order.append(key)
	ui.move_to_front()
	move_child(ui.get_parent(), get_child_count() - 1)
	_sync()


func close(id: StringName, instance_key: String = "", reason: StringName = &"close") -> bool:
	return _close_key(_key(id, instance_key), reason)


func _close_requested(key: String) -> void:
	_close_key(key, &"button")


func _close_key(key: String, reason: StringName) -> bool:
	if not _instances.has(key) or not _instances[key].active:
		return false
	var record: Dictionary = _instances[key]
	record.active = false
	_order.erase(key)
	record.ui.on_close(reason)
	record.ui.hide()
	record.ui.process_mode = Node.PROCESS_MODE_DISABLED
	release_request(record.token)
	record.token = 0
	window_closed.emit(record.config.id)
	if not record.config.keep_alive:
		_dispose(key)
	_sync()
	return true


func toggle(id: StringName, payload: Dictionary = {}) -> BaseUI:
	if is_open(id):
		close(id)
		return null
	return open(id, payload)


func close_top() -> bool:
	var keys := _ordered_keys()
	keys.reverse()
	for key in keys:
		var record: Dictionary = _instances[key]
		if not record.config.participates_in_back:
			if record.config.modal or record.config.layer >= UIConfig.Layer.RESULT:
				return true
			continue
		if record.ui.cancel_local_interaction():
			return true
		if record.config.close_on_cancel:
			_close_key(key, &"cancel")
		return true
	return false


func get_ui(id: StringName, instance_key: String = "") -> BaseUI:
	var record: Dictionary = _instances.get(_key(id, instance_key), {})
	return record.ui if not record.is_empty() and is_instance_valid(record.ui) and not record.ui.is_queued_for_deletion() else null


func is_open(id: StringName, instance_key: String = "") -> bool:
	var record: Dictionary = _instances.get(_key(id, instance_key), {})
	return not record.is_empty() and is_instance_valid(record.ui) and not record.ui.is_queued_for_deletion() and record.active


func has_blocking_ui() -> bool:
	return _gameplay_blocked or _shortcuts_blocked


func has_result_or_loading() -> bool:
	for key in _ordered_keys():
		if _instances[key].config.layer in [UIConfig.Layer.RESULT, UIConfig.Layer.LOADING]:
			return true
	return false


func can_open_debug() -> bool:
	return OS.is_debug_build() and not has_result_or_loading() and not _shortcuts_blocked


func close_scope(owner: Node) -> void:
	if is_instance_valid(owner):
		_on_scope_exiting(owner.get_instance_id())


func _on_scope_exiting(owner_id: int) -> void:
	if _scopes.has(owner_id):
		var scope_owner = _scopes[owner_id].ref.get_ref()
		var callback := _on_scope_exiting.bind(owner_id)
		if is_instance_valid(scope_owner) and scope_owner.tree_exiting.is_connected(callback):
			scope_owner.tree_exiting.disconnect(callback)
	for key in _instances.keys():
		var owner = _instances[key].owner.get_ref()
		if owner == null or owner.get_instance_id() == owner_id:
			_dispose(key)
	_scopes.erase(owner_id)
	for token in _requests.keys():
		var owner = _requests[token].owner.get_ref()
		if owner == null or owner.get_instance_id() == owner_id:
			release_request(token)
	_sync()


func _dispose(key: String) -> void:
	if not _instances.has(key):
		return
	var record: Dictionary = _instances[key]
	_instances.erase(key)
	_order.erase(key)
	if is_instance_valid(record.ui):
		if record.active:
			record.ui.on_close(&"dispose")
		record.ui.hide()
		record.ui.process_mode = Node.PROCESS_MODE_DISABLED
		record.ui.queue_free()
	release_request(record.token)
	if is_instance_valid(record.canvas):
		record.canvas.queue_free()


func _on_ui_exiting(key: String, instance_id: int) -> void:
	if not _instances.has(key) or _instances[key].ui.get_instance_id() != instance_id:
		return
	var record: Dictionary = _instances[key]
	_instances.erase(key)
	_order.erase(key)
	release_request(record.token)
	if is_instance_valid(record.canvas):
		record.canvas.queue_free()
	_sync()


func _find_key(ui: Node) -> String:
	for key in _instances:
		if _instances[key].ui == ui:
			return key
	return ""


func _record_for(ui: Node) -> Dictionary:
	return _instances.get(_find_key(ui), {})


## 旧 show/hide 仍经过同一生命周期；未登记的 HUD 与组件不受影响。
func sync_visibility(ui: BaseUI) -> void:
	if _syncing or not ui.is_node_ready():
		return
	var key := _find_key(ui)
	if key.is_empty():
		return
	var record: Dictionary = _instances[key]
	if ui.visible and not record.active:
		ui.hide()
		open(record.config.id, {}, record.owner.get_ref(), record.instance_key)
	elif not ui.visible and record.active:
		_close_key(key, &"visibility")


func _ordered_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in _order:
		if _instances.has(key) and is_instance_valid(_instances[key].ui) and not _instances[key].ui.is_queued_for_deletion() and _instances[key].active:
			keys.append(key)
	keys.sort_custom(func(a: String, b: String) -> bool:
		var a_layer: int = _instances[a].config.layer
		var b_layer: int = _instances[b].config.layer
		return _order.find(a) < _order.find(b) if a_layer == b_layer else a_layer < b_layer)
	return keys


func _sync() -> void:
	if _syncing or not is_inside_tree() or not is_instance_valid(_shield):
		return
	_syncing = true
	var keys := _ordered_keys()
	var modal_key := ""
	for key in keys:
		if _instances[key].config.modal:
			modal_key = key
	_shield.visible = not modal_key.is_empty()
	if not modal_key.is_empty():
		_shield_layer.layer = _instances[modal_key].config.layer - 1
	for key in keys:
		var enabled := modal_key.is_empty() or keys.find(key) >= keys.find(modal_key)
		_instances[key].ui.set_interactive(enabled)
	# 只清除被模态遮挡的焦点，不为新界面自动选择控件。
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and not modal_key.is_empty():
		var modal: BaseUI = _instances[modal_key].ui
		if focus != modal and not modal.is_ancestor_of(focus):
			focus.release_focus()
	_syncing = false
	_update_requests()


## 外部暂停与 UI 请求共同汇总；owner 离树自动释放自己的 token。
func acquire_request(owner: Node, pause_game: bool = false, block_gameplay: bool = false, block_ui_shortcuts: bool = false) -> int:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return 0
	var token := _next_token
	_next_token += 1
	# 同一 owner 可同时持有多个 token，使用独立闭包作为信号身份。
	var callback := func() -> void: release_request(token)
	_requests[token] = {"owner": weakref(owner), "pause": pause_game, "gameplay": block_gameplay, "shortcuts": block_ui_shortcuts, "exit_callback": callback}
	owner.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	_update_requests()
	return token


func release_request(token: int) -> void:
	if not _requests.has(token):
		return
	var request: Dictionary = _requests[token]
	_requests.erase(token)
	var owner = request.owner.get_ref()
	if is_instance_valid(owner) and owner.tree_exiting.is_connected(request.exit_callback):
		owner.tree_exiting.disconnect(request.exit_callback)
	_update_requests()


func _update_requests() -> void:
	var pause_game := false
	var block_gameplay := false
	var block_shortcuts := false
	for request in _requests.values():
		pause_game = pause_game or request.pause
		block_gameplay = block_gameplay or request.gameplay
		block_shortcuts = block_shortcuts or request.shortcuts
	var changed := _paused != pause_game or _gameplay_blocked != block_gameplay or _shortcuts_blocked != block_shortcuts
	_paused = pause_game
	_gameplay_blocked = block_gameplay
	_shortcuts_blocked = block_shortcuts
	if is_inside_tree():
		get_tree().paused = _paused
	if changed:
		state_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _shortcuts_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		if not close_top():
			open(UIId.PAUSE)
		get_viewport().set_input_as_handled()
	elif not _paused:
		if event.is_action_pressed("OpenEquipmentEnhancement"):
			toggle(UIId.EQUIPMENT)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("OpenMap"):
			toggle(UIId.MAP)
			get_viewport().set_input_as_handled()


func show_death_screen() -> void:
	if not has_result_or_loading():
		ui_close_all()
		open(UIId.DEATH)


func show_end_screen() -> void:
	if not has_result_or_loading():
		ui_close_all()
		open(UIId.END)


# 调试命令兼容包装，状态仅由新管理流程维护。
func ui_close_all() -> void:
	for key in _order.duplicate():
		_close_key(key, &"close_all")


func ui_cancel() -> void:
	if not close_top():
		open(UIId.PAUSE)


func open_pause_menu() -> void:
	toggle(UIId.PAUSE)


func ui_open_equipment_enhancement() -> void:
	toggle(UIId.EQUIPMENT)


func ui_open_map() -> void:
	toggle(UIId.MAP)


func ui_get_top() -> BaseUI:
	var list := UIList
	return list.back() if not list.is_empty() else null


func ui_clear_list() -> void:
	ui_close_all()


func load_ui(ui_path: String, _layer: String = "", owner: Node = null) -> BaseUI:
	for config: UIConfig in _configs.values():
		if config.scene_path == ui_path:
			return prepare(config.id, owner)
	return null
