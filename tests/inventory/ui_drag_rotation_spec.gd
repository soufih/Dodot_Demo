extends RefCounted
## 真实键鼠输入验证 R 旋转预览、原子落地与取消；全部视图来自现有 .tscn。

## 创建独立容器夹具，覆盖普通拖动、跨类型、交换、分割、限制和滚动后旋转。
func run(checks, lab) -> void:
	lab.create_container("R旋转网格", Vector2i(6, 4), InventoryManager.ServiceType.GRID)
	lab.create_container("R旋转栏位", Vector2i(4, 3), InventoryManager.ServiceType.SLOT)
	var grid_window = lab.windows["R旋转网格"]
	var slot_window = lab.windows["R旋转栏位"]
	grid_window.position = Vector2(24, 24)
	slot_window.position = Vector2(500, 24)
	grid_window.move_to_front()
	slot_window.move_to_front()
	await checks.get_tree().process_frame
	var grid = grid_window.get_node("Body/Content/Scroll/Board")
	var slot = slot_window.get_node("Body/Content/Scroll/Board")
	await _test_preview(checks, lab, grid)
	_clear(lab)
	await _test_stationary_drop(checks, lab, grid)
	_clear(lab)
	await _test_cross_and_stack(checks, lab, grid, slot)
	_clear(lab)
	await _test_swap(checks, lab, grid, slot)
	_clear(lab)
	await _test_split(checks, lab, grid, slot)
	_clear(lab)
	await _test_invalid(checks, lab, grid)
	await _test_scrolled(checks, lab)

## 预览尺寸随 R 切换，忽略长按重复事件；多个窗口不会重复处理同一次按键。
func _test_preview(checks, lab, grid) -> void:
	lab.manager.add_to_container(grid.container_id, 1001, 1, Vector2i.ZERO)
	var revision: int = lab.manager.get_snapshot(grid.container_id).revision
	await _begin(checks, grid, Vector2i.ZERO)
	await _key(checks, KEY_R)
	var data: Dictionary = checks.get_viewport().gui_get_drag_data()
	checks._expect(data.instance.rotated, "拖动中 R 切换预览方向一次")
	checks._expect(_preview(checks).size == Vector2(156, 52), "R 预览变为横向完整占格尺寸")
	checks._expect(not grid.record_at(Vector2(26, 26)).instance.rotated, "R 不修改来源画板缓存记录")
	checks._expect(lab.manager.get_snapshot(grid.container_id).revision == revision, "R 预览不提交真实状态")
	await _key(checks, KEY_R, true)
	checks._expect(data.instance.rotated, "长按键盘重复事件不会反复旋转")
	await _key(checks, KEY_R)
	checks._expect(not data.instance.rotated and _preview(checks).size == Vector2(52, 156), "再次按 R 恢复原方向与尺寸")
	await _key(checks, KEY_R)
	await _key(checks, KEY_ESCAPE)
	await checks._button(_point(grid, Vector2i.ZERO), false)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "Esc 清理旋转预览")
	checks._expect(not lab.manager.get_item_at(grid.container_id, Vector2i.ZERO).instance.rotated, "取消旋转拖动保留原方向")
	checks._expect(lab.manager.get_snapshot(grid.container_id).revision == revision, "取消后版本不变")
	await _key(checks, KEY_R)
	checks._expect(lab.manager.get_snapshot(grid.container_id).revision == revision, "未拖动时 R 不影响背包")

## 鼠标悬停在原方向放不下的位置，按 R 后不移动鼠标直接松手也必须成功。
func _test_stationary_drop(checks, lab, grid) -> void:
	var item: ItemInstance
	item = lab.manager.add_to_container(grid.container_id, 1001, 1, Vector2i.ZERO).payload
	var revision: int = lab.manager.get_snapshot(grid.container_id).revision
	await _begin(checks, grid, Vector2i.ZERO)
	await checks._motion(_point(grid, Vector2i(3, 3)), MOUSE_BUTTON_MASK_LEFT)
	var data: Dictionary = checks.get_viewport().gui_get_drag_data()
	checks._expect(not grid._can_drop_data(Vector2(182, 182), data), "原竖向预览在最后一行放不下")
	await _key(checks, KEY_R)
	await _drop(checks, grid, Vector2i(3, 3), true, false)
	var state: Dictionary = lab.manager.get_snapshot(grid.container_id)
	checks._expect(state.items[item.instance_id].anchor == Vector2i(3, 3), "R 后无需移动鼠标即可按落点提交")
	checks._expect(state.items[item.instance_id].instance.rotated and state.cells[3][5] == item.instance_id, "落地按旋转后的完整横向矩形占位")
	checks._expect(state.revision == revision + 1, "旋转和移动只提交一次")
	checks._expect(state.cells[0][0] == null and state.cells[2][0] == null, "旋转移动清空全部旧占位")
	lab.manager.move_in_container(grid.container_id, Vector2i(3, 3), Vector2i.ZERO)
	revision = lab.manager.get_snapshot(grid.container_id).revision
	await _begin(checks, grid, Vector2i.ZERO)
	await _key(checks, KEY_R)
	await _drop(checks, grid, Vector2i.ZERO)
	checks._expect(not lab.manager.get_item_at(grid.container_id, Vector2i.ZERO).instance.rotated, "R 后拖回自身也可原位旋转")
	checks._expect(lab.manager.get_snapshot(grid.container_id).revision == revision + 1, "拖回自身旋转只提交一次")

## 来源为普通栏位时预览仍按网格旋转；旋转后堆叠不改变目标或剩余源栈方向。
func _test_cross_and_stack(checks, lab, grid, slot) -> void:
	var item: ItemInstance
	item = lab.manager.add_to_container(slot.container_id, 1004, 6, Vector2i.ZERO).payload
	await _begin(checks, slot, Vector2i.ZERO)
	await checks._motion(_point(grid, Vector2i(5, 1)), MOUSE_BUTTON_MASK_LEFT)
	await _key(checks, KEY_R)
	checks._expect(_preview(checks).size == Vector2(52, 104), "普通栏位来源按 R 后预览仍为网格尺寸")
	await _drop(checks, grid, Vector2i(5, 1), true, false)
	checks._expect(lab.manager.get_snapshot(slot.container_id).items.is_empty(), "旋转跨容器成功后源清空")
	checks._expect(lab.manager.get_item_at(grid.container_id, Vector2i(5, 2)).instance.rotated, "跨容器按新方向占格")
	lab.manager.add_to_container(slot.container_id, 1004, 8, Vector2i.ZERO)
	await _begin(checks, grid, Vector2i(5, 2))
	await _key(checks, KEY_R)
	await _drop(checks, slot, Vector2i.ZERO)
	checks._expect(lab.manager.get_item_at(slot.container_id, Vector2i.ZERO).instance.quantity == 10, "旋转预览后仍默认堆叠同类物品")
	checks._expect(not lab.manager.get_item_at(slot.container_id, Vector2i.ZERO).instance.rotated, "堆叠保留目标方向")
	var remaining: ItemInstance = lab.manager.get_item_at(grid.container_id, Vector2i(5, 1)).instance
	checks._expect(remaining.quantity == 4 and remaining.rotated, "部分堆叠保留源余量及原方向")
	await _begin(checks, grid, Vector2i(5, 1))
	await _key(checks, KEY_R)
	await _drop(checks, slot, Vector2i(1, 0))
	var stored: ItemInstance = lab.manager.get_item_at(slot.container_id, Vector2i(1, 0)).instance
	checks._expect(stored.instance_id == item.instance_id and not stored.rotated, "放回普通栏位仍保存所选方向及身份")

## 不同物品交换时，被拖动实例采用 R 选择的方向，对方保留原方向和数量。
func _test_swap(checks, lab, grid, slot) -> void:
	var sword: ItemInstance
	var herb: ItemInstance
	sword = lab.manager.add_to_container(grid.container_id, 1001, 1, Vector2i.ZERO).payload
	herb = lab.manager.add_to_container(slot.container_id, 1002, 4, Vector2i.ZERO).payload
	await _begin(checks, grid, Vector2i.ZERO)
	await _key(checks, KEY_R)
	await _drop(checks, slot, Vector2i.ZERO)
	var stored: ItemInstance = lab.manager.get_item_at(slot.container_id, Vector2i.ZERO).instance
	checks._expect(stored.instance_id == sword.instance_id and stored.rotated, "R 后交换采用预览方向")
	var other: ItemInstance = lab.manager.get_item_at(grid.container_id, Vector2i.ZERO).instance
	checks._expect(other.instance_id == herb.instance_id and other.quantity == 4 and not other.rotated, "交换对方原数量及方向保持不变")

## 中键半栈可按 R 单独旋转，落地只改变新栈，来源身份、余量和方向保持正确。
func _test_split(checks, lab, grid, slot) -> void:
	var item: ItemInstance
	item = lab.manager.add_to_container(grid.container_id, 1004, 9, Vector2i.ZERO).payload
	await _begin(checks, grid, Vector2i.ZERO, true)
	await _key(checks, KEY_R)
	checks._expect(_preview(checks).size == Vector2(52, 104) and _preview(checks).get_node("Quantity").text == "4", "R 旋转半栈预览保留半数数量")
	await _drop(checks, grid, Vector2i(4, 1), false)
	var source: ItemInstance = lab.manager.get_item_at(grid.container_id, Vector2i.ZERO).instance
	var divided: ItemInstance = lab.manager.get_item_at(grid.container_id, Vector2i(4, 2)).instance
	checks._expect(source.instance_id == item.instance_id and source.quantity == 5 and not source.rotated, "旋转分割后源余量和原方向保留")
	checks._expect(divided.instance_id != item.instance_id and divided.quantity == 4 and divided.rotated, "新分割栈独立保存旋转后的方向")
	await _begin(checks, grid, Vector2i.ZERO, true)
	await _key(checks, KEY_R)
	await _drop(checks, slot, Vector2i.ZERO, false)
	checks._expect(lab.manager.get_item_at(slot.container_id, Vector2i.ZERO).instance.rotated, "旋转半栈可以跨类型放置")
	checks._expect(lab.manager.get_item_at(grid.container_id, Vector2i.ZERO).instance.quantity == 3, "旋转跨容器分割只扣一半")

## R 遵守配置旋转限制；旋转后无效落点取消，不留下位置或方向变化。
func _test_invalid(checks, lab, grid) -> void:
	lab.manager.add_to_container(grid.container_id, 1001, 1, Vector2i.ZERO)
	var revision: int = lab.manager.get_snapshot(grid.container_id).revision
	await _begin(checks, grid, Vector2i.ZERO)
	await _key(checks, KEY_R)
	await _drop(checks, grid, Vector2i(5, 3))
	checks._expect(lab.manager.get_snapshot(grid.container_id).revision == revision, "旋转后非法落点不提交")
	checks._expect(not lab.manager.get_item_at(grid.container_id, Vector2i.ZERO).instance.rotated, "非法落点保留原方向")
	lab.manager.remove_from_container(grid.container_id, Vector2i.ZERO)
	lab.manager.add_to_container(grid.container_id, 1003, 1, Vector2i.ZERO)
	revision = lab.manager.get_snapshot(grid.container_id).revision
	await _begin(checks, grid, Vector2i.ZERO)
	await _key(checks, KEY_R)
	var data: Dictionary = checks.get_viewport().gui_get_drag_data()
	checks._expect(not data.instance.rotated and _preview(checks).size == Vector2(104, 104), "不可旋转物品按 R 方向和预览尺寸不变")
	checks._expect(lab.status.text.contains("不允许旋转"), "不可旋转物品有明确反馈")
	await _key(checks, KEY_ESCAPE)
	await checks._button(_point(grid, Vector2i.ZERO), false)
	checks._expect(lab.manager.get_snapshot(grid.container_id).revision == revision, "禁止旋转及取消不改变版本")

## 大容器滚动后，在鼠标不再移动的情况下 R 旋转并覆盖自身旧占位进行放置。
func _test_scrolled(checks, lab) -> void:
	lab.create_container("滚动R旋转", Vector2i(10, 8), InventoryManager.ServiceType.GRID)
	var window = lab.windows["滚动R旋转"]
	window.position = Vector2(24, 24)
	window.move_to_front()
	var item: ItemInstance
	item = lab.manager.add_to_container("滚动R旋转", 1004, 7, Vector2i(9, 6), true).payload
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	for frame in range(3):
		await checks.get_tree().process_frame
	scroll.scroll_horizontal = int(scroll.get_h_scroll_bar().max_value)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for frame in range(2):
		await checks.get_tree().process_frame
	var offset := Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
	var board = scroll.get_node("Board")
	await _begin(checks, board, Vector2i(9, 7))
	await checks._motion(_point(board, Vector2i(8, 7)), MOUSE_BUTTON_MASK_LEFT)
	await _key(checks, KEY_R)
	await _drop(checks, board, Vector2i(8, 7), true, false)
	var state: Dictionary = lab.manager.get_snapshot("滚动R旋转")
	checks._expect(state.items[item.instance_id].anchor == Vector2i(8, 7) and not state.items[item.instance_id].instance.rotated, "滚动后 R 旋转落在真实矩阵坐标")
	checks._expect(state.cells[6][9] == null and state.cells[7][8] == item.instance_id, "旋转新矩形可与旧占位重叠且清除旧格")
	checks._expect(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical) == offset, "R 旋转提交后保持滚动位置")

## 复用真实键鼠管线开始左键拖动或中键半栈拖动。
func _begin(checks, board: Control, cell: Vector2i, split: bool = false) -> void:
	var point := _point(board, cell)
	await checks._motion(point, 0)
	if split:
		await checks._button(point, true, MOUSE_BUTTON_MIDDLE)
		await checks._button(point, false, MOUSE_BUTTON_MIDDLE)
	else:
		await checks._button(point, true)
		await checks._motion(point + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	checks._expect(checks.get_viewport().gui_is_dragging(), "R 测试开始原生拖拽")

## 可选不移动鼠标直接松手，覆盖 R 刷新悬停落点的行为。
func _drop(checks, board: Control, cell: Vector2i, held: bool = true, move_pointer: bool = true) -> void:
	var point := _point(board, cell)
	if move_pointer:
		await checks._motion(point, MOUSE_BUTTON_MASK_LEFT if held else 0)
	if not held:
		await checks._button(point, true)
	await checks._button(point, false)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "R 测试落地后清理预览")

## 注入完整按下/释放或重复按键，直接验证输入行为而非调用旋转回调。
func _key(checks, code: Key, echo: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		event.echo = echo if pressed else false
		Input.parse_input_event(event)
		await checks.get_tree().process_frame

## 读取引擎挂载的物品预制场景预览，验证实际布局后的尺寸。
func _preview(checks) -> Control:
	for control in checks.get_viewport().find_children("*", "PanelContainer", true, false):
		if control.scene_file_path == "res://UI/Inventory/inventory_item.tscn" and control.get_parent().name != "Items":
			return control
	return null

## 每组使用独立物品夹具，保留原窗口和场景节点。
func _clear(lab) -> void:
	for id in ["R旋转网格", "R旋转栏位"]:
		for record in lab.manager.get_snapshot(id).items.values():
			lab.manager.remove_from_container(id, record.anchor)

## 使用含滚动偏移的画板全局坐标生成真实输入位置。
func _point(board: Control, cell: Vector2i) -> Vector2:
	return board.global_position + Vector2(cell * board.cell_size) + Vector2(26, 26)
