extends RefCounted
## 超宽、超高容器的实际滚轮输入及滚动后交互回归，不依赖演示物品。

## 经表单创建三种溢出方向，验证原生滚动条及内容交互。
func run(checks, lab) -> void:
	var small: ScrollContainer = lab.windows["UI测试容器"].get_node("Body/Content/Scroll")
	checks._expect(not small.get_h_scroll_bar().visible and not small.get_v_scroll_bar().visible, "小容器不显示多余滚动条")
	var small_window = lab.windows["UI测试容器"]
	small_window.move_to_front()
	var small_point := small.global_position + Vector2(40, 40)
	var before: int = lab.manager.get_snapshot("UI测试容器").revision
	await _wheel(checks, small_point, MOUSE_BUTTON_WHEEL_DOWN)
	checks._expect(small.scroll_horizontal == 0 and small.scroll_vertical == 0, "小容器滚轮不产生无意义偏移")
	checks._expect(lab.manager.get_snapshot("UI测试容器").revision == before, "小容器滚轮不修改数据")
	await _test_scroll_threshold(checks, lab)
	for scenario in [
		["横向滚动测试", Vector2i(10, 3), true, false],
		["纵向滚动测试", Vector2i(4, 12), false, true],
		["双向滚动测试", Vector2i(10, 12), true, true],
	]:
		await _test_container(checks, lab, scenario[0], scenario[1], scenario[2], scenario[3])

## 检查超过五列或十行才滚动，并确认滚动条不会连带触发另一轴。
func _test_scroll_threshold(checks, lab) -> void:
	for scenario in [
		["五列十行边界", Vector2i(5, 10), false, false],
		["六列十行边界", Vector2i(6, 10), true, false],
		["五列十一行边界", Vector2i(5, 11), false, true],
	]:
		var id: String = scenario[0]
		checks._expect(lab.create_container(id, scenario[1], InventoryManager.ServiceType.GRID).is_ok(), id + " 创建成功")
		for frame in range(3):
			await checks.get_tree().process_frame
		var scroll: ScrollContainer = lab.windows[id].get_node("Body/Content/Scroll")
		checks._expect(scroll.get_h_scroll_bar().visible == scenario[2], id + " 横向滚动阈值正确")
		checks._expect(scroll.get_v_scroll_bar().visible == scenario[3], id + " 纵向滚动阈值正确")

## 滚动到真实矩阵末端后点击、拖动物品，确认坐标包含滚动偏移且刷新不跳回顶部。
func _test_container(checks, lab, id: String, dimensions: Vector2i, horizontal: bool, vertical: bool) -> void:
	var form = lab.container_form
	form.get_node("Name").text = id
	form.get_node("Type").select(0)
	form.get_node("Dimensions/Width").value = dimensions.x
	form.get_node("Dimensions/Height").value = dimensions.y
	form.get_node("Create").pressed.emit()
	var window = lab.windows[id]
	window.position = Vector2(24, 24)
	window.move_to_front()
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	var board: Control = scroll.get_node("Board")
	var last := dimensions - Vector2i.ONE
	checks._expect(lab.manager.add_to_container(id, 1002, 9, last).is_ok(), id + " 准备末格物品")
	for frame in range(3):
		await checks.get_tree().process_frame
	var h: HScrollBar = scroll.get_h_scroll_bar()
	var v: VScrollBar = scroll.get_v_scroll_bar()
	checks._expect(h.visible == horizontal, id + " 仅需要时显示横向滚动条")
	checks._expect(v.visible == vertical, id + " 仅需要时显示纵向滚动条")
	checks._expect(board.custom_minimum_size == Vector2(dimensions * board.cell_size), id + " 完整矩阵保持原尺寸")
	checks._expect(window.size.x < dimensions.x * board.cell_size + 32 if horizontal else window.size.y < dimensions.y * board.cell_size + 116, id + " 窗口尺寸受限而非随内容无限扩展")
	var point := scroll.global_position + Vector2(40, 40)
	var window_position: Vector2 = window.position
	var before_revision: int = lab.manager.get_snapshot(id).revision
	await checks._motion(point, 0)
	await _wheel(checks, point, MOUSE_BUTTON_WHEEL_DOWN)
	if vertical:
		checks._expect(scroll.scroll_vertical > 0 and scroll.scroll_horizontal == 0, id + " 普通滚轮优先上下滚动")
	else:
		checks._expect(scroll.scroll_horizontal > 0 and scroll.scroll_vertical == 0, id + " 仅超宽时普通滚轮自动左右滚动")
	if horizontal:
		var old_horizontal: int = scroll.scroll_horizontal
		var old_vertical: int = scroll.scroll_vertical
		await _wheel(checks, point, MOUSE_BUTTON_WHEEL_DOWN, true)
		checks._expect(scroll.scroll_horizontal > old_horizontal, id + " Shift 加滚轮左右滚动")
		checks._expect(scroll.scroll_vertical == old_vertical, id + " 横向滚动不改变纵向位置")
	checks._expect(not window.dragging and window.position == window_position, id + " 滚轮不拖动窗口")
	checks._expect(lab.manager.get_snapshot(id).revision == before_revision, id + " 滚轮不改变容器版本")
	# 大滚动量应钳制在合法末端，不能超过内容边界。
	if vertical:
		await _wheel(checks, point, MOUSE_BUTTON_WHEEL_DOWN, false, 1000)
		checks._expect(is_equal_approx(v.value, v.max_value - v.page), id + " 纵向滚动可到达末端且不越界")
	if horizontal:
		await _wheel(checks, point, MOUSE_BUTTON_WHEEL_DOWN, true, 1000)
		checks._expect(is_equal_approx(h.value, h.max_value - h.page), id + " 横向滚动可到达末端且不越界")
	var bottom_right := board.global_position + Vector2(last * board.cell_size) + Vector2(26, 26)
	checks._expect(scroll.get_global_rect().has_point(bottom_right), id + " 末格经过滚动后位于可见区域")
	var offset := Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
	await checks._motion(bottom_right, 0)
	await checks._button(bottom_right, true)
	await checks._button(bottom_right, false)
	checks._expect(not lab._selected.is_empty() and lab._selected.container_id == id and lab._selected.record.anchor == last, id + " 滚动后点击定位真实末格")
	if lab._selected.is_empty():
		return
	checks._expect(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical) == offset, id + " 选择刷新保持滚动位置")
	var item_id: int = lab._selected.record.instance.instance_id
	var destination := last - Vector2i(1, 0)
	var to_point := board.global_position + Vector2(destination * board.cell_size) + Vector2(26, 26)
	await checks._motion(bottom_right, 0)
	await checks._button(bottom_right, true)
	await checks._motion(bottom_right + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	checks._expect(checks.get_viewport().gui_is_dragging(), id + " 滚动后仍可开始原生物品拖拽")
	await checks._motion(to_point, MOUSE_BUTTON_MASK_LEFT)
	await checks._button(to_point, false)
	var state: Dictionary = lab.manager.get_snapshot(id)
	checks._expect(state.cells[destination.y][destination.x] == item_id and state.cells[last.y][last.x] == null, id + " 滚动后拖放提交真实目标坐标")
	checks._expect(state.items[item_id].instance.quantity == 9, id + " 滚动后移动保持数量")
	checks._expect(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical) == offset, id + " 物品刷新不重置滚动位置")
	if vertical:
		await _wheel(checks, point, MOUSE_BUTTON_WHEEL_UP, false, 1000)
		checks._expect(scroll.scroll_vertical == 0, id + " 向上滚轮可返回顶部")
	if horizontal:
		await _wheel(checks, point, MOUSE_BUTTON_WHEEL_UP, true, 1000)
		checks._expect(scroll.scroll_horizontal == 0, id + " 反向横滚可返回左端")

## 发出完整滚轮按下/释放序列并等待布局稳定，包含 Shift 和滚动量，不直接设置滚动条值。
func _wheel(checks, point: Vector2, button: MouseButton, shift: bool = false, factor: float = 1.0) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	event.shift_pressed = shift
	event.factor = factor
	Input.parse_input_event(event)
	await checks.get_tree().process_frame
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await checks.get_tree().process_frame
