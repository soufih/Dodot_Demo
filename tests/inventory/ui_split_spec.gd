extends RefCounted
## 中键半栈拖放回归，全部节点复用测试台及物品 .tscn 场景。

## 运行真实中键取出、取消、同/跨容器放置、合并、失效来源及滚动后分割。
func run(checks, lab) -> void:
	lab.create_container("分割网格", Vector2i(6, 4), InventoryManager.ServiceType.GRID)
	lab.create_container("分割栏位", Vector2i(4, 3), InventoryManager.ServiceType.SLOT)
	var grid_window = lab.windows["分割网格"]
	var slot_window = lab.windows["分割栏位"]
	grid_window.position = Vector2(24, 24)
	slot_window.position = Vector2(500, 24)
	grid_window.move_to_front()
	slot_window.move_to_front()
	await checks.get_tree().process_frame
	var grid = grid_window.get_node("Body/Content/Scroll/Board")
	var slot = slot_window.get_node("Body/Content/Scroll/Board")
	lab.manager.add_to_container("分割网格", 1004, 8, Vector2i.ZERO, true)
	await _test_cancel(checks, lab, grid)
	await _test_placement(checks, lab, grid, slot)
	await _test_invalid(checks, lab, grid, slot)
	await _test_scrolled(checks, lab)

## 中键松开后保持半栈预览，数量与占格尺寸准确；Esc 和右键取消都不扣减数据。
func _test_cancel(checks, lab, grid) -> void:
	var before: int = lab.manager.get_snapshot("分割网格").revision
	var data: Dictionary = await _take(checks, grid, Vector2i(0, 1))
	checks._expect(data.instance.quantity == 4 and data.split_quantity == 4, "偶数中键预览为一半")
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i.ZERO).instance.quantity == 8, "中键取出前不扣减真实数量")
	var preview: Control = _preview(checks)
	checks._expect(preview != null, "中键分割复用物品场景预览")
	if preview != null:
		checks._expect(preview.size == Vector2(52, 104), "分割预览保持旋转后的完整网格尺寸")
		checks._expect(preview.get_node("Quantity").text == "4", "分割预览显示半栈数量")
	await _escape(checks)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "Esc 取消中键分割预览")
	checks._expect(lab.manager.get_snapshot("分割网格").revision == before, "Esc 取消不修改版本")
	await _take(checks, grid, Vector2i.ZERO)
	await _right_cancel(checks, grid)
	checks._expect(lab.manager.get_snapshot("分割网格").revision == before, "右键取消不修改数量或版本")

## 奇数对半保留多出的一个，新栈可放到同容器、跨类型容器，也可完整合入同类目标。
func _test_placement(checks, lab, grid, slot) -> void:
	lab.manager.remove_from_container("分割网格", Vector2i.ZERO)
	var original: ItemInstance
	original = lab.manager.add_to_container("分割网格", 1004, 9, Vector2i.ZERO, true).payload
	var data: Dictionary = await _take(checks, grid, Vector2i(0, 1))
	checks._expect(data.instance.quantity == 4, "奇数分割向下取整")
	await _place(checks, grid, Vector2i(2, 0))
	var source: Dictionary = lab.manager.get_item_at("分割网格", Vector2i.ZERO)
	var target: Dictionary = lab.manager.get_item_at("分割网格", Vector2i(2, 1))
	checks._expect(source.instance.instance_id == original.instance_id and source.instance.quantity == 5, "奇数分割保留原 ID 和多出的一个")
	checks._expect(target.instance.instance_id != original.instance_id and target.instance.quantity == 4, "放置分割栈分配新 ID")
	checks._expect(target.instance.rotated and target.anchor == Vector2i(2, 0), "分割新栈保留方向及完整矩形")
	checks._expect(grid.get_node("Items").get_child_count() == 2, "放置后显示两个物品视图")
	checks._expect(lab._selected.record.instance.instance_id == target.instance.instance_id, "放置后选择新分割栈")
	await _take(checks, grid, Vector2i(0, 1))
	await _place(checks, slot, Vector2i.ZERO)
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i.ZERO).instance.quantity == 3, "跨容器分割源保留余量")
	checks._expect(lab.manager.get_item_at("分割栏位", Vector2i.ZERO).instance.quantity == 2, "网格到栏位分割数量正确")
	await _take(checks, slot, Vector2i.ZERO)
	var preview: Control = _preview(checks)
	checks._expect(preview != null and preview.size == Vector2(52, 104), "栏位来源分割预览也保持网格占格尺寸")
	await _place(checks, grid, Vector2i(4, 0))
	checks._expect(lab.manager.get_item_at("分割栏位", Vector2i.ZERO).instance.quantity == 1, "分割数量为二时源仍保留一件")
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i(4, 1)).instance.quantity == 1, "栏位到网格分割按旋转矩形放置")
	await _take(checks, grid, Vector2i.ZERO)
	await _place(checks, grid, Vector2i(2, 1))
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i.ZERO).instance.quantity == 2, "分割合并只扣一半")
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i(2, 0)).instance.quantity == 5, "分割栈默认完整合入同类目标")
	checks._expect(lab._selected.record.instance.instance_id == target.instance.instance_id, "分割合并后选择原目标实例")

## 单件/空格拒绝启动，非法落点取消，目标容量变化和来源被替换均不能扣错数量。
func _test_invalid(checks, lab, grid, slot) -> void:
	var point := _point(slot, Vector2i.ZERO)
	await checks._motion(point, 0)
	await checks._button(point, true, MOUSE_BUTTON_MIDDLE)
	await checks._button(point, false, MOUSE_BUTTON_MIDDLE)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "单件物品不能中键分割")
	checks._expect(lab.status.text.contains("失败"), "单件分割显示失败原因")
	point = _point(grid, Vector2i(5, 3))
	await checks._motion(point, 0)
	await checks._button(point, true, MOUSE_BUTTON_MIDDLE)
	await checks._button(point, false, MOUSE_BUTTON_MIDDLE)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "中键点击空格不启动分割")
	lab.manager.remove_from_container("分割网格", Vector2i.ZERO)
	lab.manager.add_to_container("分割网格", 1004, 9, Vector2i.ZERO, true)
	var before: int = lab.manager.get_snapshot("分割网格").revision
	await _take(checks, grid, Vector2i.ZERO)
	await _place(checks, grid, Vector2i(5, 3))
	checks._expect(lab.manager.get_snapshot("分割网格").revision == before, "越界放置取消且不扣减原栈")
	lab.manager.remove_from_container("分割栏位", Vector2i.ZERO)
	lab.manager.add_to_container("分割栏位", 1004, 8, Vector2i.ZERO)
	var slot_before: int = lab.manager.get_snapshot("分割栏位").revision
	await _take(checks, grid, Vector2i.ZERO)
	await _place(checks, slot, Vector2i.ZERO)
	checks._expect(lab.manager.get_snapshot("分割网格").revision == before and lab.manager.get_snapshot("分割栏位").revision == slot_before, "容量只能接收部分时整个分割取消")
	var data: Dictionary = await _take(checks, grid, Vector2i.ZERO)
	lab.manager.remove_from_container("分割网格", Vector2i.ZERO)
	var replacement: ItemInstance
	replacement = lab.manager.add_to_container("分割网格", 1002, 6, Vector2i.ZERO).payload
	slot._drop_data(Vector2(130, 26), data)
	checks._expect(lab.status.text.contains("源物品已经变化"), "分割期间原位置被替换时拒绝旧拖拽")
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i.ZERO).instance.quantity == 6, "失效分割不扣减替换物品")
	checks._expect(lab.manager.get_snapshot("分割栏位").revision == slot_before, "失效分割不向目标添加物品")
	await _right_cancel(checks, grid)
	data = await _take(checks, grid, Vector2i.ZERO)
	lab.manager.add_to_container("分割网格", 1002, 18, Vector2i(5, 2))
	lab.manager.stack_in_container("分割网格", Vector2i.ZERO, Vector2i(5, 2))
	slot._drop_data(Vector2(130, 26), data)
	checks._expect(lab.status.text.contains("源物品已经变化"), "同一实例数量变化后拒绝旧分割数量")
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i.ZERO).instance.quantity == 4, "失效分割保留源的最新数量")
	await _right_cancel(checks, grid)
	lab.manager.remove_from_container("分割网格", Vector2i.ZERO)
	lab.manager.add_to_container("分割网格", 1004, 9, Vector2i.ZERO, true)
	data = await _take(checks, grid, Vector2i.ZERO)
	lab.manager.rotate_in_container("分割网格", Vector2i.ZERO, false)
	slot._drop_data(Vector2(130, 26), data)
	checks._expect(lab.status.text.contains("源物品已经变化"), "分割预览期间旋转后要求重新取出")
	checks._expect(lab.manager.get_item_at("分割网格", Vector2i.ZERO).instance.quantity == 9, "预览方向失效不扣减数量")
	await _right_cancel(checks, grid)

## 滚动到矩阵末端后中键取出并放在相邻空位，坐标和滚动位置均保持正确。
func _test_scrolled(checks, lab) -> void:
	lab.create_container("滚动分割", Vector2i(10, 8), InventoryManager.ServiceType.GRID)
	var window = lab.windows["滚动分割"]
	window.position = Vector2(24, 24)
	window.move_to_front()
	lab.manager.add_to_container("滚动分割", 1004, 7, Vector2i(9, 6), true)
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	for frame in range(3):
		await checks.get_tree().process_frame
	scroll.scroll_horizontal = int(scroll.get_h_scroll_bar().max_value)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for frame in range(2):
		await checks.get_tree().process_frame
	var offset := Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
	var board = scroll.get_node("Board")
	await _take(checks, board, Vector2i(9, 7))
	await _place(checks, board, Vector2i(8, 6))
	checks._expect(lab.manager.get_item_at("滚动分割", Vector2i(9, 6)).instance.quantity == 4, "滚动后分割正确定位源")
	checks._expect(lab.manager.get_item_at("滚动分割", Vector2i(8, 7)).instance.quantity == 3, "滚动后分割正确定位新栈占位")
	checks._expect(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical) == offset, "分割刷新保持滚动位置")

## 发送真实中键按下与释放，返回原生拖拽携带的数据，验证无需持续长按中键。
func _take(checks, board: Control, cell: Vector2i) -> Dictionary:
	var point := _point(board, cell)
	await checks._motion(point, 0)
	await checks._button(point, true, MOUSE_BUTTON_MIDDLE)
	await checks._button(point, false, MOUSE_BUTTON_MIDDLE)
	checks._expect(checks.get_viewport().gui_is_dragging(), "中键点击启动半栈拖拽，松开后保持")
	var data: Variant = checks.get_viewport().gui_get_drag_data()
	return data if data is Dictionary else {}

## 左键点击落点完成原生 force_drag 放置或取消，释放后预览必须清理。
func _place(checks, board: Control, cell: Vector2i) -> void:
	var point := _point(board, cell)
	await checks._motion(point, 0)
	await checks._button(point, true)
	await checks._button(point, false)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "左键确认后清理分割预览")

## 发送 Esc 的完整按下/释放，验证引擎的原生取消路径。
func _escape(checks) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await checks.get_tree().process_frame

## 右键取消原生拖拽，不额外构造 UI 控件或修改服务数据。
func _right_cancel(checks, board: Control) -> void:
	var point := _point(board, Vector2i.ZERO)
	await checks._button(point, true, MOUSE_BUTTON_RIGHT)
	await checks._button(point, false, MOUSE_BUTTON_RIGHT)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "右键取消中键分割")

## 查找引擎实际挂载的预制物品拖拽预览。
func _preview(checks) -> Control:
	for control in checks.get_viewport().find_children("*", "PanelContainer", true, false):
		if control.scene_file_path == "res://UI/Inventory/inventory_item.tscn" and control.get_parent().name != "Items":
			return control
	return null

## 将含滚动偏移的画板坐标转换到实际输入坐标。
func _point(board: Control, cell: Vector2i) -> Vector2:
	return board.global_position + Vector2(cell * board.cell_size) + Vector2(26, 26)
