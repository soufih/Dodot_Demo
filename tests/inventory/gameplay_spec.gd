extends Node
## 正式资源、角色组件、世界掉落、交互输入、UIManager 与切场景的集成测试。

const SCOPE = preload("res://tests/inventory/gameplay_scope.tscn")
const DEFINITION = preload("res://tests/inventory/gameplay_definition.tres")
const PLAYER_DEFINITION = preload("res://Rescource/Data/Inventory/player_backpack.tres")
const HERO = preload("res://Scene/Hero/Hero.tscn")

var checks = preload("res://tests/inventory/spec_context.gd").new()
var scope: Node
var actor: Node2D

## 延后到场景全部 ready 后开始，避免测试本身影响组件初始化顺序。
func _ready() -> void:
	_run.call_deferred()

## 依次验证数据与实际输入，再跨场景验证会话，最后清理正式 Autoload 中的测试容器。
func _run() -> void:
	scope = get_parent()
	actor = scope.get_node("Actor")
	UIManager.configure_scene(scope, [UIId.INVENTORY, UIId.PAUSE, UIId.SETTINGS, UIId.DEATH, UIId.END])
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	await _settle()
	# 可单独回归正式主题下的布局，不依赖拾取用例的物品配置。
	if OS.get_cmdline_user_args().has("--inventory-scroll-only"):
		await _test_inventory_scroll_layout()
		UIManager.ui_close_all()
		print("INVENTORY_SCROLL_LAYOUT_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
		get_tree().quit(0 if checks.failures == 0 else 1)
		return
	_test_resources_and_initialization()
	await _test_partial_pickup()
	await _test_mixed_and_duplicate()
	await _test_ui_input()
	await _test_inventory_scroll_layout()
	await _test_scene_lifetime()
	await _test_real_hero()
	UIManager.ui_close_all()
	InventoryManager.unregister_container(DEFINITION.container_id)
	print("INVENTORY_GAMEPLAY_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 检查正式目录占位配置及组件挂载，不依赖 Lab 的演示目录。
func _test_resources_and_initialization() -> void:
	checks.expect(actor.get_node("Inventory").initialization_result.is_ok(), "玩家组件创建正式会话背包")
	checks.expect(InventoryManager.has_container(DEFINITION.container_id), "会话容器可由全局 Manager 查询")
	var sword := ResourceManager.get_item_config(10)
	checks.expect(sword.GridSize == Vector2i(1, 3) and sword.CanRotate and sword.MaxStack == 1, "正式武器占位与旋转配置生效")
	var material := ResourceManager.get_item_config(21)
	checks.expect(material.GridSize == Vector2i.ONE and not material.CanRotate and material.MaxStack == 100, "正式材料使用单格和真实堆叠上限")
	var before: Dictionary = checks.value(InventoryManager.get_snapshot(DEFINITION.container_id))
	checks.code(PlayerInventorySession.ensure(DEFINITION, InventoryManager), InventoryResult.Code.OK, "已有会话可以重复绑定")
	checks.equal(checks.value(InventoryManager.get_snapshot(DEFINITION.container_id)), before, "重复绑定不改变容器版本或内容")

## 超过 MaxStack 的数量按合法栈接收，满包余量保留；腾空后可对同一目标再次按 E。
func _test_partial_pickup() -> void:
	_clear_inventory()
	var original := [{"id": 21, "amount": 250}]
	var dropped := _drop(original)
	await _settle()
	checks.expect(actor.get_node("Detector").get_current_interactable() == dropped.get_node("Pickup"), "真实物理区域进入玩家交互检测")
	checks.expect(actor.get_node("Prompt").visible and actor.get_node("Prompt").text.contains("250"), "场景提示显示可拾取数量")
	checks.expect(dropped.get_node("ItemIcon").texture != null, "掉落场景显示正式物品图标")
	await _key(KEY_E)
	checks.equal(_total(), 200, "真实 E 输入将两栈材料放入背包")
	checks.equal(InventoryManager.get_snapshot(DEFINITION.container_id).items.size(), 2, "超过上限自动拆为两个合法栈")
	checks.equal(dropped.items, [{"id": 21, "amount": 50}], "空间不足的五十份保留在地上")
	checks.equal(original[0].amount, 250, "世界清单不会修改生成器的原始数组")
	checks.equal(dropped.get_node("Amount").text, "50", "部分拾取刷新场景数量标签")
	checks.expect(actor.get_node("Prompt").visible and actor.get_node("Prompt").text.contains("剩余"), "部分拾取保留可重试提示")
	var before: Dictionary = checks.value(InventoryManager.get_snapshot(DEFINITION.container_id))
	await _key(KEY_E)
	checks.equal(checks.value(InventoryManager.get_snapshot(DEFINITION.container_id)), before, "满包重复交互不增加物品或版本")
	checks.equal(dropped.items[0].amount, 50, "满包重试不扣减地面余量")
	checks.expect(actor.get_node("Prompt").visible and actor.get_node("Prompt").text.contains("没有可容纳"), "拾取失败提示不会被交互控制器隐藏")
	InventoryManager.remove_from_container(DEFINITION.container_id, Vector2i.ZERO)
	await _key(KEY_E)
	checks.equal(_total(), 150, "腾出空间后同一交互目标可以继续拾取")
	checks.expect(not is_instance_valid(dropped), "全部拾取后才销毁世界节点")
	checks.expect(actor.get_node("Detector").get_current_interactable() == null, "销毁后检测器清理目标引用")

## 混合清单逐项处理，重复和回调重入不能重复入包，未知配置保留供排查而不吞掉合法条目。
func _test_mixed_and_duplicate() -> void:
	_clear_inventory()
	var inventory: PlayerInventoryComponent = actor.get_node("Inventory")
	var dropped := _drop([{"id": 10, "amount": 1}, {"id": 21, "amount": 3}])
	var result := dropped.collect(inventory.receive_item)
	checks.code(result, InventoryResult.Code.OK, "混合掉落可部分成功")
	checks.equal(result.payload, 3, "只统计实际入包数量")
	checks.equal(dropped.items, [{"id": 10, "amount": 1}], "放不下的多格武器保留，材料仍可入包")
	checks.equal(_total(), 3, "混合拾取数量守恒")
	dropped.queue_free()
	await _settle()
	_clear_inventory()
	dropped = _drop([{"id": 21, "amount": 1}])
	var nested: Array = []
	var on_change := func(_id, _revision, _ids): nested.append(dropped.collect(inventory.receive_item).code)
	InventoryManager.container_changed.connect(on_change, CONNECT_ONE_SHOT)
	checks.code(dropped.collect(inventory.receive_item), InventoryResult.Code.OK, "正常拾取完成")
	checks.equal(nested, [InventoryResult.Code.RULE_REJECTED], "提交通知期间的重复拾取被拒绝")
	checks.code(dropped.collect(inventory.receive_item), InventoryResult.Code.RULE_REJECTED, "排队销毁前重复调用也被拒绝")
	checks.equal(_total(), 1, "重入与重复拾取不复制物品")
	await _settle()
	dropped = _drop([{"id": 999999, "amount": 2}])
	checks.code(dropped.collect(inventory.receive_item), InventoryResult.Code.INVALID_ITEM, "未知掉落配置拒绝入包")
	checks.equal(dropped.items[0].amount, 2, "非法配置失败不扣减地面条目")
	checks.code(inventory.receive_item(21, 0), InventoryResult.Code.INVALID_ITEM, "零数量不能入包")
	dropped.queue_free()
	await _settle()

## Tab 开关正式 UI，界面打开时屏蔽拾取；暂停和其他快捷键屏蔽请求仍然优先。
func _test_ui_input() -> void:
	_clear_inventory()
	actor.get_node("Inventory").receive_item(21, 3)
	await _key(KEY_TAB)
	checks.expect(UIManager.is_open(UIId.INVENTORY), "项目已有 Tab 动作打开正式背包")
	checks.expect(not get_tree().paused and UIManager.gameplay_blocked, "背包阻止游戏输入但不暂停世界")
	checks.expect(actor.get_node("Input").is_banned, "已有 InputController 响应 UI 的游戏输入屏蔽")
	var ui = UIManager.get_ui(UIId.INVENTORY)
	checks.equal(ui.windows.size(), 1, "正式工作区绑定玩家容器")
	checks.equal(ui.windows[0].container_id, DEFINITION.container_id, "UI 显示玩家会话数据")
	var dropped := _drop([{"id": 21, "amount": 1}])
	await _settle()
	await _key(KEY_E)
	checks.equal(_total(), 3, "背包打开时按 E 不会拾取世界物品")
	checks.equal(dropped.items[0].amount, 1, "被屏蔽的交互保留掉落")
	ui.get_node("Close").grab_focus()
	await _key(KEY_TAB)
	checks.expect(not UIManager.is_open(UIId.INVENTORY), "关闭按钮获得焦点时 Tab 仍可关闭背包")
	checks.expect(not UIManager.gameplay_blocked and not actor.get_node("Input").is_banned, "关闭后恢复游戏输入")
	checks.equal(_total(), 3, "关闭窗口不清空业务数据")
	await _key(KEY_E)
	checks.equal(_total(), 4, "关闭后交互恢复")
	await _key(KEY_TAB)
	UIManager.open(UIId.PAUSE)
	await _key(KEY_TAB)
	checks.expect(UIManager.is_open(UIId.PAUSE) and UIManager.is_open(UIId.INVENTORY), "暂停层打开时 Tab 不操作下层背包")
	await _key(KEY_ESCAPE)
	checks.expect(not UIManager.is_open(UIId.PAUSE) and UIManager.is_open(UIId.INVENTORY), "Esc 关闭暂停后保留原背包")
	await _key(KEY_TAB)
	var token := UIManager.acquire_request(scope, false, false, true)
	await _key(KEY_TAB)
	checks.expect(not UIManager.is_open(UIId.INVENTORY), "UI 快捷键屏蔽期间不能打开背包")
	UIManager.release_request(token)
	await _key(KEY_TAB)
	ui = UIManager.get_ui(UIId.INVENTORY)
	var board = ui.windows[0].get_node("Body/Content/Scroll/Board")
	var point: Vector2 = board.global_position + Vector2(26, 26)
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	checks.expect(get_viewport().gui_is_dragging(), "正式背包能发起原生物品拖拽")
	var before: Dictionary = checks.value(InventoryManager.get_snapshot(DEFINITION.container_id))
	await _key(KEY_TAB)
	await _button(point + Vector2(16, 0), false)
	checks.expect(not get_viewport().gui_is_dragging() and not UIManager.is_open(UIId.INVENTORY), "Tab 关闭时取消未完成拖拽")
	checks.equal(checks.value(InventoryManager.get_snapshot(DEFINITION.container_id)), before, "关闭中的拖拽不修改物品状态")
	checks.expect(InventoryManager.container_changed.get_connections().is_empty(), "窗口关闭后解除正式背包订阅")

## 经正式 UIManager 继承全局主题，验证五列十行阈值及单轴滚动不会互相影响。
func _test_inventory_scroll_layout() -> void:
	for scenario in [
		[Vector2i(5, 6), false, false],
		[Vector2i(5, 10), false, false],
		[Vector2i(6, 10), true, false],
		[Vector2i(5, 11), false, true],
		[Vector2i(6, 11), true, true],
	]:
		var dimensions: Vector2i = scenario[0]
		var id := "integrated_scroll_%d_%d" % [dimensions.x, dimensions.y]
		checks.code(InventoryManager.create_container(id, dimensions, InventoryManager.ServiceType.GRID), InventoryResult.Code.OK, id + " 创建夹具")
		var ui = UIManager.open(UIId.INVENTORY, {"container_id": id}, scope)
		await _settle()
		var window = ui.windows[0]
		var scroll: ScrollContainer = window.get_node("Body/Content/Scroll")
		checks.equal(scroll.get_h_scroll_bar().visible, scenario[1], id + " 横向阈值为五列")
		checks.equal(scroll.get_v_scroll_bar().visible, scenario[2], id + " 纵向阈值为十行")
		checks.expect(scroll.get_h_scroll_bar().page >= mini(dimensions.x, 5) * 52, id + " 可见宽度容纳完整格子")
		checks.expect(scroll.get_v_scroll_bar().page >= mini(dimensions.y, 10) * 52, id + " 可见高度容纳完整格子")
		UIManager.close(UIId.INVENTORY)
		await _settle()
		InventoryManager.unregister_container(id)

## 实际更换场景和角色实例，验证原容器、物品 ID 与版本保留，仅新游戏显式重置。
func _test_scene_lifetime() -> void:
	var before: Dictionary = checks.value(InventoryManager.get_snapshot(DEFINITION.container_id))
	await _key(KEY_TAB)
	var previous_actor := actor
	reparent(get_tree().root)
	checks.equal(get_tree().change_scene_to_packed(SCOPE), OK, "开始第一次场景切换")
	await _settle()
	scope = get_tree().current_scene
	actor = scope.get_node("Actor")
	checks.expect(not is_instance_valid(previous_actor), "旧场景角色已销毁")
	checks.expect(not UIManager.is_open(UIId.INVENTORY), "切场景自动关闭原背包视图")
	checks.equal(checks.value(InventoryManager.get_snapshot(DEFINITION.container_id)), before, "新场景角色绑定原容器与原实例身份")
	checks.expect(actor.get_node("Inventory").initialization_result.is_ok(), "新角色不重复创建已存在容器")
	checks.equal(get_tree().change_scene_to_packed(SCOPE), OK, "开始第二次场景切换")
	await _settle()
	scope = get_tree().current_scene
	actor = scope.get_node("Actor")
	checks.equal(checks.value(InventoryManager.get_snapshot(DEFINITION.container_id)), before, "连续切关不丢失或重复添加物品")
	checks.code(PlayerInventorySession.start_new(DEFINITION, InventoryManager), InventoryResult.Code.OK, "新游戏显式重建玩家容器")
	checks.expect(InventoryManager.get_snapshot(DEFINITION.container_id).items.is_empty(), "新会话从空背包开始")
	checks.equal(InventoryManager.get_snapshot(DEFINITION.container_id).revision, 0, "新会话容器版本归零")

## 检查实际 Hero.tscn 的组件绑定与生成器，角色销毁不会注销默认会话。
func _test_real_hero() -> void:
	var hero = HERO.instantiate()
	DataLoader.set_hero(hero)
	scope.add_child(hero)
	# Hero.ready 会执行首次地面检测，进入物理空间后再停止测试角色。
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	var inventory := PlayerInventoryComponent.find_for(hero)
	checks.expect(inventory != null and inventory.initialization_result.is_ok(), "真实 Hero 场景已挂载背包组件")
	checks.equal(inventory.definition.container_id, PLAYER_DEFINITION.container_id, "真实角色使用正式背包定义资源")
	checks.equal(InventoryManager.get_snapshot(PLAYER_DEFINITION.container_id).size, Vector2i(8, 6), "正式背包尺寸取自资源")
	checks.code(inventory.receive_item(21, 2), InventoryResult.Code.OK, "真实玩家组件可接收正式材料")
	var dropped: DroppedItem = hero.get_node("DropComponent").create_dropped_item([{"id": 10, "amount": 1}], Vector2(100, 100))
	checks.equal(dropped.items, [{"id": 10, "amount": 1}], "真实掉落工厂将清单传入世界节点")
	dropped.queue_free()
	hero.queue_free()
	await _settle()
	DataLoader.set_hero(null)
	checks.equal(InventoryManager.get_snapshot(PLAYER_DEFINITION.container_id).items.size(), 1, "真实角色销毁后背包物品仍保留")
	InventoryManager.unregister_container(PLAYER_DEFINITION.container_id)

## 使用真实工厂生成测试掉落并固定位置，使物理交互检测可重复。
func _drop(entries: Array) -> DroppedItem:
	var dropped: DroppedItem = actor.get_node("Drops").create_dropped_item(entries, actor.global_position)
	dropped.freeze = true
	dropped.linear_velocity = Vector2.ZERO
	return dropped

## 清空测试容器而不销毁会话，用于各用例独立布置物品。
func _clear_inventory() -> void:
	for record in InventoryManager.get_snapshot(DEFINITION.container_id).items.values():
		InventoryManager.remove_from_container(DEFINITION.container_id, record.anchor)

## 汇总测试背包数量，用于与地面余量一起检查守恒。
func _total() -> int:
	var total := 0
	for record in InventoryManager.get_snapshot(DEFINITION.container_id).items.values():
		total += record.instance.quantity
	return total

## 等待物理检测和 UI 布局完成，不依赖固定秒数睡眠。
func _settle() -> void:
	for frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame

## 注入项目 InputMap 对应的实际键盘事件，覆盖 UI 与角色输入路由。
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

## 注入真实鼠标移动，用于正式 UI 拖放关闭的集成检查。
func _motion(point: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(16, 0)
	event.button_mask = mask
	Input.parse_input_event(event)
	await get_tree().process_frame

## 注入完整左键按下与释放，避免全局按键状态影响后续场景测试。
func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await get_tree().process_frame
