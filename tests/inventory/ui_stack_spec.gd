extends RefCounted
## 真实鼠标拖放的堆叠交互回归；复用既有 .tscn 测试台，不创建控件。

## 验证同容器、跨类型的默认堆叠与不同物品交换，以及数量视图与选择状态。
func run(checks, lab) -> void:
	lab.create_container("堆叠网格", Vector2i(5, 3), InventoryManager.ServiceType.GRID)
	lab.create_container("堆叠栏位", Vector2i(4, 3), InventoryManager.ServiceType.SLOT)
	var grid_window = lab.windows["堆叠网格"]
	var slot_window = lab.windows["堆叠栏位"]
	grid_window.position = Vector2(24, 24)
	slot_window.position = Vector2(500, 24)
	grid_window.move_to_front()
	slot_window.move_to_front()
	await checks.get_tree().process_frame
	var grid = grid_window.get_node("Body/Content/Scroll/Board")
	var slot = slot_window.get_node("Body/Content/Scroll/Board")
	var source: ItemInstance
	var target: ItemInstance
	source = lab.manager.add_to_container("堆叠网格", 1004, 7, Vector2i.ZERO, true).payload
	target = lab.manager.add_to_container("堆叠网格", 1004, 8, Vector2i(2, 0)).payload
	await _drag(checks, grid, Vector2i(0, 1), grid, Vector2i(3, 0))
	checks._expect(lab.manager.get_item_at("堆叠网格", Vector2i.ZERO).instance.quantity == 5, "网格部分堆叠余量留在原位置")
	checks._expect(lab.manager.get_item_at("堆叠网格", Vector2i(3, 0)).instance.quantity == 10, "拖到非锚点也定位目标栈")
	checks._expect(grid.get_node("Items").get_child_count() == 2, "部分堆叠保留两个物品视图")
	checks._expect(_quantity(grid, Vector2i.ZERO) == "5" and _quantity(grid, Vector2i(2, 0)) == "10", "部分堆叠刷新双方数量文字")
	checks._expect(lab._selected.record.instance.instance_id == target.instance_id, "堆叠后选择目标实例")
	checks._expect(lab.selection_form.get_node("Description").text.contains("10"), "选择说明显示堆叠后的数量")
	checks._expect(lab.status.text == "已堆叠 2 件物品", "状态栏报告实际合并数量")
	var before: int = lab.manager.get_snapshot("堆叠网格").revision
	await _drag(checks, grid, Vector2i(0, 1), grid, Vector2i(3, 0))
	checks._expect(lab.manager.get_snapshot("堆叠网格").revision == before, "拖到满栈取消且不改变状态")
	var slot_target: ItemInstance
	slot_target = lab.manager.add_to_container("堆叠栏位", 1004, 3, Vector2i.ZERO).payload
	await _drag(checks, grid, Vector2i(0, 1), slot, Vector2i.ZERO)
	var state: Dictionary = lab.manager.get_snapshot("堆叠网格")
	checks._expect(not state.items.has(source.instance_id) and state.cells[0][0] == null and state.cells[1][0] == null, "跨类型完整合并释放源全部网格")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i.ZERO).instance.quantity == 8, "网格到栏位堆叠数量守恒")
	checks._expect(slot.get_node("Items").get_child_count() == 1 and _quantity(slot, Vector2i.ZERO) == "8", "跨容器合并刷新目标视图")
	checks._expect(lab._selected.record.instance.instance_id == slot_target.instance_id, "完整合并后选择仍指向保留的目标")
	var slot_source: ItemInstance
	slot_source = lab.manager.add_to_container("堆叠栏位", 1004, 7, Vector2i(1, 0), true).payload
	await _drag(checks, slot, Vector2i(1, 0), slot, Vector2i.ZERO)
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i(1, 0)).instance.quantity == 5, "栏位内部堆叠保留余量")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i.ZERO).instance.quantity == 10, "栏位内部堆叠遵守上限")
	lab.manager.remove_from_container("堆叠网格", Vector2i(2, 0))
	var next_target: ItemInstance
	next_target = lab.manager.add_to_container("堆叠网格", 1004, 2, Vector2i(2, 0)).payload
	await _drag(checks, slot, Vector2i(1, 0), grid, Vector2i(3, 0))
	checks._expect(not lab.manager.get_snapshot("堆叠栏位").items.has(slot_source.instance_id), "栏位到网格完整合并移除源记录")
	checks._expect(lab.manager.get_item_at("堆叠网格", Vector2i(2, 0)).instance.quantity == 7, "栏位到网格合并到已有目标占位")
	var exchange: ItemInstance
	exchange = lab.manager.add_to_container("堆叠栏位", 1004, 4, Vector2i(2, 0)).payload
	await _drag(checks, slot, Vector2i(2, 0), slot, Vector2i.ZERO, true)
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i.ZERO).instance.instance_id == exchange.instance_id, "Shift 可强制交换同类满栈")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i(2, 0)).instance.instance_id == slot_target.instance_id, "强制交换保留双方身份")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i.ZERO).instance.quantity == 4, "强制交换不合并数量")
	_test_revalidation(checks, lab, grid, slot)
	await _test_default_drop(checks, lab, grid, slot)

## 预览只读且不能代替提交校验；覆盖不兼容/不可堆叠物品和预览后目标被填满。
func _test_revalidation(checks, lab, grid, slot) -> void:
	var source: Dictionary = slot.record_at(Vector2(26, 26))
	var data := {"source_id": "堆叠栏位", "source_pos": source.anchor, "instance": source.instance}
	var before_source: int = lab.manager.get_snapshot("堆叠栏位").revision
	var before_target: int = lab.manager.get_snapshot("堆叠网格").revision
	checks._expect(grid._can_drop_data(Vector2(182, 26), data), "可部分合并的目标接受预览")
	checks._expect(lab.manager.get_snapshot("堆叠栏位").revision == before_source and lab.manager.get_snapshot("堆叠网格").revision == before_target, "堆叠悬停不修改任何容器")
	# 在预览之后通过另一条合法命令填满目标，正式释放必须重新读取容量。
	lab.manager.add_to_container("堆叠网格", 1004, 3, Vector2i.ZERO)
	lab.manager.stack_in_container("堆叠网格", Vector2i.ZERO, Vector2i(2, 0))
	before_target = lab.manager.get_snapshot("堆叠网格").revision
	grid._drop_data(Vector2(182, 26), data)
	checks._expect(lab.status.text.contains("已满"), "预览后满栈显示正式失败原因")
	checks._expect(lab.manager.get_snapshot("堆叠栏位").revision == before_source and lab.manager.get_snapshot("堆叠网格").revision == before_target, "重新校验失败不扣减源或修改目标")
	lab.manager.add_to_container("堆叠栏位", 1002, 3, Vector2i(3, 0))
	checks._expect(slot._can_drop_data(Vector2(182, 26), data), "不同物品默认接受交换意图")
	lab.manager.add_to_container("堆叠栏位", 1001, 1, Vector2i(0, 1))
	lab.manager.add_to_container("堆叠栏位", 1001, 1, Vector2i(1, 1))
	var single: Dictionary = slot.record_at(Vector2(26, 78))
	checks._expect(slot._can_drop_data(Vector2(78, 78), {"source_id": "堆叠栏位", "source_pos": single.anchor, "instance": single.instance}), "不可堆叠物品默认接受交换意图")

## 普通拖放按物品配置区分堆叠与交换，覆盖非锚点、不可堆叠物品、自身及越界失败。
func _test_default_drop(checks, lab, grid, slot) -> void:
	var source: Dictionary = lab.manager.get_item_at("堆叠栏位", Vector2i(3, 0))
	var target: Dictionary = lab.manager.get_item_at("堆叠网格", Vector2i(2, 0))
	await _drag(checks, slot, Vector2i(3, 0), grid, Vector2i(3, 0), false)
	checks._expect(lab.manager.get_item_at("堆叠网格", Vector2i(2, 0)).instance.instance_id == source.instance.instance_id, "普通跨容器拖到非锚点交换到原目标锚点")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i(3, 0)).instance.instance_id == target.instance.instance_id, "普通交换将原目标送回源位置")
	checks._expect(lab._selected.record.instance.instance_id == source.instance.instance_id, "交换后仍选择被拖动的实例")
	var compatible: ItemInstance
	compatible = lab.manager.add_to_container("堆叠网格", 1002, 5, Vector2i(4, 0)).payload
	await _drag(checks, grid, Vector2i(4, 0), grid, Vector2i(2, 0), false)
	checks._expect(lab.manager.get_item_at("堆叠网格", Vector2i(2, 0)).instance.quantity == 8, "同类未满栈无需 Shift 自动堆叠")
	checks._expect(not lab.manager.get_snapshot("堆叠网格").items.has(compatible.instance_id), "同类默认完整堆叠移除源实例")
	lab.manager.add_to_container("堆叠网格", 1002, 3, Vector2i(4, 0))
	var single: Dictionary = lab.manager.get_item_at("堆叠栏位", Vector2i(0, 1))
	var other_single: Dictionary = lab.manager.get_item_at("堆叠栏位", Vector2i(1, 1))
	await _drag(checks, slot, Vector2i(0, 1), slot, Vector2i(1, 1), false)
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i(1, 1)).instance.instance_id == single.instance.instance_id, "不可堆叠物品也默认执行交换")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i(0, 1)).instance.instance_id == other_single.instance.instance_id, "不可堆叠交换保留双方实例")
	lab.manager.add_to_container("堆叠网格", 1004, 2, Vector2i.ZERO)
	var grid_revision: int = lab.manager.get_snapshot("堆叠网格").revision
	await _drag(checks, grid, Vector2i.ZERO, grid, Vector2i(1, 0), false)
	checks._expect(lab.manager.get_snapshot("堆叠网格").revision == grid_revision, "拖到自身其他占位格不移动或修改版本")
	var slot_revision: int = lab.manager.get_snapshot("堆叠栏位").revision
	await _drag(checks, slot, Vector2i(3, 0), grid, Vector2i(4, 0), false)
	checks._expect(lab.status.text.contains("失败"), "普通交换放不下时显示失败原因")
	checks._expect(lab.manager.get_snapshot("堆叠网格").revision == grid_revision and lab.manager.get_snapshot("堆叠栏位").revision == slot_revision, "失败交换保持双方状态版本")
	checks._expect(lab.manager.get_item_at("堆叠栏位", Vector2i(3, 0)).instance.instance_id == target.instance.instance_id, "失败交换保留源实例")

## 默认不按修饰键注入完整鼠标拖放事件，shift=true 时验证强制交换。
func _drag(checks, source: Control, from_cell: Vector2i, target: Control, to_cell: Vector2i, shift: bool = false) -> void:
	var from_point := source.global_position + Vector2(from_cell * source.cell_size) + Vector2(26, 26)
	var to_point := target.global_position + Vector2(to_cell * target.cell_size) + Vector2(26, 26)
	checks._shift(shift)
	await checks._motion(from_point, 0)
	await checks._button(from_point, true)
	await checks._motion(from_point + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	checks._expect(checks.get_viewport().gui_is_dragging(), "堆叠操作触发原生拖拽")
	await checks._motion(to_point, MOUSE_BUTTON_MASK_LEFT)
	await checks._button(to_point, false)
	checks._shift(false)
	checks._expect(not checks.get_viewport().gui_is_dragging(), "释放后清理堆叠拖拽预览")

## 按场景内物品的位置查找实际数量 Label，验证渲染结果而非仅检查数据快照。
func _quantity(board: Control, anchor: Vector2i) -> String:
	for view in board.get_node("Items").get_children():
		if view.position == Vector2(anchor * board.cell_size) + Vector2(3, 3):
			return view.get_node("Quantity").text
	return ""
