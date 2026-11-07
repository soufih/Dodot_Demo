extends Control
## 只渲染快照并翻译鼠标意图，规则与修改统一交给注入的 Manager。

signal item_selected(container_id: String, record: Dictionary)
signal operation_completed(result: InventoryResult)

@export var cell_scene: PackedScene
@export var item_scene: PackedScene
@export var cell_size: int = 52

## 默认使用画板比例；手工装备槽可指定所属布局，避免局部拉伸影响网格预览。
var drag_preview_scale_source: Control
var container_id: String
var _manager: Node
var _lookup: Callable
var _service_type: int
var _snapshot: Dictionary = {}
var _selected_id: int = -1
var _drag_item: ItemInstance
var _drag_preview: Control
var _bound_mouse_filter: MouseFilter = MOUSE_FILTER_STOP

## 未绑定的视图不接收鼠标输入；成功绑定后恢复场景作者设置的过滤方式。
func _ready() -> void:
	_bound_mouse_filter = mouse_filter
	mouse_filter = MOUSE_FILTER_IGNORE

## 仅拖拽来源处理 R，修改独立预览；忽略按键重复，真实状态在落地时才提交。
func _input(event: InputEvent) -> void:
	if _drag_item == null or not get_viewport().gui_is_dragging():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_R and event.physical_keycode != KEY_R:
		return
	var config: ItemConfig = _lookup.call(_drag_item.config_id)
	if config.CanRotate:
		_drag_item.rotated = not _drag_item.rotated
		_update_drag_preview(_drag_preview, _drag_item)
		# 鼠标静止时也重新校验悬停落点，使按 R 后直接松手可以放下。
		get_viewport().update_mouse_cursor_state()
	else:
		operation_completed.emit(InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "此物品不允许旋转"))
	get_viewport().set_input_as_handled()

## 原生拖拽成功、取消或失败后清理来源引用，预览节点由引擎释放。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_item = null
		_drag_preview = null

## 绑定外部服务；不持有可写容器状态，重复绑定时移除旧信号订阅。
func unbind() -> void:
	cancel_interaction()
	if is_instance_valid(_manager) and _manager.container_changed.is_connected(_on_container_changed):
		_manager.container_changed.disconnect(_on_container_changed)
	_manager = null
	drag_preview_scale_source = null
	_snapshot = {}
	mouse_filter = MOUSE_FILTER_IGNORE


func cancel_interaction() -> void:
	if _drag_item != null and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	_drag_item = null
	_drag_preview = null


func bind(manager: Node, id: String, service_type: int, lookup: Callable) -> void:
	if _manager != null and _manager.container_changed.is_connected(_on_container_changed):
		_manager.container_changed.disconnect(_on_container_changed)
	_manager = manager
	container_id = id
	_service_type = service_type
	_lookup = lookup
	_manager.container_changed.connect(_on_container_changed)
	refresh()
	mouse_filter = _bound_mouse_filter

## 用预制格子和物品场景渲染独立快照，物品覆盖层不拦截画板输入。
func refresh() -> void:
	_snapshot = _manager.get_snapshot(container_id)
	_clear_children($Cells)
	_clear_children($Items)
	var dimensions: Vector2i = _snapshot.size
	custom_minimum_size = Vector2(dimensions * cell_size)
	size = custom_minimum_size
	$Cells.columns = dimensions.x
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var cell = cell_scene.instantiate()
			cell.custom_minimum_size = Vector2.ONE * cell_size
			cell.get_node("Coordinate").text = "%d,%d" % [x, y]
			$Cells.add_child(cell)
	for id in _snapshot.items:
		var record: Dictionary = _snapshot.items[id]
		var config: ItemConfig = _lookup.call(record.instance.config_id)
		var view = item_scene.instantiate()
		$Items.add_child(view)
		view.position = Vector2(record.anchor * cell_size) + Vector2(3, 3)
		view.size = _item_footprint_size(record.instance, config) - Vector2(6, 6)
		view.display(record.instance, config)
		view.set_selected(id == _selected_id)

## 清除旧视图节点，数据生命周期仍由 Manager 管理。
func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

## 按像素位置查找缓存记录，空格不调用会发失败信号的业务查询。
func record_at(local_position: Vector2) -> Dictionary:
	if _snapshot.is_empty():
		return {}
	var cell := _cell_at(local_position)
	if cell.x < 0 or cell.y < 0 or cell.x >= _snapshot.size.x or cell.y >= _snapshot.size.y:
		return {}
	var id: Variant = _snapshot.cells[cell.y][cell.x]
	return _snapshot.items.get(id, {})

## 左键选择，中键预览取出一半；分割拖放到落点确认后才修改真实数量。
func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_manager):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		_begin_split(event.position)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var record := record_at(event.position)
		_selected_id = record.instance.instance_id if not record.is_empty() else -1
		refresh()
		item_selected.emit(container_id, record)

## Godot 原生拖拽入口；无论来源/目标容器类型，预览始终按配置与方向的完整网格尺寸显示。
func _get_drag_data(at_position: Vector2) -> Variant:
	var record := record_at(at_position)
	if record.is_empty():
		return null
	_drag_item = record.instance.copy()
	_drag_preview = _create_drag_preview(_drag_item)
	set_drag_preview(_drag_preview)
	return {"source_id": container_id, "source_pos": record.anchor, "instance": _drag_item}

## 复用物品预制场景，普通拖动和中键分割均保持配置定义的完整占格尺寸。
func _create_drag_preview(item: ItemInstance) -> Control:
	var preview = item_scene.instantiate()
	_update_drag_preview(preview, item)
	# 原生预览脱离源窗口挂载，需显式继承所属界面的显示比例。
	var scale_source: Control = drag_preview_scale_source if is_instance_valid(drag_preview_scale_source) else self
	preview.scale = scale_source.get_global_transform().get_scale()
	preview.modulate.a = 0.8
	return preview

## 按当前预览方向更新完整占格尺寸与说明，不旋转或缩放原容器中的物品视图。
func _update_drag_preview(preview: Control, item: ItemInstance) -> void:
	var config: ItemConfig = _lookup.call(item.config_id)
	var preview_size := Vector2(item.get_effective_size(config) * cell_size)
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.display(item, config)

## 中键只构造半栈拖拽数据，不预扣数量；左键放置，右键/Esc 由原生拖放取消。
func _begin_split(at_position: Vector2) -> void:
	if get_viewport().gui_is_dragging():
		return
	var checked: InventoryResult = _manager.can_split(container_id, _cell_at(at_position))
	if not checked.is_ok():
		operation_completed.emit(checked)
		return
	var record := record_at(at_position)
	var item := ItemInstance.new(record.instance.config_id, checked.payload, record.instance.rotated)
	_drag_item = item
	_drag_preview = _create_drag_preview(item)
	force_drag({"source_id": container_id, "source_pos": record.anchor, "instance": item,
		"split_quantity": item.quantity, "source_instance_id": record.instance.instance_id,
		"source_quantity": record.instance.quantity, "source_rotated": record.instance.rotated}, _drag_preview)

## 返回占格数乘以格子大小的完整像素尺寸；网格计入旋转，普通背包始终单格。
func _item_footprint_size(item: ItemInstance, config: ItemConfig) -> Vector2:
	var extent := Vector2i.ONE
	if _service_type in [InventoryManager.ServiceType.GRID, InventoryManager.ServiceType.WAREHOUSE]:
		extent = item.get_effective_size(config)
	return Vector2(extent * cell_size)

## 布局整理后按实例 ID 更新选择记录，避免外部操作仍使用整理前的锚点。
func refresh_selection() -> void:
	refresh()
	item_selected.emit(container_id, _snapshot.items.get(_selected_id, {}))

## 只接受本系统的拖拽数据，实际落点规则由 Manager 预览校验。
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Godot 会在拖放期间反复询问悬停控件；解绑或绑定失败后必须明确拒绝。
	if not is_instance_valid(_manager):
		return false
	if not data is Dictionary or not data.has_all(["source_id", "source_pos", "instance"]):
		return false
	if not data.instance is ItemInstance:
		return false
	if not data.source_id is String or not data.source_pos is Vector2i:
		return false
	var target := record_at(at_position)
	if data.has("split_quantity"):
		if not data.has_all(["source_instance_id", "source_quantity", "source_rotated"]) or not data.split_quantity is int:
			return false
		# 分割必须完整放下，不能交换占着源位置的其他物品，也不能只合并一部分。
		if not target.is_empty():
			if target.instance.instance_id == data.source_instance_id:
				return false
			var merged: InventoryResult = _manager.can_stack(container_id, data.instance, _cell_at(at_position))
			return merged.is_ok() and merged.payload == data.split_quantity
		return _manager.can_place(container_id, data.instance, _cell_at(at_position), data.instance.rotated).is_ok()
	if not target.is_empty():
		if _wants_stack(target, data.instance):
			return _manager.can_stack(container_id, data.instance, _cell_at(at_position)).is_ok()
		# 不同物品、不可堆叠物品或 Shift 表示交换，最终双向占位由正式事务校验。
		return true
	var result: InventoryResult = _manager.can_place(container_id, data.instance, _cell_at(at_position), data.instance.rotated)
	return result.is_ok()

## 同类可堆叠物品默认合并；Shift 显式交换，自身占位沿用无变化的交换命令。
## 此处仅选择交互意图，实际数量、容量和合法性仍由 Manager 与 Service 校验。
func _wants_stack(target: Dictionary, item: ItemInstance) -> bool:
	if target.is_empty() or Input.is_key_pressed(KEY_SHIFT):
		return false
	if target.instance.instance_id == item.instance_id or target.instance.config_id != item.config_id:
		return false
	var config: ItemConfig = _lookup.call(item.config_id)
	return config.MaxStack > 1

## 由画板提供悬停说明，覆盖层可以忽略鼠标而不影响物品提示。
func _get_tooltip(at_position: Vector2) -> String:
	var record := record_at(at_position)
	if record.is_empty():
		return "空格 (%d, %d)" % [_cell_at(at_position).x, _cell_at(at_position).y]
	var config: ItemConfig = _lookup.call(record.instance.config_id)
	return "%s × %d\n%s\n锚点 %s · 实例 %d" % [config.ItemName, record.instance.quantity, config.ItemDiscription, record.anchor, record.instance.instance_id]

## 释放时重新校验：同类默认堆叠，不同物品或 Shift 交换，空格移动；分割校验原栈未变化。
## 合并后选中保留身份的目标栈，使数量说明、旋转和移除按钮继续指向实际存在的实例。
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not is_instance_valid(_manager):
		return
	var result: InventoryResult
	var target := record_at(at_position)
	var selected_id: int = data.instance.instance_id
	if data.has("split_quantity"):
		var source: Dictionary = _manager.get_snapshot(data.source_id).get("items", {}).get(data.source_instance_id, {})
		if source.is_empty() or source.anchor != data.source_pos or source.instance.quantity != data.source_quantity \
				or source.instance.rotated != data.source_rotated:
			result = InventoryResult.failure(InventoryResult.Code.STALE_STATE, "源物品已经变化，请重新分割")
		else:
			result = _manager.split_between_containers(data.source_id, container_id, data.source_pos, _cell_at(at_position), data.split_quantity, data.instance.rotated)
		if result.is_ok():
			selected_id = result.payload.instance_id
	elif _wants_stack(target, data.instance):
		result = _manager.stack_between_containers(data.source_id, container_id, data.source_pos, _cell_at(at_position))
		selected_id = target.instance.instance_id
	elif not target.is_empty():
		result = _manager.swap_between_containers(data.source_id, container_id, data.source_pos, _cell_at(at_position), data.instance.rotated)
	else:
		result = _manager.switch_to_container(data.source_id, container_id, data.source_pos, _cell_at(at_position), data.instance.rotated)
	operation_completed.emit(result)
	if result.is_ok():
		_selected_id = selected_id
		refresh()
		item_selected.emit(container_id, _snapshot.items.get(_selected_id, {}))

## 仅响应绑定容器的提交通知，重读状态而不是直接修改快照。
func _on_container_changed(id: String, _revision: int, _ids: Array[int]) -> void:
	if id == container_id:
		refresh()

## 把局部像素坐标转换为矩阵坐标，负值使用 floor，不能截断为零。
func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
