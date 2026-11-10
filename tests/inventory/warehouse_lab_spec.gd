extends Node
## 完整仓库 UI 场景回归：表单、坐标存取、详情、整理、关闭重开与真实拖放。

var checks = preload("res://tests/inventory/spec_context.gd").new()
var _last_pointer := Vector2.ZERO
@onready var lab = $Lab
@onready var forms = $Lab/Tools/Margin/Forms
@onready var bag_board = $Lab/Workspace/Bag/Body/Content/Scroll/Board
@onready var warehouse_board = $Lab/Workspace/Warehouse/Body/Content/Scroll/Board

## 使用既有场景组件执行交互；可选截图只准备显示，不使用合成鼠标操作隐藏窗口。
func _ready() -> void:
	await _settle()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--warehouse-lab-capture="):
			lab._on_item_selected(_bag_id(), _find(_bag_id(), 1001))
			await _settle()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--warehouse-lab-capture="))
			print("WAREHOUSE_LAB_CAPTURE_COMPLETE")
			get_tree().quit()
			return
	checks.code(lab.initialization_result, InventoryResult.Code.OK, "完整仓库 UI 初始化成功")
	checks.equal(lab.manager.get_container_ids().size(), 2, "测试台独立创建背包与仓库")
	checks.equal(lab.manager.get_snapshot(_bag_id()).items.size(), 4, "背包提供四种演示物品")
	checks.equal(lab.manager.get_snapshot(_warehouse_id()).items.size(), 4, "仓库提供四种散放物品")
	checks.equal($Lab/Workspace/Warehouse.scene_file_path, "res://UI/Inventory/warehouse_window.tscn", "使用独立仓库窗口预制场景")
	checks.equal($Lab/Workspace/Warehouse.get_node("Title/Row/Name").text, "仓库", "仓库显示场景配置的中文标题")
	var scroll: ScrollContainer = $Lab/Workspace/Warehouse/Body/Content/Scroll
	checks.expect(not scroll.get_h_scroll_bar().visible and scroll.size.x >= warehouse_board.size.x, "专用仓库窗口完整显示十列，不需要横向滚动")
	checks.expect(scroll.get_v_scroll_bar().visible, "超过十行的仓库仍可纵向滚动")
	checks.expect(not $Lab/Workspace/Warehouse.get_global_rect().intersects($Lab/Details.get_global_rect()), "增宽后的仓库不遮挡实验室详情面板")
	_choose_item(1002)
	forms.get_node("Quantity").value = 4
	await _click(forms.get_node("Add").get_global_rect().get_center())
	checks.equal(lab.manager.get_snapshot(_bag_id()).items.size(), 4, "新增同类物品时优先堆叠，不额外创建新堆")
	var quantities: Array = []
	for record: Dictionary in lab.manager.get_snapshot(_bag_id()).items.values():
		if record.instance.config_id == 1002:
			quantities.append(record.instance.quantity)
	checks.expect(quantities == [12], "表单新增数量合并到已有草药堆")
	var herb := _find(_bag_id(), 1002)
	await _click(_point(bag_board, herb.anchor))
	checks.equal(lab._selected_instance_id, herb.instance.instance_id, "真实点击更新选中身份")
	checks.expect(lab.details.get_node("Name").text.contains("草药"), "详情面板同步物品名称")
	checks.expect(lab.details.get_node("Icon").texture != null, "详情面板显示目录图标")
	forms.get_node("Destination/X").value = 6
	forms.get_node("Destination/Y").value = 0
	checks.expect(not forms.get_node("Deposit").disabled and forms.get_node("Withdraw").disabled, "背包选择仅允许存入")
	await _click(forms.get_node("Deposit").get_global_rect().get_center())
	checks.equal(lab.manager.get_item_at(_warehouse_id(), Vector2i(6, 0)).instance.instance_id, herb.instance.instance_id, "按表单坐标原子存入仓库")
	checks.equal(lab._selected_container, _warehouse_id(), "存入后选择跟随到仓库")
	checks.expect(not forms.get_node("Withdraw").disabled, "存入后可以直接取回所选实例")
	forms.get_node("Destination/X").value = 2
	forms.get_node("Destination/Y").value = 0
	await _click(forms.get_node("Withdraw").get_global_rect().get_center())
	checks.equal(lab.manager.get_item_at(_bag_id(), Vector2i(2, 0)).instance.instance_id, herb.instance.instance_id, "按表单坐标原子取回背包")
	checks.equal(lab.manager.get_item_at(_bag_id(), Vector2i(2, 0)).instance.quantity, herb.instance.quantity, "存取保留数量与实例身份")
	var bag_before: Dictionary = checks.value(lab.manager.get_snapshot(_bag_id()))
	var warehouse_before: Dictionary = checks.value(lab.manager.get_snapshot(_warehouse_id()))
	forms.get_node("Destination/X").value = 3
	forms.get_node("Destination/Y").value = 5
	await _click(forms.get_node("Deposit").get_global_rect().get_center())
	checks.expect(lab.get_node("Status").text.contains("失败"), "占用目标显示真实失败反馈")
	checks.equal(checks.value(lab.manager.get_snapshot(_bag_id())), bag_before, "存入失败保留背包完整状态")
	checks.equal(checks.value(lab.manager.get_snapshot(_warehouse_id())), warehouse_before, "存入失败保留仓库完整状态")
	var sword := _find(_warehouse_id(), 1001)
	await _click(_point(warehouse_board, sword.anchor))
	await _click($Lab/Workspace/Warehouse.get_node("Title/Row/Organize").get_global_rect().get_center())
	checks.equal(lab._selected_instance_id, sword.instance.instance_id, "整理后仍选中原实例")
	var organized: Dictionary = lab.manager.get_snapshot(_warehouse_id()).items[sword.instance.instance_id]
	checks.expect(organized.anchor != sword.anchor, "手动整理改变散放物品锚点")
	checks.expect(lab.details.get_node("Data").text.contains(str(organized.anchor)), "整理后详情显示最新锚点")
	warehouse_before = checks.value(lab.manager.get_snapshot(_warehouse_id()))
	await _click(forms.get_node("Toggle").get_global_rect().get_center())
	checks.expect(not $Lab/Workspace/Warehouse.visible and not lab._warehouse_open, "隐藏仓库解绑视图")
	checks.expect(forms.get_node("Deposit").disabled and forms.get_node("Withdraw").disabled, "隐藏期间禁用仓库存取")
	forms.get_node("Target").select(1)
	forms.get_node("Target").item_selected.emit(1)
	checks.expect(forms.get_node("Add").disabled, "隐藏期间不能通过新增表单写入仓库")
	await _click(forms.get_node("Toggle").get_global_rect().get_center())
	checks.expect($Lab/Workspace/Warehouse.visible and lab._warehouse_open, "再次打开仓库恢复视图")
	checks.equal(checks.value(lab.manager.get_snapshot(_warehouse_id())), warehouse_before, "关闭重开不清空仓库")
	checks.expect(not forms.get_node("Add").disabled, "打开后恢复仓库新增操作")
	forms.get_node("Quantity").value = 2
	var previous_quantity: int = $Lab/WarehouseManager.get_item_count(_warehouse_id(), 1002).payload
	await _click(forms.get_node("Add").get_global_rect().get_center())
	checks.equal(lab.manager.get_snapshot(_warehouse_id()).items.size(), 4, "向仓库快速添加同类物品时补已有堆")
	checks.equal($Lab/WarehouseManager.get_item_count(_warehouse_id(), 1002).payload, previous_quantity + 2, "仓库数量统计同步快速堆叠后的新增数量")
	var carried := _find(_bag_id(), 1001)
	var from := _point(bag_board, carried.anchor)
	await _motion(from, 0)
	await _button(from, true)
	await _motion(from + Vector2(18, 0), MOUSE_BUTTON_MASK_LEFT)
	checks.expect(get_viewport().gui_is_dragging(), "新仓库场景支持原生物品拖放")
	var to := _point(warehouse_board, Vector2i(3, 7))
	await _motion(to, MOUSE_BUTTON_MASK_LEFT)
	await _button(to, false)
	checks.equal(lab.manager.get_item_at(_warehouse_id(), Vector2i(3, 9)).instance.instance_id, carried.instance.instance_id, "真实拖放存入完整三格长剑")
	checks.expect(not get_viewport().gui_is_dragging(), "松开鼠标清理拖拽预览")
	await _click(forms.get_node("Reset").get_global_rect().get_center())
	checks.equal(lab.manager.get_snapshot(_bag_id()).items.size(), 4, "重置恢复背包演示内容")
	checks.equal(lab.manager.get_snapshot(_warehouse_id()).items.size(), 4, "重置恢复仓库散放内容")
	checks.equal(lab._selected_instance_id, -1, "重置清理过期选择")
	await _test_workspace_scene()
	print("WAREHOUSE_LAB_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 正式工作区也按仓库类型选择新的专用场景，而非仅在演示中使用。
func _test_workspace_scene() -> void:
	UIManager.configure_scene(self, [UIId.INVENTORY])
	InventoryManager.create_container("warehouse_window_test", Vector2i(10, 12), InventoryManager.ServiceType.WAREHOUSE)
	var ui = UIManager.open(UIId.INVENTORY, {"container_id": "warehouse_window_test", "service_type": InventoryManager.ServiceType.WAREHOUSE}, self)
	await _settle()
	checks.expect(ui != null, "正式工作区可以打开仓库")
	if ui != null:
		checks.equal(ui.windows[0].scene_file_path, "res://UI/Inventory/warehouse_window.tscn", "正式工作区选择专用仓库场景")
		checks.expect(ui.windows[0].get_node("Title/Row/Organize").visible, "正式仓库场景提供整理按钮")
		var scroll: ScrollContainer = ui.windows[0].get_node("Body/Content/Scroll")
		checks.expect(not scroll.get_h_scroll_bar().visible and scroll.size.x >= scroll.get_node("Board").size.x, "正式工作区也完整显示仓库一行十格")
	UIManager.close(UIId.INVENTORY)
	InventoryManager.unregister_container("warehouse_window_test")

## 按配置 ID 选择已存在的下拉项，同时触发数量上限同步。
func _choose_item(id: int) -> void:
	var choice: OptionButton = forms.get_node("Item")
	for index in range(choice.item_count):
		if choice.get_item_id(index) == id:
			choice.select(index)
			choice.item_selected.emit(index)
			return

## 从隔离快照中寻找测试实例，不依赖自动添加的新物品锚点。
func _find(container: String, config: int) -> Dictionary:
	for record: Dictionary in lab.manager.get_snapshot(container).items.values():
		if record.instance.config_id == config:
			return record
	return {}

## 使用实际画布变换定位鼠标，兼容窗口移动和滚动偏移。
func _point(board: Control, cell: Vector2i) -> Vector2:
	return board.get_global_transform_with_canvas() * (Vector2(cell * 52) + Vector2(26, 26))

## 获取当前演示背包标识。
func _bag_id() -> String:
	return lab.backpack_definition.container_id

## 获取当前演示仓库标识。
func _warehouse_id() -> String:
	return lab.warehouse_definition.container_id

## 发出完整 GUI 点击序列。
func _click(point: Vector2) -> void:
	await _motion(point, 0)
	await _button(point, true)
	await _button(point, false)

## 保持 Input 中鼠标位置与按钮状态同步。
func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _last_pointer
	event.button_mask = buttons
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发送左键按下或释放，验证实际控件接收交互。
func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

## 等待容器布局与 UI 刷新稳定。
func _settle() -> void:
	for frame in range(4):
		await get_tree().process_frame
