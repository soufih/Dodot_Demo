extends Node
## 使用真实 Hero、正式目录、物理掉落、按键和拖放验证装备接入，不替换角色组件。

const LAB := "res://Scene/Inventory/InventoryGameplayLab.tscn"
var checks = preload("res://tests/inventory/spec_context.gd").new()
var lab: Node
var hero: HeroProperty
var inventory: PlayerInventoryComponent
var equipment: PlayerEquipmentComponent
var _last_pointer := Vector2.ZERO

## 等待 Autoload 初始化完成后加载正式角色测试台。
func _ready() -> void:
	_run.call_deferred()

## 保持测试驱动跨场景存活，依次测试穿戴、切换、互斥、生命周期与新游戏重置。
func _run() -> void:
	reparent(get_tree().root)
	checks.equal(get_tree().change_scene_to_file(LAB), OK, "加载真实玩家装备接入场景")
	await _wait_for_hero()
	if await _capture_preview():
		get_tree().quit()
		return
	_clear_items()
	checks.expect(equipment.initialization_result.is_ok(), "真实 Hero 自动初始化装备容器")
	checks.expect(inventory.equipment == equipment, "背包组件通过场景引用装备组件")
	checks.equal(equipment.get_current_weapon(), -1, "显式卸下初始装备后空手")
	checks.expect(hero.get_node("WeaponController").Weapon == null, "空手不加载攻击属性")
	checks.expect(hero._InputController.equipment == equipment, "攻击输入通过场景引用本角色装备组件")
	var attack_counts := {"requested": 0, "started": 0, "finished": 0}
	hero._InputController.when_attack_tigger.connect(func(): attack_counts.requested += 1)
	hero.on_attack.connect(func(_combo): attack_counts.started += 1)
	hero.end_attack.connect(func(): attack_counts.finished += 1)
	await _click_attack()
	checks.equal(attack_counts.requested, 0, "空手真实左键不发送攻击请求")
	checks.equal(attack_counts.started, 0, "空手不进入攻击流程")
	checks.expect(not hero._InputController.has_buffered_action(&"Attack"), "空手不缓存攻击输入")
	checks.equal(InventoryManager.get_snapshot(_gear_id()).size, Vector2i(8, 1), "正式装备资源提供八个槽位")
	await _key(KEY_E)
	checks.expect(not InventoryManager.get_snapshot(_bag_id()).items.is_empty(), "真实 E 拾取测试台材料")
	await _pickup("Sword")
	var sword := _find(10)
	await _open()
	var windows = UIManager.get_ui(UIId.INVENTORY).windows
	checks.equal(windows.size(), 2, "Tab 同时打开背包和装备窗口")
	checks.equal(windows[0].container_id, _bag_id(), "第一个窗口绑定玩家背包")
	checks.equal(windows[1].container_id, _gear_id(), "第二个窗口绑定玩家装备")
	checks.expect(not windows[0].get_global_rect().intersects(windows[1].get_global_rect()), "独立布局夹具中的两个浮动窗口并排且不重叠")
	await _equip(10, &"main_hand")
	if _equipped(&"main_hand").is_empty():
		checks.expect(false, "首次穿戴提交到主武器槽")
		get_tree().quit(1)
		return
	checks.equal(_equipped(&"main_hand").instance.instance_id, sword.instance.instance_id, "真实拖放穿戴保留拾取实例身份")
	_check_weapon(10)
	await _click_attack()
	checks.equal(attack_counts.requested, 0, "已装备但背包仍打开时屏蔽攻击输入")
	checks.expect(not hero._InputController.has_buffered_action(&"Attack"), "背包界面打开时不缓存攻击")
	await _key(KEY_TAB)
	await _click_attack()
	checks.equal(attack_counts.requested, 1, "装备武器并关闭界面后真实左键发送攻击请求")
	checks.equal(attack_counts.started, 1, "真实左键经状态机触发角色攻击")
	checks.expect(hero.get_node("State").Current == hero.get_node("State/Attack"), "真实攻击输入进入 Attack 状态")
	checks.equal(hero.get_node("WeaponController").Ani.current_animation, "SwordAttack", "真实攻击播放已装备长剑的动画")
	checks.expect(hero.get_node("WeaponController").Context != null, "穿戴后角色攻击创建上下文")
	checks.equal(hero.get_node("WeaponController").Context.weapon_data, WeaponManager.get_weapon_porperty("Sword"), "攻击使用已装备武器的正式属性")
	for frame in range(120):
		if attack_counts.finished > 0:
			break
		await get_tree().physics_frame
		await get_tree().process_frame
	checks.equal(attack_counts.finished, 1, "攻击动画自然结束后发出结束通知")
	checks.expect(hero.get_node("State").Current != hero.get_node("State/Attack"), "攻击自然结束后退出 Attack 状态")
	await _pickup("SecondaryWeapon")
	await _open()
	# 在实际较小视口中仍通过真实拖放穿戴，验证缩放后的坐标映射。
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().size = Vector2i(1280, 720)
	await _settle()
	windows = UIManager.get_ui(UIId.INVENTORY).windows
	checks.expect(windows[1].scale.x < 1.0, "小分辨率等比适配装备窗口")
	checks.expect(get_viewport().get_visible_rect().encloses(windows[1].get_global_rect()), "小分辨率完整显示装备窗口")
	await _equip(11, &"off_hand")
	checks.equal(equipment.get_next_weapon(), 11, "副武器进入备用选择")
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	await _settle()
	await _key(KEY_TAB)
	var before: Dictionary = checks.value(InventoryManager.get_snapshot(_gear_id()))
	await _key(KEY_Q)
	checks.equal(equipment.get_current_weapon(), 11, "真实 Q 输入经状态机切换武器")
	checks.equal(equipment.get_next_weapon(), 10, "切换后原武器成为备用")
	checks.equal(checks.value(InventoryManager.get_snapshot(_gear_id())), before, "选择切换不改变装备实例与容器版本")
	_check_weapon(11)
	await _pickup("TwoHandWeapon")
	await _open()
	before = checks.value(InventoryManager.get_snapshot(_gear_id()))
	var bag_before: Dictionary = checks.value(InventoryManager.get_snapshot(_bag_id()))
	await _equip(15, &"main_hand")
	checks.equal(checks.value(InventoryManager.get_snapshot(_gear_id())), before, "副武器非空时双手武器替换整体失败")
	checks.equal(checks.value(InventoryManager.get_snapshot(_bag_id())), bag_before, "失败穿戴不扣背包物品")
	_check_weapon(11)
	await _unequip(&"off_hand")
	checks.equal(equipment.get_current_weapon(), 10, "卸下当前副武器后自动使用剩余主武器")
	_check_weapon(10)
	await _equip(15, &"main_hand")
	checks.equal(equipment.get_current_weapon(), 15, "副武器卸下后双手武器可以穿戴")
	_check_weapon(15)
	before = checks.value(InventoryManager.get_snapshot(_gear_id()))
	await _equip(11, &"off_hand")
	checks.equal(checks.value(InventoryManager.get_snapshot(_gear_id())), before, "双手武器已装备时副武器拖入失败")
	await _capture()
	var point := _slot_point(&"main_hand")
	await _begin(point)
	await _key(KEY_TAB)
	await _button(point, false)
	checks.expect(not get_viewport().gui_is_dragging() and not UIManager.is_open(UIId.INVENTORY), "关闭双窗口时取消装备来源拖放")
	checks.equal(checks.value(InventoryManager.get_snapshot(_gear_id())), before, "关闭中的拖放不卸下装备")
	var subscriptions: int = InventoryManager.container_changed.get_connections().size()
	checks.equal(subscriptions, 1, "关闭后仅保留角色装备组件订阅")
	var old_component: WeakRef = weakref(equipment)
	var saved_bag: Dictionary = checks.value(InventoryManager.get_snapshot(_bag_id()))
	var saved_gear: Dictionary = checks.value(InventoryManager.get_snapshot(_gear_id()))
	await _open()
	checks.equal(get_tree().reload_current_scene(), OK, "实际重载角色所在场景")
	await _wait_for_hero()
	checks.expect(old_component.get_ref() == null, "旧角色组件已释放")
	checks.expect(not UIManager.is_open(UIId.INVENTORY), "切场景关闭旧的双窗口")
	checks.equal(checks.value(InventoryManager.get_snapshot(_bag_id())), saved_bag, "切场景完整保留背包实例和版本")
	checks.equal(checks.value(InventoryManager.get_snapshot(_gear_id())), saved_gear, "切场景完整保留装备实例和版本")
	checks.equal(InventoryManager.container_changed.get_connections().size(), subscriptions, "新角色接管订阅且不泄漏旧角色")
	_check_weapon(15)
	lab.get_node("HUD/Panel/Margin/Rows/Reset").pressed.emit()
	checks.expect(InventoryManager.get_snapshot(_bag_id()).items.is_empty(), "显式新会话恢复空背包")
	checks.equal(InventoryManager.get_snapshot(_gear_id()).items.size(), 2, "显式新会话恢复两把初始武器")
	checks.equal(equipment.get_current_weapon(), 10, "重置后使用主武器 10")
	_check_weapon(10)
	checks.expect(hero.get_node("WeaponController").Context == null, "重置清除旧攻击上下文")
	_clear_items()
	checks.expect(hero.get_node("PlayerUI/weapon_state_ui").current_item.texture == null, "卸下全部装备清除武器 HUD")
	checks.code(equipment.switch_weapon(), InventoryResult.Code.RULE_REJECTED, "没有备用武器时不能切换")
	print("EQUIPMENT_GAMEPLAY_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 空手及拾取用例显式清理初始内容，避免把空手夹具与正式新游戏默认值混淆。
func _clear_items() -> void:
	for id in [_bag_id(), _gear_id()]:
		for record: Dictionary in InventoryManager.get_snapshot(id).items.values():
			InventoryManager.remove_from_container(id, record.anchor)

## 等待角色进入物理空间并结束出生输入禁用，重新获取跨场景组件引用。
func _wait_for_hero() -> void:
	for frame in range(90):
		await get_tree().physics_frame
		await get_tree().process_frame
	lab = get_tree().current_scene
	hero = lab.get_node("Hero")
	inventory = hero.get_node("Inventory")
	equipment = hero.get_node("Equipment")
	# 手工定位点允许作者自由重叠窗口；键鼠回归使用独立布局，避免落点被其他窗口遮挡。
	var ui = UIManager.prepare(UIId.INVENTORY, lab)
	ui.window_positions.clear()
	checks.expect(not hero._InputController.is_banned, "出生后恢复游戏输入")

## 使用测试台的真实掉落按钮与 E 交互拾取武器。
func _pickup(button: String) -> void:
	lab.get_node("HUD/Panel/Margin/Rows/" + button).pressed.emit()
	for frame in range(4):
		await get_tree().physics_frame
	await _key(KEY_E)

## 检查战斗控制器和角色 HUD 都引用当前装备选择。
func _check_weapon(id: int) -> void:
	var controller = hero.get_node("WeaponController")
	var hud = hero.get_node("PlayerUI/weapon_state_ui")
	checks.equal(controller.Weapon, WeaponManager.get_weapon_porperty(ResourceManager.get_item_name(id)), "武器控制器同步正式攻击属性")
	checks.equal(controller.WeaponTexture.texture, ResourceManager.get_item_icon(id), "手持武器图标同步装备")
	checks.equal(hud.current_item.texture, ResourceManager.get_item_icon(id), "角色 HUD 同步当前武器")
	checks.equal(hud.next_item.texture, ResourceManager.get_item_icon(equipment.get_next_weapon()), "角色 HUD 同步备用武器")

## 按真实 Tab 打开玩家双窗口，不直接实例化 UI。
func _open() -> void:
	if not UIManager.is_open(UIId.INVENTORY):
		await _key(KEY_TAB)
	await _settle()

## 从背包物品的实际显示位置拖入命名装备槽。
func _equip(id: int, slot_id: StringName) -> void:
	var record := _find(id)
	checks.expect(not record.is_empty(), "准备穿戴的正式物品存在")
	if record.is_empty():
		return
	var board = UIManager.get_ui(UIId.INVENTORY).windows[0].get_node("Body/Content/Scroll/Board")
	var from: Vector2 = board.get_global_transform_with_canvas() * (Vector2(record.anchor * 52) + Vector2(26, 26))
	await _drag(from, _slot_point(slot_id))

## 寻找能容纳装备完整矩形的空背包位置，再进行真实卸下拖放。
func _unequip(slot_id: StringName) -> void:
	var record := _equipped(slot_id)
	var state: Dictionary = InventoryManager.get_snapshot(_bag_id())
	var destination := Vector2i(-1, -1)
	for y in range(state.size.y):
		for x in range(state.size.x):
			if InventoryManager.can_place(_bag_id(), record.instance, Vector2i(x, y), record.instance.rotated).is_ok():
				destination = Vector2i(x, y)
				break
		if destination.x >= 0:
			break
	checks.expect(destination.x >= 0, "背包存在卸下装备的完整空间")
	var board = UIManager.get_ui(UIId.INVENTORY).windows[0].get_node("Body/Content/Scroll/Board")
	var to: Vector2 = board.get_global_transform_with_canvas() * (Vector2(destination * 52) + Vector2(26, 26))
	await _drag(_slot_point(slot_id), to)

## 查找装备 UI 的业务槽，使用包含缩放的真实矩形中心。
func _slot_point(id: StringName) -> Vector2:
	var layout = UIManager.get_ui(UIId.INVENTORY).windows[1].get_node("Body/Content/Scroll/Board")
	for slot in layout._find_slots():
		if slot.slot_id == id:
			return slot.get_global_rect().get_center()
	return Vector2.ZERO

## 读取隔离快照中的正式装备记录。
func _equipped(id: StringName) -> Dictionary:
	var pos: Vector2i = InventoryManager.get_slot_position(_gear_id(), id).payload
	return InventoryManager.get_item_at(_gear_id(), pos)

## 在真实背包中按配置 ID 查找实例，不依赖物品自动放置的具体位置。
func _find(id: int) -> Dictionary:
	for record: Dictionary in InventoryManager.get_snapshot(_bag_id()).items.values():
		if record.instance.config_id == id:
			return record
	return {}

## 返回当前玩家的背包会话 ID。
func _bag_id() -> String:
	return inventory.definition.container_id

## 返回当前玩家的装备会话 ID。
func _gear_id() -> String:
	return equipment.definition.container_id

## 原生拖放包含开始阈值、移动和释放，规则失败时同样必须清理预览。
func _drag(from: Vector2, to: Vector2) -> void:
	await _begin(from)
	await _motion(to, MOUSE_BUTTON_MASK_LEFT)
	await _button(to, false)
	checks.expect(not get_viewport().gui_is_dragging(), "释放后结束正式装备拖拽")

## 注入真实鼠标输入，确认引擎启动拖放。
func _begin(point: Vector2) -> void:
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(18, 0), MOUSE_BUTTON_MASK_LEFT)
	checks.expect(get_viewport().gui_is_dragging(), "正式角色界面启动原生拖拽")

## 发送鼠标移动，保持 Input 中的位置和按钮掩码一致。
func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = buttons
	event.relative = point - _last_pointer
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发送鼠标左键按下或释放，经过实际 GUI 分发。
func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

## 使用项目实际绑定的物理键码触发 E、Tab、Q。
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

## 在测试台控件以外发送真实左键按下与释放，验证完整输入到攻击状态的链路。
func _click_attack() -> void:
	var point := Vector2(1200, 700)
	await _motion(point, 0)
	await _button(point, true)
	await _button(point, false)

## 等待工作区缩放、场景容器排序与数据刷新稳定。
func _settle() -> void:
	for frame in range(4):
		await get_tree().process_frame

## 图形截图模式通过正式命令准备场景，不依赖隐藏窗口中会被操作系统覆盖的合成鼠标位置。
func _capture_preview() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--equipment-gameplay-capture="):
			inventory.toggle_inventory()
			await _settle()
			await _capture()
			print("EQUIPMENT_GAMEPLAY_CAPTURE_COMPLETE")
			return true
	return false

## 可选渲染正式双窗口截图；普通 headless 回归不等待渲染信号。
func _capture() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--equipment-gameplay-capture="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--equipment-gameplay-capture="))
