extends Control
## 可拖动背包窗口：边框处理窗口移动，内容输入交给画板处理。

signal item_selected(container_id: String, record: Dictionary)
signal operation_completed(result: InventoryResult)
signal focused(container_id: String)

## 内容区默认显示五列、十行（每格 52 像素）；超过后出现滚动条，格子本身不缩放。
@export var max_grid_view_size: Vector2i = Vector2i(260, 520)
## 场景可以指定显示标题；留空时沿用容器 ID。
@export var window_title: String = ""
## 独立测试场景可注入对应的仓库管理器；正式工作区默认使用全局 WarehouseManager。
@export var warehouse_manager: Node

var container_id: String
var dragging: bool = false
var _start_pointer: Vector2
var _start_position: Vector2
var _manager: Node
var _warehouse_manager: Node

## 默认不监听全局输入，仅在边框按住左键期间捕获移动与松开事件。
func _ready() -> void:
	set_process_input(false)

## 绑定容器并限制可见内容尺寸；给需要的滚动条留出空间，避免单轴溢出连带产生另一轴滚动。
func bind(manager: Node, id: String, service_type: int, lookup: Callable, display_name: String = "") -> InventoryResult:
	unbind()
	_manager = manager
	container_id = id
	if service_type == InventoryManager.ServiceType.WAREHOUSE:
		_warehouse_manager = warehouse_manager if warehouse_manager != null else WarehouseManager
		if _warehouse_manager.inventory_manager != manager:
			_manager = null
			_warehouse_manager = null
			return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "仓库管理器与物品管理器必须属于同一会话")
	var board = $Body/Content/Scroll/Board
	var scroll: ScrollContainer = $Body/Content/Scroll
	if board.has_method("validate_layout"):
		var validation: InventoryResult = board.validate_layout(manager, id)
		if not validation.is_ok():
			_manager = null
			return validation
	board.bind(manager, id, service_type, lookup)
	var state: Dictionary = manager.get_snapshot(id)
	var grid_size: Vector2 = board.custom_minimum_size
	var visible_size := grid_size.min(Vector2(max_grid_view_size))
	var bar_space := Vector2.ZERO
	if grid_size.x > visible_size.x:
		bar_space.y = scroll.get_h_scroll_bar().get_combined_minimum_size().y
	if grid_size.y > visible_size.y:
		bar_space.x = scroll.get_v_scroll_bar().get_combined_minimum_size().x
	# 装备窗口大小由场景作者设置，不能按 N × 1 的业务矩阵重新排列或缩放布局。
	if service_type != InventoryManager.ServiceType.EQUIPMENT_SLOT:
		size = Vector2(maxf(visible_size.x + 32 + bar_space.x, 280), visible_size.y + 116 + bar_space.y)
	var default_title := window_title if not window_title.is_empty() else id
	$Title/Row/Name.text = display_name if not display_name.is_empty() else default_title
	$Body/Content/Type.text = "%s · %d × %d" % ["网格背包" if service_type == InventoryManager.ServiceType.GRID else "普通背包", state.size.x, state.size.y]
	if service_type == InventoryManager.ServiceType.EQUIPMENT_SLOT:
		$Body/Content/Type.text = "装备栏 · 拖动物品穿戴或卸下"
	if service_type == InventoryManager.ServiceType.WAREHOUSE:
		$Body/Content/Type.text = "仓库 · %d × %d" % [state.size.x, state.size.y]
	$Title/Row/Organize.visible = service_type == InventoryManager.ServiceType.WAREHOUSE
	$Title/Row/Organize.disabled = service_type != InventoryManager.ServiceType.WAREHOUSE
	$Title/Row/Grip.visible = service_type != InventoryManager.ServiceType.WAREHOUSE
	manager.container_changed.connect(_on_container_changed)
	_update_summary()
	return InventoryResult.success()


func unbind() -> void:
	_end_drag()
	if is_instance_valid(_manager) and _manager.container_changed.is_connected(_on_container_changed):
		_manager.container_changed.disconnect(_on_container_changed)
	_manager = null
	_warehouse_manager = null
	$Title/Row/Organize.disabled = true
	$Body/Content/Scroll/Board.unbind()


func cancel_interaction() -> void:
	_end_drag()
	$Body/Content/Scroll/Board.cancel_interaction()

## 四条边框及标题栏均可开始拖动；使用父画布坐标保留按下点偏移，避免跳动。
func _on_border_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			_start_pointer = _parent_point(event.global_position)
			_start_position = position
			move_to_front()
			set_process_input(true)
			focused.emit(container_id)
		else:
			_end_drag()
		accept_event()

## 拖动离开边框后仍继续跟踪，任意位置松开左键都结束拖动。
func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
	elif event is InputEventMouseMotion:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_end_drag()
			return
		var desired := _start_position + _parent_point(event.position) - _start_pointer
		var bounds: Vector2 = (get_parent() as Control).size
		position = desired.clamp(Vector2.ZERO, (bounds - size * scale).max(Vector2.ZERO))

## 失焦取消拖动，避免切出应用后产生粘住鼠标的窗口。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_drag()

## 清理拖动状态；不会修改容器物品或版本。
func _end_drag() -> void:
	dragging = false
	set_process_input(false)

## 将视口坐标转换到父 Control，兼容画布缩放与父级偏移。
func _parent_point(point: Vector2) -> Vector2:
	return (get_parent() as Control).get_global_transform_with_canvas().affine_inverse() * point

## 转发物品选择并提升窗口层级，不在窗口层执行业务规则。
func _on_item_selected(id: String, record: Dictionary) -> void:
	move_to_front()
	focused.emit(id)
	item_selected.emit(id, record)

## 转发画板命令结果，供测试台显示成功或失败反馈。
func _on_operation_completed(result: InventoryResult) -> void:
	operation_completed.emit(result)

## 手动整理仅发出仓库命令，实际排序和原子提交由 Service 负责。
func _on_organize_pressed() -> void:
	if not is_instance_valid(_warehouse_manager):
		return
	var result: InventoryResult = _warehouse_manager.organize_warehouse(container_id)
	operation_completed.emit(result)
	if result.is_ok():
		$Body/Content/Scroll/Board.refresh_selection()

## 内容变化时刷新统计，标题栏拖动不会产生该信号。
func _on_container_changed(id: String, _revision: int, _ids: Array[int]) -> void:
	if id == container_id:
		_update_summary()

## 从快照计算物品数与占格数，不暴露内部容器。
func _update_summary() -> void:
	var state: Dictionary = _manager.get_snapshot(container_id)
	var occupied: int = 0
	for row in state.cells:
		for id in row:
			occupied += int(id != null)
	$Body/Content/Summary.text = "%d 件物品 · %d / %d 格    v%d" % [state.items.size(), occupied, state.size.x * state.size.y, state.revision]
