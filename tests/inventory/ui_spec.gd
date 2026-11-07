extends Node
## 使用真实测试场景和输入管线，覆盖表单、物品视图与边框拖动。

var _assertions: int = 0
var _failures: int = 0
var _last_pointer: Vector2 = Vector2.ZERO
@onready var lab = $Lab

## 等待布局后运行回归；--ui-capture=路径 切换为仅渲染截图并退出。
func _ready() -> void:
	for frame in range(4):
		await get_tree().process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture="):
			if OS.get_cmdline_user_args().has("--ui-large"):
				await _prepare_large_preview()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--ui-capture="))
			print("INVENTORY_UI_CAPTURE_COMPLETE")
			get_tree().quit()
			return
	_expect(lab.windows.size() == 2, "默认场景提供两类容器")
	_expect(lab.windows["旅行背包"].position != lab.windows["储物箱"].position, "布局完成后初始窗口错开")
	_test_forms()
	await get_tree().process_frame
	await _test_border_drag()
	await _test_drag_preview_sizes()
	_test_item_commands()
	await _test_native_item_drag()
	await preload("res://tests/inventory/ui_scroll_spec.gd").new().run(self, lab)
	await preload("res://tests/inventory/ui_stack_spec.gd").new().run(self, lab)
	await preload("res://tests/inventory/ui_split_spec.gd").new().run(self, lab)
	await preload("res://tests/inventory/ui_drag_rotation_spec.gd").new().run(self, lab)
	print("INVENTORY_UI_TEST_RESULT assertions=%d failures=%d" % [_assertions, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

## 仅供真实渲染检查：展示大容器及滚动后的末格，交互行为仍由独立滚轮用例验证。
func _prepare_large_preview() -> void:
	lab.create_container("可滚动背包", Vector2i(10, 8), InventoryManager.ServiceType.GRID)
	var window = lab.windows["可滚动背包"]
	window.position = Vector2(460, 24)
	lab.manager.add_to_container("可滚动背包", 1002, 9, Vector2i(9, 7))
	lab.manager.add_to_container("可滚动背包", 1003, 1, Vector2i(6, 4))
	for frame in range(3):
		await get_tree().process_frame
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	scroll.scroll_horizontal = int(scroll.get_h_scroll_bar().max_value)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for frame in range(2):
		await get_tree().process_frame

## 通过场景内按钮信号执行添加操作，同时检查显示结果、失败提示和后端状态。
func _test_forms() -> void:
	var form = lab.container_form
	form.get_node("Name").text = "UI测试容器"
	form.get_node("Type").select(0)
	form.get_node("Dimensions/Width").value = 4
	form.get_node("Dimensions/Height").value = 4
	form.get_node("Create").pressed.emit()
	_expect(lab.windows.has("UI测试容器"), "创建按钮实例化完整窗口场景")
	var state: Dictionary = lab.manager.get_snapshot("UI测试容器")
	_expect(state.size == Vector2i(4, 4), "表单宽高传入后端")
	var count: int = lab.windows.size()
	form.get_node("Create").pressed.emit()
	_expect(lab.windows.size() == count, "重复 ID 不生成多余窗口")
	_expect(lab.status.text.contains("失败"), "重复 ID 显示失败信息")
	form.get_node("Name").text = "单格测试容器"
	form.get_node("Type").select(1)
	form.get_node("Create").pressed.emit()
	var items = lab.item_form
	# 通过物品表单向网格放入旋转长剑。
	lab._set_target("UI测试容器")
	items.get_node("Config").select(0)
	items.get_node("Config").item_selected.emit(0)
	items.get_node("Rotated").button_pressed = true
	_expect(not items.has_node("Position"), "快速添加表单无需手动输入坐标")
	items.get_node("Add").pressed.emit()
	state = lab.manager.get_snapshot("UI测试容器")
	_expect(state.items.size() == 1, "添加物品按钮写入实例")
	_expect(state.cells[0][0] != null and state.cells[0][2] == state.cells[0][0], "旋转选项影响网格占位")
	var board = lab.windows["UI测试容器"].get_node("Body/Content/Scroll/Board")
	_expect(board.get_node("Cells").get_child_count() == 16, "格子由场景按尺寸实例化")
	_expect(board.get_node("Items").get_child_count() == 1, "物品视图订阅变更通知刷新")
	_expect(board.get_node("Items").get_child(0).size == Vector2(150, 46), "多格物品按实际占位渲染")
	var revision: int = state.revision
	items.get_node("Add").pressed.emit()
	_expect(lab.manager.get_snapshot("UI测试容器").revision == revision + 1, "再次点击快速添加只增加一次版本")
	_expect(lab.manager.get_item_at("UI测试容器", Vector2i(0, 1)).instance.config_id == 1001, "再次添加自动跳过已占用区域")
	_expect(lab.status.text.contains("(0, 1)"), "快速添加显示实际放置位置")
	# 下游拖放回归使用独立固定布局；先验证快速添加结果，再清理第二把长剑。
	lab.manager.remove_from_container("UI测试容器", Vector2i(0, 1))
	items.get_node("Config").select(1)
	items.get_node("Config").item_selected.emit(1)
	items.get_node("Amount").value = 5
	items.get_node("Add").pressed.emit()
	_expect(lab.manager.get_item_at("UI测试容器", Vector2i(3, 0)).instance.quantity == 5, "快速添加按首个适配空格保存表单数量")
	_expect(items.get_node("Rotated").disabled, "不可旋转配置禁用旋转选项")
	lab.manager.move_in_container("UI测试容器", Vector2i(3, 0), Vector2i(0, 3))
	lab._set_target("单格测试容器")
	items.get_node("Config").select(2)
	items.get_node("Config").item_selected.emit(2)
	items.get_node("Add").pressed.emit()
	state = lab.manager.get_snapshot("单格测试容器")
	_expect(state.cells[0][0] != null and state.cells[0][1] == null, "普通背包 UI 使用单格规则")
	lab.create_container("快速添加容量测试", Vector2i.ONE, InventoryManager.ServiceType.GRID)
	items.get_node("Config").select(1)
	items.get_node("Config").item_selected.emit(1)
	items.get_node("Amount").value = 5
	items.get_node("Add").pressed.emit()
	_expect(lab.manager.get_item_at("快速添加容量测试", Vector2i.ZERO).instance.quantity == 5, "小容器首次快速添加成功")
	revision = lab.manager.get_snapshot("快速添加容量测试").revision
	items.get_node("Add").pressed.emit()
	_expect(lab.manager.get_snapshot("快速添加容量测试").revision == revision, "无适配位置时快速添加保持版本")
	_expect(lab.status.text.contains("失败") and lab.status.text.contains("没有可容纳"), "无适配位置时显示失败原因")
	lab.create_container("快速添加旋转测试", Vector2i(3, 1), InventoryManager.ServiceType.GRID)
	items.get_node("Config").select(0)
	items.get_node("Config").item_selected.emit(0)
	items.get_node("Add").pressed.emit()
	state = lab.manager.get_snapshot("快速添加旋转测试")
	_expect(state.items.size() == 1 and state.revision == 1, "自动旋转快速添加仅创建一栈并提交一次")
	var rotated_item: ItemInstance = lab.manager.get_item_at("快速添加旋转测试", Vector2i.ZERO).instance
	_expect(rotated_item.rotated and state.cells[0][2] == rotated_item.instance_id, "Lab 未指定旋转时自动转为适配的横向占位")
	var rotated_board = lab.windows["快速添加旋转测试"].get_node("Body/Content/Scroll/Board")
	_expect(rotated_board.get_node("Items").get_child(0).size == Vector2(150, 46), "Lab 按自动旋转后的实际占位显示物品")
	_expect(not items.get_node("Rotated").button_pressed, "自动回退不修改表单中的首选方向")
	_expect(lab.status.text.contains("(0, 0)"), "自动旋转添加显示实际锚点")

## 通过视口真实鼠标事件覆盖四边拖动、松开、内容区域、右键、失焦和边界约束。
func _test_border_drag() -> void:
	var window = lab.windows["UI测试容器"]
	var other = lab.windows["储物箱"]
	var other_before: Vector2 = other.position
	window.move_to_front()
	window.position = Vector2(100, 80)
	await get_tree().process_frame
	var unchanged: Dictionary = lab.manager.get_snapshot("UI测试容器")
	for handle in ["Title", "TopBorder", "LeftBorder", "RightBorder", "BottomBorder"]:
		window.position = Vector2(100, 80)
		await get_tree().process_frame
		var border: Control = window.get_node(handle)
		var point := border.get_global_rect().get_center()
		var before: Vector2 = window.position
		await _motion(point, 0)
		await _button(point, true)
		_expect(window.dragging, handle + " 左键按下开始拖动")
		for frame in range(3):
			await get_tree().process_frame
		_expect(window.position == before and window.dragging, handle + " 保持长按时不跳动")
		await _motion(point + Vector2(35, 24), MOUSE_BUTTON_MASK_LEFT)
		_expect(window.position.is_equal_approx(before + Vector2(35, 24)), handle + " 持续按住移动窗口且不跳动")
		# 松开点故意不在边框内，检查全局释放处理。
		await _button(point + Vector2(70, 50), false)
		_expect(not window.dragging, handle + " 边框外松开结束拖动")
		var stopped: Vector2 = window.position
		await _motion(point + Vector2(90, 70), 0)
		_expect(window.position == stopped, handle + " 松开后不再移动")
	var board: Control = window.get_node("Body/Content/Scroll/Board")
	var content_point := board.global_position + Vector2(26, 26)
	var before: Vector2 = window.position
	await _button(content_point, true)
	_expect(not window.dragging, "物品内容区域不会开始窗口拖动")
	await _button(content_point, false)
	_expect(window.position == before, "点击内容不移动窗口")
	var title_point: Vector2 = window.get_node("Title").get_global_rect().get_center()
	await _button(title_point, true, MOUSE_BUTTON_RIGHT)
	await _motion(title_point + Vector2(20, 20), MOUSE_BUTTON_MASK_RIGHT)
	_expect(not window.dragging and window.position == before, "右键不能拖动窗口")
	await _button(title_point, false, MOUSE_BUTTON_RIGHT)
	await _button(title_point, true)
	await _motion(Vector2(-500, -500), MOUSE_BUTTON_MASK_LEFT)
	_expect(window.position == Vector2.ZERO, "拖动不能移出工作区左上角")
	await _motion(Vector2(4000, 4000), MOUSE_BUTTON_MASK_LEFT)
	_expect(window.position.is_equal_approx((lab.workspace.size - window.size).max(Vector2.ZERO)), "拖动不能移出工作区右下角")
	window.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not window.dragging, "窗口失焦取消长按拖动")
	await _button(Vector2(4000, 4000), false)
	_expect(other.position == other_before, "拖动仅改变当前窗口")
	_expect(lab.manager.get_snapshot("UI测试容器").revision == unchanged.revision, "窗口拖动不修改物品版本")

## 用原生拖拽检查各形状的实际预览尺寸，释放到原锚点不改变物品数据。
func _test_drag_preview_sizes() -> void:
	await _check_drag_preview("UI测试容器", Vector2(26, 26), Vector2(156, 52), "旋转长条 3×1")
	_expect(lab.manager.rotate_in_container("UI测试容器", Vector2i.ZERO, false).is_ok(), "准备未旋转长条预览")
	await _check_drag_preview("UI测试容器", Vector2(26, 26), Vector2(52, 156), "未旋转长条 1×3")
	_expect(lab.manager.rotate_in_container("UI测试容器", Vector2i.ZERO, true).is_ok(), "恢复长条方向")
	await _check_drag_preview("UI测试容器", Vector2(26, 182), Vector2(52, 52), "网格单格栈")
	# 自行准备额外形状，不依赖测试台可由开发者调整的默认演示物品。
	_expect(lab.manager.add_to_container("UI测试容器", 1003, 1, Vector2i(2, 1)).is_ok(), "准备方形预览物品")
	await _check_drag_preview("UI测试容器", Vector2(130, 78), Vector2(104, 104), "网格方形 2×2", "单格测试容器")
	_expect(lab.manager.remove_from_container("UI测试容器", Vector2i(2, 1)).is_ok(), "清理方形预览物品")
	_expect(lab.manager.add_to_container("UI测试容器", 1004, 3, Vector2i(0, 2)).is_ok(), "准备横向两格预览物品")
	await _check_drag_preview("UI测试容器", Vector2(26, 130), Vector2(104, 52), "网格长条 2×1")
	_expect(lab.manager.remove_from_container("UI测试容器", Vector2i(0, 2)).is_ok(), "清理横向两格预览物品")
	await _check_drag_preview("单格测试容器", Vector2(26, 26), Vector2(104, 104), "普通背包中的 2×2 配置", "UI测试容器")
	_expect(lab.manager.add_to_container("单格测试容器", 1001, 1, Vector2i(1, 0)).is_ok(), "准备普通背包长条物品")
	await _check_drag_preview("单格测试容器", Vector2(78, 26), Vector2(52, 156), "普通背包中的 1×3 配置")
	_expect(lab.manager.rotate_in_container("单格测试容器", Vector2i(1, 0), true).is_ok(), "旋转普通背包长条方向")
	await _check_drag_preview("单格测试容器", Vector2(78, 26), Vector2(156, 52), "普通背包中的旋转 3×1 配置")
	_expect(lab.manager.remove_from_container("单格测试容器", Vector2i(1, 0)).is_ok(), "清理普通背包长条物品")

## 读取引擎实际挂载的拖拽预览，覆盖布局完成后的尺寸而非只检查计算结果。
func _check_drag_preview(id: String, local_point: Vector2, expected: Vector2, label: String, hover_target_id: String = "") -> void:
	var window = lab.windows[id]
	window.position = Vector2(24, 24)
	window.move_to_front()
	await get_tree().process_frame
	var board: Control = window.get_node("Body/Content/Scroll/Board")
	var point := board.global_position + local_point
	var before: int = lab.manager.get_snapshot(id).revision
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	_expect(get_viewport().gui_is_dragging(), label + " 触发原生拖拽")
	var preview: Control = null
	for control in get_viewport().find_children("*", "PanelContainer", true, false):
		if control.scene_file_path == "res://UI/Inventory/inventory_item.tscn" and control.get_parent().name != "Items":
			preview = control
			break
	_expect(preview != null, label + " 复用物品预制场景")
	if preview != null:
		_expect(preview.size.is_equal_approx(expected), label + " 预览为完整占格尺寸，不扣边距")
	await _motion(point + Vector2(20, 4), MOUSE_BUTTON_MASK_LEFT)
	if preview != null:
		_expect(preview.size.is_equal_approx(expected), label + " 拖动过程中尺寸保持固定")
	if not hover_target_id.is_empty():
		var target_window = lab.windows[hover_target_id]
		target_window.position = Vector2(430, 24)
		target_window.move_to_front()
		await get_tree().process_frame
		var target: Control = target_window.get_node("Body/Content/Scroll/Board")
		var target_revision: int = lab.manager.get_snapshot(hover_target_id).revision
		await _motion(target.global_position + Vector2(130, 78), MOUSE_BUTTON_MASK_LEFT)
		if preview != null:
			_expect(preview.size.is_equal_approx(expected), label + " 跨不同类型容器悬停仍保持网格尺寸")
		_expect(lab.manager.get_snapshot(hover_target_id).revision == target_revision, label + " 悬停不修改目标容器")
		await _motion(point + Vector2(20, 4), MOUSE_BUTTON_MASK_LEFT)
	await _button(point + Vector2(20, 4), false)
	_expect(lab.manager.get_snapshot(id).revision == before, label + " 拖回原位不改变版本")

## 验证选择、旋转、移除与原生拖拽的预览/提交回调，数据写入仍经 Manager。
func _test_item_commands() -> void:
	var board = lab.windows["UI测试容器"].get_node("Body/Content/Scroll/Board")
	var target = lab.windows["单格测试容器"].get_node("Body/Content/Scroll/Board")
	var record: Dictionary = board.record_at(Vector2(26, 26))
	lab._on_item_selected("UI测试容器", record)
	lab.selection_form.get_node("Rotate").pressed.emit()
	_expect(not lab.manager.get_item_at("UI测试容器", Vector2i.ZERO).instance.rotated, "选中物品旋转按钮提交方向")
	record = board.record_at(Vector2(26, 26))
	var data := {"source_id": "UI测试容器", "source_pos": record.anchor, "instance": record.instance}
	_expect(target._can_drop_data(Vector2(26, 26), data), "占用目标默认接受交换意图")
	var original_target: int = lab.manager.get_item_at("单格测试容器", Vector2i.ZERO).instance.instance_id
	target._drop_data(Vector2(26, 26), data)
	_expect(lab.manager.get_item_at("单格测试容器", Vector2i.ZERO).instance.instance_id == record.instance.instance_id, "显式交换把源实例放到目标")
	_expect(lab.manager.get_item_at("UI测试容器", Vector2i.ZERO).instance.instance_id == original_target, "显式交换把目标实例放到源锚点")
	var reverse: Dictionary = target.record_at(Vector2(26, 26))
	board._drop_data(Vector2(26, 26), {"source_id": "单格测试容器", "source_pos": reverse.anchor, "instance": reverse.instance})
	_expect(lab.manager.get_item_at("UI测试容器", Vector2i.ZERO).instance.instance_id == record.instance.instance_id, "交换可逆且保留实例身份")
	var revision: int = lab.manager.get_snapshot("UI测试容器").revision
	_expect(target._can_drop_data(Vector2(78, 26), data), "跨类型空格接受拖拽预览")
	_expect(lab.manager.get_snapshot("UI测试容器").revision == revision, "拖拽预览只读")
	target._drop_data(Vector2(78, 26), data)
	_expect(lab.manager.get_snapshot("UI测试容器").items.size() == 1, "跨容器拖放移除源实例")
	_expect(lab.manager.get_item_at("单格测试容器", Vector2i(1, 0)).instance.instance_id == record.instance.instance_id, "跨容器拖放保留实例 ID")
	_expect(target.get_node("Items").get_child_count() == 2, "跨容器拖放刷新目标视图")
	lab.selection_form.get_node("Remove").pressed.emit()
	_expect(lab.manager.get_snapshot("单格测试容器").items.size() == 1, "移除按钮删除完整选中栈")
	_expect(lab.selection_form.get_node("Remove").disabled, "移除后清理选择")
	_expect(not target._can_drop_data(Vector2.ZERO, "unrelated"), "拒绝其他系统的拖拽数据")
	# 允许发起交换意图，但对方 2×2 物品放不到源锚点 (0,3)，正式提交必须失败。
	var herb: Dictionary = board.record_at(Vector2(26, 182))
	var before_source: int = lab.manager.get_snapshot("UI测试容器").revision
	var before_target: int = lab.manager.get_snapshot("单格测试容器").revision
	var invalid_swap := {"source_id": "UI测试容器", "source_pos": herb.anchor, "instance": herb.instance}
	_expect(target._can_drop_data(Vector2(26, 26), invalid_swap), "交换预览只表示明确意图")
	target._drop_data(Vector2(26, 26), invalid_swap)
	_expect(lab.status.text.contains("失败"), "放不下的交换显示正式失败原因")
	_expect(lab.manager.get_snapshot("UI测试容器").revision == before_source, "失败交换保持源状态版本")
	_expect(lab.manager.get_snapshot("单格测试容器").revision == before_target, "失败交换保持目标状态版本")

## 用完整鼠标按下、超过阈值的移动和释放验证 Godot 原生物品拖放链路。
func _test_native_item_drag() -> void:
	var source_window = lab.windows["UI测试容器"]
	var target_window = lab.windows["单格测试容器"]
	source_window.position = Vector2(24, 24)
	target_window.position = Vector2(430, 24)
	source_window.move_to_front()
	await get_tree().process_frame
	var source: Control = source_window.get_node("Body/Content/Scroll/Board")
	var target: Control = target_window.get_node("Body/Content/Scroll/Board")
	var from_point := source.global_position + Vector2(26, 182)
	var to_point := target.global_position + Vector2(130, 78)
	await _motion(from_point, 0)
	await _button(from_point, true)
	await _motion(from_point + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	_expect(get_viewport().gui_is_dragging(), "鼠标长按移动触发原生物品拖拽")
	await _motion(to_point, MOUSE_BUTTON_MASK_LEFT)
	await _button(to_point, false)
	var state: Dictionary = lab.manager.get_snapshot("单格测试容器")
	var id: Variant = state.cells[1][2]
	_expect(id != null and state.items[id].instance.quantity == 5, "原生物品拖放在目标落点提交正确数量")
	_expect(lab.manager.get_snapshot("UI测试容器").items.is_empty(), "原生拖放成功移除源实例")
	_expect(not get_viewport().gui_is_dragging(), "松开鼠标清理原生拖拽预览")

## 注入修饰键状态，验证 Shift 可显式强制交换同类物品。
func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.shift_pressed = pressed
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## 向真实输入管线发送鼠标按钮事件，等待 GUI 分发完成。
func _button(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (1 << (int(button) - 1)) if pressed else 0
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发送带指定按钮掩码的鼠标移动，模拟持续按住或已经松开的状态。
func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = buttons
	event.relative = point - _last_pointer
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 累计断言并输出失败说明，允许一次运行汇总多个交互问题。
func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures += 1
		push_error("UI FAIL: " + description)
