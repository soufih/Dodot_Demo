extends Node
## 仓库世界接入：真实角色移动、E 交互、三窗口存取、家园摆放与跨场景会话。

const LAB := "res://Scene/Inventory/WarehouseGameplayLab.tscn"
const HOME := "res://Scene/Map/Home/Home.tscn"
const INVALID = preload("res://tests/inventory/warehouse_invalid_fixtures.tscn")
var checks = preload("res://tests/inventory/spec_context.gd").new()
var scene: Node
var hero: HeroProperty
var inventory: PlayerInventoryComponent
var warehouse: WarehouseInteractable
var _last_pointer := Vector2.ZERO

## 等待 Autoload 初始化完成后运行，测试驱动独立于被切换的世界场景。
func _ready() -> void:
	_run.call_deferred()

## 验证交互对象只管理界面和会话绑定，仓库物品不会随场景节点销毁。
func _run() -> void:
	reparent(get_tree().root)
	if await _capture_preview():
		return
	checks.equal(get_tree().change_scene_to_file(LAB), OK, "加载真实仓库接入测试台")
	await _wait_for_world(false)
	checks.code(warehouse.initialization_result, InventoryResult.Code.OK, "世界交互物创建仓库会话")
	checks.expect(InventoryManager.is_warehouse(_warehouse_id()), "稳定 ID 对应真实仓库服务")
	checks.expect(not InventoryManager.is_warehouse(inventory.definition.container_id), "背包不会被识别为仓库")
	checks.expect(not warehouse.can_interact(self), "没有背包组件的对象不能打开仓库")
	_test_invalid_definitions()
	await _key(KEY_E)
	checks.expect(not InventoryManager.get_snapshot(inventory.definition.container_id).items.is_empty(), "沿用真实拾取流程准备背包物品")
	checks.code(inventory.receive_item(10, 1), InventoryResult.Code.OK, "准备一件正式武器用于存取")
	await _move_to_warehouse()
	checks.expect(hero.InteractBox.get_current_interactable() == warehouse, "角色物理检测选中仓库交互区")
	checks.expect(hero.get_node("PlayerUI/InteractionPrompt").text.contains("仓库"), "角色显示 E 打开仓库提示")
	await _key(KEY_E)
	await _settle()
	var ui = UIManager.get_ui(UIId.INVENTORY)
	checks.expect(UIManager.is_open(UIId.INVENTORY), "真实 E 输入打开仓库界面")
	checks.equal(ui.windows.size(), 3, "沿用背包装备列表并追加仓库窗口")
	checks.equal(ui.windows[2].container_id, _warehouse_id(), "第三个窗口绑定世界仓库")
	checks.equal(ui.windows[2].scene_file_path, "res://UI/Inventory/warehouse_window.tscn", "世界交互使用正式仓库 UI")
	checks.expect(UIManager.gameplay_blocked and not get_tree().paused, "仓库界面屏蔽游戏输入但不暂停世界")
	checks.expect(not warehouse.can_interact(hero), "界面打开期间不能重复交互")
	var record := _find_sword()
	var item_id: int = record.instance.instance_id
	await _drag(_bag_point(record.anchor), _warehouse_point(Vector2i(3, 6)))
	checks.equal(InventoryManager.get_item_at(_warehouse_id(), Vector2i(3, 6)).instance.instance_id, item_id, "真实背包到世界仓库拖放保留实例身份")
	var saved := _warehouse_value()
	await _key(KEY_ESCAPE)
	checks.expect(not UIManager.is_open(UIId.INVENTORY) and not hero._InputController.is_banned, "Esc 关闭仓库后恢复角色输入")
	checks.equal(_warehouse_value(), saved, "关闭界面不清空仓库")
	checks.expect(hero.get_node("PlayerUI/InteractionPrompt").visible, "仓库提示可重复使用")
	await _key(KEY_E)
	await _settle()
	checks.expect(UIManager.is_open(UIId.INVENTORY), "同一仓库可以再次通过 E 打开")
	checks.equal(_warehouse_value(), saved, "再次打开不重复创建或重置仓库")
	ui = UIManager.get_ui(UIId.INVENTORY)
	await _click(ui.windows[2].get_node("Title/Row/Organize").get_global_rect().get_center())
	checks.equal(InventoryManager.get_item_at(_warehouse_id(), Vector2i.ZERO).instance.instance_id, item_id, "正式仓库整理按钮通过 Manager 重新摆放")
	await _drag(_warehouse_point(Vector2i.ZERO), _bag_point(Vector2i(4, 4)))
	checks.equal(InventoryManager.get_item_at(inventory.definition.container_id, Vector2i(4, 4)).instance.instance_id, item_id, "世界仓库取回真实背包")
	checks.expect(InventoryManager.get_snapshot(_warehouse_id()).items.is_empty(), "取回后仓库没有复制物品")
	await _drag(_bag_point(Vector2i(4, 4)), _warehouse_point(Vector2i(2, 3)))
	saved = _warehouse_value()
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	await _settle()
	checks.equal(UIManager.get_ui(UIId.INVENTORY).windows.size(), 2, "普通 Tab 仍只打开玩家背包和装备")
	warehouse.queue_free()
	await _settle()
	checks.expect(UIManager.is_open(UIId.INVENTORY), "旧仓库已关闭后销毁，不会误关后来打开的玩家窗口")
	checks.equal(_warehouse_value(), saved, "销毁交互物不删除物品")
	checks.equal(get_tree().reload_current_scene(), OK, "实际重新创建仓库所在场景")
	await _wait_for_world(false)
	checks.expect(not UIManager.is_open(UIId.INVENTORY), "场景退出清理原界面")
	checks.equal(_warehouse_value(), saved, "重载场景复用原仓库内容和版本")
	await _move_to_warehouse()
	await _key(KEY_E)
	await _settle()
	checks.expect(UIManager.is_open(UIId.INVENTORY), "新交互物仍能打开保留数据的仓库")
	warehouse.queue_free()
	await _settle()
	checks.expect(not UIManager.is_open(UIId.INVENTORY), "销毁拥有当前仓库界面的交互物会关闭该界面")
	checks.equal(_warehouse_value(), saved, "关闭拥有的界面后仍保留仓库状态")
	checks.equal(get_tree().change_scene_to_file(HOME), OK, "加载正式家园场景")
	await _wait_for_world(true)
	checks.code(warehouse.initialization_result, InventoryResult.Code.OK, "正式家园已摆放并初始化仓库")
	checks.equal(_warehouse_value(), saved, "测试场景进入家园后同一仓库数据保持不变")
	await _move_to_warehouse()
	checks.expect(hero.InteractBox.get_current_interactable() == warehouse, "正式家园出生点附近可步行进入仓库交互区")
	await _key(KEY_E)
	await _settle()
	checks.expect(UIManager.is_open(UIId.INVENTORY), "正式家园可通过 E 打开仓库")
	checks.equal(UIManager.get_ui(UIId.INVENTORY).windows[2].container_id, _warehouse_id(), "正式家园绑定同一稳定仓库 ID")
	await _key(KEY_ESCAPE)
	checks.equal(get_tree().change_scene_to_file(LAB), OK, "返回接入测试台验证显式新会话")
	await _wait_for_world(false)
	scene.get_node("HUD/Panel/Margin/Rows/Reset").pressed.emit()
	checks.expect(InventoryManager.get_snapshot(_warehouse_id()).items.is_empty(), "显式新会话重置家园仓库")
	checks.equal(InventoryManager.get_snapshot(_warehouse_id()).revision, 0, "重置后仓库版本归零")
	checks.expect(InventoryManager.get_snapshot(inventory.definition.container_id).items.is_empty(), "同时重置玩家背包")
	checks.expect(InventoryManager.is_warehouse(_warehouse_id()), "重置后仍是有效的仓库服务")
	await _test_main_menu_start()
	print("WAREHOUSE_GAMEPLAY_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 使用正式世界的真实 Hero；测试只隔离运行期窗口定位，不修改作者的场景定位资源。
func _wait_for_world(home: bool) -> void:
	for frame in range(90):
		await get_tree().physics_frame
		await get_tree().process_frame
	scene = get_tree().current_scene
	hero = scene.hero if home else scene.get_node("Hero")
	inventory = PlayerInventoryComponent.find_for(hero)
	warehouse = scene.get_node("HomeWarehouse")
	var ui = UIManager.prepare(UIId.INVENTORY, scene)
	ui.window_positions.clear()
	ui.warehouse_window_positions.clear()
	checks.expect(not hero._InputController.is_banned, "真实角色出生后恢复输入")

## 通过按住移动键进入交互范围，不直接调用 interact 冒充真实 E 流程。
func _move_to_warehouse() -> void:
	var target_x := warehouse.global_position.x - 32.0
	await _key_state(KEY_D, true)
	for frame in range(90):
		if hero.global_position.x >= target_x:
			break
		await get_tree().physics_frame
		await get_tree().process_frame
	await _key_state(KEY_D, false)
	for frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame

## 配置错误不覆盖同名背包，不创建错误类型的仓库，也不产生运行异常。
func _test_invalid_definitions() -> void:
	var before: Dictionary = checks.value(InventoryManager.get_snapshot(inventory.definition.container_id))
	var fixtures = INVALID.instantiate()
	scene.add_child(fixtures)
	for name in ["Missing", "WrongType", "Collision"]:
		var invalid: WarehouseInteractable = fixtures.get_node(name)
		checks.expect(not invalid.initialization_result.is_ok() and not invalid.can_interact(hero), "错误仓库配置不可交互：" + name)
		checks.expect(not invalid.get_interaction_text().is_empty(), "错误仓库配置提供提示")
	checks.expect(not InventoryManager.has_container("wrong_warehouse_role"), "错误角色配置没有注册新容器")
	checks.equal(checks.value(InventoryManager.get_snapshot(inventory.definition.container_id)), before, "同名仓库配置不会覆盖已有玩家背包")
	fixtures.queue_free()

## 从真实主菜单开始游戏，验证仓库重置与加载屏到家园的完整入口。
func _test_main_menu_start() -> void:
	checks.code(InventoryManager.add_to_container(_warehouse_id(), 10, 1, Vector2i.ZERO), InventoryResult.Code.OK, "新游戏前准备一件旧仓库物品")
	checks.equal(get_tree().change_scene_to_file("res://Scene/Map/MainScene/MainScene.tscn"), OK, "返回真实主菜单")
	await _settle()
	get_tree().current_scene.get_node("CanvasLayer/Mainmenu/ButtonContainer/gamestart").pressed.emit()
	checks.expect(UIManager.is_open(UIId.LOADING), "主菜单开始游戏进入正式加载层")
	checks.expect(InventoryManager.get_snapshot(_warehouse_id()).items.is_empty(), "主菜单新游戏清空上一会话仓库")
	var loading: LoadingScreenUI = UIManager.get_ui(UIId.LOADING)
	for frame in range(300):
		if loading._ready_to_continue or loading._failed:
			break
		await get_tree().physics_frame
		await get_tree().process_frame
	checks.expect(loading._ready_to_continue and not loading._failed, "正式家园依赖加载完成")
	await _key(KEY_SPACE)
	await _wait_for_world(true)
	checks.equal(get_tree().current_scene.scene_file_path, HOME, "加载屏任意键继续后进入正式家园")
	checks.expect(not UIManager.is_open(UIId.LOADING), "进入家园后释放加载层输入锁")
	checks.expect(InventoryManager.get_snapshot(_warehouse_id()).items.is_empty(), "新家园绑定重置后的仓库")
	checks.expect(InventoryManager.get_snapshot(inventory.definition.container_id).items.is_empty(), "新游戏同时清空背包")
	checks.expect(InventoryManager.get_snapshot(inventory.equipment.definition.container_id).items.is_empty(), "新游戏同时清空装备")

## 保存规范化仓库快照，包含实例、数量、方向、矩阵和版本。
func _warehouse_value() -> Dictionary:
	return checks.value(InventoryManager.get_snapshot(_warehouse_id()))

## 所有场景使用同一正式资源 ID，交互物被释放时仍可查询全局会话。
func _warehouse_id() -> String:
	return preload("res://Rescource/Data/Inventory/home_warehouse.tres").container_id

## 按配置查找真实拾取的武器实例。
func _find_sword() -> Dictionary:
	for record: Dictionary in InventoryManager.get_snapshot(inventory.definition.container_id).items.values():
		if record.instance.config_id == 10:
			return record
	return {}

## 背包与仓库窗口顺序来自玩家容器列表与仓库追加规则。
func _bag_point(cell: Vector2i) -> Vector2:
	var board = UIManager.get_ui(UIId.INVENTORY).windows[0].get_node("Body/Content/Scroll/Board")
	return board.get_global_transform_with_canvas() * (Vector2(cell * 52) + Vector2(26, 26))

## 将仓库真实网格坐标转换为画布鼠标坐标。
func _warehouse_point(cell: Vector2i) -> Vector2:
	var board = UIManager.get_ui(UIId.INVENTORY).windows[2].get_node("Body/Content/Scroll/Board")
	return board.get_global_transform_with_canvas() * (Vector2(cell * 52) + Vector2(26, 26))

## 点击正式 UI 控件，不直接调用整理回调。
func _click(point: Vector2) -> void:
	await _motion(point, 0)
	await _button(point, true)
	await _button(point, false)

## 原生拖放验证输入阈值、目标坐标和释放后的清理。
func _drag(from: Vector2, to: Vector2) -> void:
	await _motion(from, 0)
	await _button(from, true)
	await _motion(from + Vector2(18, 0), MOUSE_BUTTON_MASK_LEFT)
	checks.expect(get_viewport().gui_is_dragging(), "真实交互界面启动原生物品拖拽")
	await _motion(to, MOUSE_BUTTON_MASK_LEFT)
	await _button(to, false)
	checks.expect(not get_viewport().gui_is_dragging(), "释放后清理仓库拖拽预览")

## 同步 Input 鼠标位置及按钮掩码。
func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _last_pointer
	event.button_mask = buttons
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发送真实 GUI 左键事件。
func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

## 按实际物理键码发送按下或释放，供行走和交互使用。
func _key_state(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

## E、Tab、Esc 均使用完整按下释放序列。
func _key(code: Key) -> void:
	await _key_state(code, true)
	await _key_state(code, false)

## 等待窗口排序、生命周期退出与刷新完成。
func _settle() -> void:
	for frame in range(4):
		await get_tree().process_frame

## 原生渲染截图走独立分支，避免系统鼠标位置干扰自动 GUI 拖放；交互断言仍在无头模式运行。
func _capture_preview() -> bool:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--warehouse-gameplay-capture="):
			continue
		get_tree().change_scene_to_file(HOME)
		await _wait_for_world(true)
		await _move_to_warehouse()
		inventory.receive_item(10, 1)
		inventory.receive_item(21, 40)
		InventoryManager.add_to_container(_warehouse_id(), 15, 1, Vector2i(0, 0))
		InventoryManager.add_to_container(_warehouse_id(), 21, 80, Vector2i(2, 2))
		warehouse.interact(hero)
		await _settle()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--warehouse-gameplay-capture="))
		get_tree().quit()
		return true
	return false
