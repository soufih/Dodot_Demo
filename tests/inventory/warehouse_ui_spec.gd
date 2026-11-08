extends Node
## 仓库共用网格窗口，使用实际按钮、滚轮和原生拖放验证多格显示与整理选择刷新。

const DEFINITION = preload("res://Rescource/Data/Inventory/home_warehouse.tres")
const BAG := "warehouse_ui_bag"
var checks = preload("res://tests/inventory/spec_context.gd").new()
var _last_pointer := Vector2.ZERO
@onready var manager = $Manager
@onready var window = $Workspace/Warehouse
@onready var board = $Workspace/Warehouse/Body/Content/Scroll/Board
@onready var bag_board = $Workspace/Bag/Body/Content/Scroll/Board

## 等待真实布局后初始化资源定义中的仓库，测试结束输出完成标记。
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	await _settle()
	manager.configure(checks.lookup)
	checks.code(manager.create_container(DEFINITION.container_id, DEFINITION.size, DEFINITION.service_type), InventoryResult.Code.OK, "按仓库定义创建 UI 数据")
	manager.create_container(BAG, Vector2i(4, 4), InventoryManager.ServiceType.GRID)
	checks.code(window.bind(manager, DEFINITION.container_id, DEFINITION.service_type, checks.lookup), InventoryResult.Code.OK, "仓库类型绑定共用网格窗口")
	$Workspace/Bag.bind(manager, BAG, InventoryManager.ServiceType.GRID, checks.lookup)
	var item: ItemInstance = manager.add_to_container(DEFINITION.container_id, 4, 1, Vector2i(6, 2)).payload
	await _settle()
	checks.expect(window.get_node("Title/Row/Organize").visible, "仓库显示场景声明的整理按钮")
	checks.expect(not $Workspace/Bag.get_node("Title/Row/Organize").visible, "普通网格背包不显示整理按钮")
	checks.expect(window.get_node("Body/Content/Type").text.begins_with("仓库"), "仓库类型说明正确")
	checks.equal(board.get_node("Items").get_child(0).size, Vector2(150, 46), "仓库静态长条按三个网格显示，不退化为单格")
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	checks.expect(scroll.get_h_scroll_bar().visible and scroll.get_v_scroll_bar().visible, "超宽超高仓库保留双向滚动")
	var selected: Array = []
	window.item_selected.connect(func(_id, record): selected.append(record))
	await _wheel(true, true)
	var source: Vector2 = board.global_position + Vector2(7 * 52 + 26, 2 * 52 + 26)
	await _motion(source, 0)
	await _button(source, true)
	await _button(source, false)
	checks.equal(selected.back().instance.instance_id, item.instance_id, "滚动后可选择仓库多格物品")
	var revision: int = manager.get_snapshot(DEFINITION.container_id).revision
	var organize: Control = window.get_node("Title/Row/Organize")
	await _click(organize.get_global_rect().get_center())
	checks.equal(manager.get_item_at(DEFINITION.container_id, Vector2i(2, 0)).instance.instance_id, item.instance_id, "实际点击整理按钮后按完整网格重新摆放")
	checks.equal(manager.get_snapshot(DEFINITION.container_id).revision, revision + 1, "按钮整理仅提交一次")
	checks.equal(selected.back().instance.instance_id, item.instance_id, "整理保留选择的实例身份")
	checks.equal(selected.back().anchor, Vector2i.ZERO, "整理后外部选择记录使用新锚点")
	checks.expect(not window.dragging, "点击整理按钮不拖动窗口")
	await _click(organize.get_global_rect().get_center())
	checks.equal(manager.get_snapshot(DEFINITION.container_id).revision, revision + 1, "重复点击整理不递增版本")
	await _wheel(false, true)
	source = board.global_position + Vector2(26, 26)
	await _begin(source)
	var preview := _preview()
	checks.expect(preview != null and preview.size == Vector2(156, 52), "仓库拖拽预览保持完整网格尺寸")
	var target: Vector2 = bag_board.global_position + Vector2(26, 26)
	await _motion(target, MOUSE_BUTTON_MASK_LEFT)
	await _button(target, false)
	checks.equal(manager.get_item_at(BAG, Vector2i(2, 0)).instance.instance_id, item.instance_id, "真实拖放从仓库取出多格物品")
	checks.expect(manager.get_snapshot(DEFINITION.container_id).items.is_empty(), "取出清空仓库占位")
	await _wheel(true, false)
	await _wheel(true, true)
	target = board.global_position + Vector2(7 * 52 + 26, 11 * 52 + 26)
	await _begin(bag_board.global_position + Vector2(26, 26))
	await _motion(target, MOUSE_BUTTON_MASK_LEFT)
	await _button(target, false)
	checks.equal(manager.get_item_at(DEFINITION.container_id, Vector2i(9, 11)).instance.instance_id, item.instance_id, "滚动后真实存入仓库末行，正确定位完整矩形")
	checks.expect(manager.get_snapshot(BAG).items.is_empty(), "存入后背包没有复制物品")
	await _test_scaled_preview()
	var before: Dictionary = checks.value(manager.get_snapshot(DEFINITION.container_id))
	window.unbind()
	$Workspace/Bag.unbind()
	checks.expect(organize.disabled, "解绑后禁用仓库整理按钮")
	organize.pressed.emit()
	checks.equal(checks.value(manager.get_snapshot(DEFINITION.container_id)), before, "解绑后发出按钮事件不修改数据或调用空 Manager")
	checks.equal(manager.container_changed.get_connections().size(), 0, "关闭视图解除所有订阅")
	checks.code(window.bind(manager, DEFINITION.container_id, DEFINITION.service_type, checks.lookup), InventoryResult.Code.OK, "仓库视图可以重新绑定同一会话")
	checks.equal(checks.value(manager.get_snapshot(DEFINITION.container_id)), before, "关闭和重开界面不清空仓库")
	window.unbind()
	window.warehouse_manager = WarehouseManager
	checks.code(window.bind(manager, DEFINITION.container_id, DEFINITION.service_type, checks.lookup), InventoryResult.Code.RULE_REJECTED, "独立 UI 不能误用全局仓库管理器")
	checks.expect(organize.disabled, "管理器会话不匹配时整理按钮保持禁用")
	checks.equal(checks.value(manager.get_snapshot(DEFINITION.container_id)), before, "拒绝错误管理器绑定不改变物品状态")
	window.warehouse_manager = $WarehouseManager
	print("WAREHOUSE_UI_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 真实拖放预览脱离源窗口后仍须匹配缩放后的格子，旋转与半栈沿用相同比例。
func _test_scaled_preview() -> void:
	window.scale = Vector2(0.6, 0.6)
	$Workspace/Bag.scale = Vector2(0.6, 0.6)
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	var item: ItemInstance = manager.add_to_container(BAG, 2, 6, Vector2i.ZERO).payload
	await _settle()
	var source: Vector2 = bag_board.get_global_transform() * Vector2(26, 26)
	await _begin(source)
	_check_preview_size(Vector2(104, 52), bag_board, "缩放背包普通拖动")
	await _key(KEY_R)
	_check_preview_size(Vector2(52, 104), bag_board, "缩放背包按 R 旋转")
	var target: Vector2 = board.get_global_transform() * Vector2(26, 26)
	await _motion(target, MOUSE_BUTTON_MASK_LEFT)
	_check_preview_size(Vector2(52, 104), board, "悬停缩放仓库")
	await _button(target, false)
	var stored: Dictionary = manager.get_item_at(DEFINITION.container_id, Vector2i.ZERO)
	checks.expect(not stored.is_empty() and stored.instance.instance_id == item.instance_id and stored.instance.rotated, "缩放后按实际格子落地，保留身份和旋转")
	var before: Dictionary = checks.value(manager.get_snapshot(DEFINITION.container_id))
	await _motion(target, 0)
	await _button(target, true, MOUSE_BUTTON_MIDDLE)
	await _button(target, false, MOUSE_BUTTON_MIDDLE)
	checks.expect(get_viewport().gui_is_dragging(), "缩放仓库启动半栈预览")
	_check_preview_size(Vector2(52, 104), board, "缩放仓库半栈拖动")
	await _key(KEY_ESCAPE)
	checks.expect(not get_viewport().gui_is_dragging(), "取消后清理缩放预览")
	checks.equal(checks.value(manager.get_snapshot(DEFINITION.container_id)), before, "取消半栈预览不修改真实数据")

## 读取引擎挂载并完成布局后的实际显示大小，避免只验证未缩放的逻辑尺寸。
func _check_preview_size(footprint: Vector2, source: Control, label: String) -> void:
	var preview := _preview()
	checks.expect(preview != null, label + " 存在物品预览")
	if preview == null:
		return
	checks.equal(preview.size, footprint, label + " 保留完整逻辑占格")
	var expected := footprint * source.get_global_transform().get_scale()
	checks.expect(preview.get_global_rect().size.is_equal_approx(expected), label + " 实际显示大小与格子一致")

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

## 在仓库内容区域发送完整滚轮按下与释放，Shift 控制水平滚动。
func _wheel(down: bool, horizontal: bool) -> void:
	var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
	var point := scroll.global_position + Vector2(4, 4)
	await _motion(point, 0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.shift_pressed = horizontal
		event.factor = 1000
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()

## 使用真实 GUI 点击，测试整理按钮不会触发标题拖动。
func _click(point: Vector2) -> void:
	await _motion(point, 0)
	await _button(point, true)
	await _button(point, false)

## 长按并移动超过阈值，确认原生拖放已启动。
func _begin(point: Vector2) -> void:
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(18, 0), MOUSE_BUTTON_MASK_LEFT)
	checks.expect(get_viewport().gui_is_dragging(), "仓库交互通过真实输入启动原生拖放")

## 输入管线中的鼠标移动保持位置与按钮掩码同步。
func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _last_pointer
	event.button_mask = buttons
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发送左键按下与释放，控制点来自场景组件的实际坐标。
func _button(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (1 << (int(button) - 1)) if pressed else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

## 排除静态物品视图，读取引擎挂载的拖放预览。
func _preview() -> Control:
	for node in get_viewport().find_children("*", "PanelContainer", true, false):
		if node.scene_file_path == "res://UI/Inventory/inventory_item.tscn" and node.get_parent().name != "Items":
			return node
	return null

## 等待滚动偏移、界面排序和刷新稳定后读取实际矩形。
func _settle() -> void:
	for frame in range(4):
		await get_tree().process_frame
