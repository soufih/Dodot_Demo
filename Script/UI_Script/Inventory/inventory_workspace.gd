extends BaseUI
## 管理一组现有容器的窗口；容器创建与存档归业务层所有。
const WINDOW = preload("res://UI/Inventory/inventory_window.tscn")
const EQUIPMENT_WINDOW = preload("res://UI/Inventory/equipment_window.tscn")
const WAREHOUSE_WINDOW = preload("res://UI/Inventory/warehouse_window.tscn")
var windows: Array[Control] = []
## 浮动窗口之间的初始间隔；各窗口内部布局仍由各自场景决定。
@export var window_gap: float = 24.0
## 不含仓库时的定位数组；与打开的容器顺序逐项对应，默认先背包、后装备。
@export var window_positions: Array[Marker2D] = []
## 包含仓库时使用独立定位数组，默认依次为背包、装备和仓库。
@export var warehouse_window_positions: Array[Marker2D] = []


## 验证容器后按是否包含仓库选取整套定位点，再实例化场景并绑定已有容器。
func on_open(payload: Dictionary) -> bool:
	_clear_windows()
	var containers: Array = payload.get("containers", [])
	if containers.is_empty() and payload.has("container_id"):
		var entry := payload.duplicate()
		entry.id = payload.container_id
		containers = [entry]
	var has_warehouse := false
	# 先校验全部容器，避免只显示部分绑定结果。
	for entry in containers:
		if not entry is Dictionary or not entry.has("id") or InventoryManager.get_snapshot(entry.id).is_empty():
			return false
		if entry.has("window_scene") and not entry.window_scene is PackedScene:
			return false
		if entry.get("service_type", InventoryManager.ServiceType.GRID) == InventoryManager.ServiceType.WAREHOUSE:
			has_warehouse = true
	var positions: Array[Marker2D] = warehouse_window_positions if has_warehouse else window_positions
	var next_position := Vector2(24, 24)
	for entry in containers:
		var service_type: int = entry.get("service_type", InventoryManager.ServiceType.GRID)
		var default_scene: PackedScene = EQUIPMENT_WINDOW if service_type == InventoryManager.ServiceType.EQUIPMENT_SLOT else WINDOW
		if service_type == InventoryManager.ServiceType.WAREHOUSE:
			default_scene = WAREHOUSE_WINDOW
		var scene: PackedScene = entry.get("window_scene", default_scene)
		var view = scene.instantiate()
		$Workspace.add_child(view)
		var result: InventoryResult = view.bind(InventoryManager, entry.id, service_type, ResourceManager.get_item_config, entry.get("display_name", ""))
		if not result.is_ok():
			view.unbind()
			view.queue_free()
			_clear_windows()
			return false
		view.position = _initial_window_position(positions, windows.size(), next_position)
		next_position = view.position + Vector2(view.size.x + window_gap, 0)
		view.operation_completed.connect(_on_operation_completed)
		windows.append(view)
	$Empty.visible = windows.is_empty()
	$Status.text = "拖动物品进行操作，按 Esc 关闭背包。"
	_clamp_windows.call_deferred()
	return true

## 将定位点转换到工作区坐标，兼容父节点偏移和缩放；缺少或未赋值时继续自动排列。
func _initial_window_position(positions: Array[Marker2D], index: int, fallback: Vector2) -> Vector2:
	if index >= positions.size() or not is_instance_valid(positions[index]):
		return fallback
	return $Workspace.get_global_transform_with_canvas().affine_inverse() \
		* positions[index].get_global_transform_with_canvas().origin


func on_close(_reason: StringName) -> void:
	_clear_windows()


func _clear_windows() -> void:
	if is_inside_tree() and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	for view in windows:
		view.unbind()
		view.hide()
		view.queue_free()
	windows.clear()


func cancel_local_interaction() -> bool:
	if get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
		return true
	for view in windows:
		if view.dragging:
			view.cancel_interaction()
			return true
	return false


func set_interactive(enabled: bool) -> void:
	if not enabled:
		cancel_local_interaction()
	super.set_interactive(enabled)


func _clamp_windows() -> void:
	var available: Vector2 = ($Workspace.size - Vector2(48, 48)).max(Vector2.ONE)
	# 同一工作区共享缩放比例，让背包、装备与仓库的文字和网格保持一致。
	var factor := 1.0
	for view in windows:
		factor = minf(factor, minf(available.x / view.size.x, available.y / view.size.y))
	for view in windows:
		view.scale = Vector2.ONE * factor
		view.position = view.position.clamp(Vector2.ZERO, ($Workspace.size - view.size * view.scale).max(Vector2.ZERO))


func _on_operation_completed(result: InventoryResult) -> void:
	$Status.text = "操作成功" if result.is_ok() else result.message
