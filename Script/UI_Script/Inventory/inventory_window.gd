extends Control
## 可拖动背包窗口：边框处理窗口移动，内容输入交给画板处理。

signal item_selected(container_id: String, record: Dictionary)
signal operation_completed(result: InventoryResult)
signal focused(container_id: String)

## 内容区最大可见像素宽高；超过后出现滚动条，格子本身不缩放。
@export var max_grid_view_size: Vector2i = Vector2i(416, 312)

var container_id: String
var dragging: bool = false
var _start_pointer: Vector2
var _start_position: Vector2
var _manager: Node

## 默认不监听全局输入，仅在边框按住左键期间捕获移动与松开事件。
func _ready() -> void:
	set_process_input(false)

## 绑定容器并限制可见内容尺寸；给需要的滚动条留出空间，避免单轴溢出连带产生另一轴滚动。
func bind(manager: Node, id: String, service_type: int, lookup: Callable) -> void:
	_manager = manager
	container_id = id
	var board = $Body/Content/Scroll/Board
	var scroll: ScrollContainer = $Body/Content/Scroll
	board.bind(manager, id, service_type, lookup)
	var state: Dictionary = manager.get_snapshot(id)
	var grid_size: Vector2 = board.custom_minimum_size
	var visible_size := grid_size.min(Vector2(max_grid_view_size))
	var bar_space := Vector2.ZERO
	if grid_size.x > visible_size.x:
		bar_space.y = scroll.get_h_scroll_bar().get_combined_minimum_size().y
	if grid_size.y > visible_size.y:
		bar_space.x = scroll.get_v_scroll_bar().get_combined_minimum_size().x
	size = Vector2(maxf(visible_size.x + 32 + bar_space.x, 280), visible_size.y + 116 + bar_space.y)
	$Title/Row/Name.text = id
	$Body/Content/Type.text = "%s · %d × %d" % ["网格背包" if service_type == InventoryManager.ServiceType.GRID else "普通背包", state.size.x, state.size.y]
	manager.container_changed.connect(_on_container_changed)
	_update_summary()

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
		position = desired.clamp(Vector2.ZERO, (bounds - size).max(Vector2.ZERO))

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
