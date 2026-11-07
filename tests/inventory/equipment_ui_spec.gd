extends Node
## 真实场景与键鼠回归：同组多槽、跨背包拖放、手工布局保持及正式工作区接入。

const CUSTOM = preload("res://tests/inventory/equipment_custom_window.tscn")
const EQUIPMENT_ID := "测试装备栏"
var checks = preload("res://tests/inventory/spec_context.gd").new()
var _last_pointer := Vector2.ZERO
@onready var lab = $Lab
@onready var bag = $Lab/Workspace/Bag/Body/Content/Scroll/Board
@onready var equipment = $Lab/Workspace/Equipment
@onready var layout = $Lab/Workspace/Equipment/Body/Content/Scroll/Board

## 等待真实布局后回归；截图模式只负责渲染演示场景，不替代交互测试。
func _ready() -> void:
	await _settle()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture="):
			lab.manager.switch_to_container(lab.BAG_ID, EQUIPMENT_ID, _find(2001).anchor, Vector2i.ZERO)
			lab.manager.switch_to_container(lab.BAG_ID, EQUIPMENT_ID, _find(2002).anchor, Vector2i(1, 0))
			await _settle()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--ui-capture="))
			print("EQUIPMENT_UI_CAPTURE_COMPLETE")
			get_tree().quit()
			return
	_test_scene_and_forms()
	await _test_native_equipping()
	await _test_restrictions_and_rings()
	await _test_manual_layout()
	await _test_window_drag()
	await _test_failed_binding()
	await _test_workspace()
	await _test_workspace_positions()
	await _test_workspace_layout_switching()
	print("EQUIPMENT_UI_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 场景预先具有武器分组及两个不同槽位，表单使用现有按钮与配置资源。
func _test_scene_and_forms() -> void:
	checks.equal(layout._find_slots().size(), lab.equipment_definition.equipment_slots.size(), "场景槽位数量与服务定义一致")
	checks.equal(_slot(&"main_hand").get_parent(), _slot(&"off_hand").get_parent(), "主武器与副武器同属一个分组")
	checks.expect(_slot(&"main_hand").slot_id != _slot(&"off_hand").slot_id, "同分组多槽绑定不同业务标识")
	checks.equal(lab.manager.get_snapshot(EQUIPMENT_ID).size, Vector2i(8, 1), "通过定义资源与会话创建八个装备槽")
	checks.equal(lab.manager.get_snapshot(lab.BAG_ID).items.size(), lab.item_catalog.Item.size(), "演示提供装备及普通物品")
	for slot in layout._find_slots():
		checks.expect(slot._manager == lab.manager, "场景槽位已绑定：" + String(slot.slot_id))
	var count: int = lab.manager.get_snapshot(lab.BAG_ID).items.size()
	lab.get_node("Toolbar/Item").select(0)
	lab.get_node("Toolbar/Add").pressed.emit()
	checks.equal(lab.manager.get_snapshot(lab.BAG_ID).items.size(), count + 1, "添加按钮向背包新增物品")
	lab.get_node("Toolbar/Reset").pressed.emit()
	checks.equal(lab.manager.get_snapshot(lab.BAG_ID).items.size(), lab.item_catalog.Item.size(), "重置按钮恢复测试物品")
	checks.expect(_slot(&"main_hand").get_node("Empty").visible, "空装备槽显示拖入提示")

## 原生左键拖拽在两个武器槽中分别穿戴、交换，卸下仍保持网格预览尺寸。
func _test_native_equipping() -> void:
	var sword: Dictionary = _find(2001)
	var dagger: Dictionary = _find(2002)
	await _drag(_bag_point(sword.anchor), _center(_slot(&"main_hand")))
	checks.equal(_record(&"main_hand").instance.instance_id, sword.instance.instance_id, "长剑拖入主武器槽")
	checks.expect(_slot(&"main_hand").get_node("Item").visible, "穿戴后刷新槽位图标")
	await _drag(_bag_point(dagger.anchor), _center(_slot(&"off_hand")))
	checks.equal(_record(&"off_hand").instance.instance_id, dagger.instance.instance_id, "短剑拖入同组副武器槽")
	checks.equal(_record(&"main_hand").instance.instance_id, sword.instance.instance_id, "副武器穿戴不覆盖主武器")
	await _drag(_center(_slot(&"main_hand")), _center(_slot(&"off_hand")))
	checks.equal(_record(&"main_hand").instance.instance_id, dagger.instance.instance_id, "两个武器槽可交换独立装备")
	checks.equal(_record(&"off_hand").instance.instance_id, sword.instance.instance_id, "交换保留另一把武器身份")
	var before: Dictionary = checks.value(lab.manager.get_snapshot(EQUIPMENT_ID))
	var saved_scale: Vector2 = equipment.scale
	var source_slot := _slot(&"off_hand")
	var saved_slot_scale := source_slot.scale
	equipment.scale = Vector2(0.6, 0.6)
	source_slot.scale = Vector2(1.1, 0.9)
	await _settle()
	await _begin(_center(_slot(&"off_hand")))
	var preview := _preview()
	checks.expect(preview != null, "装备来源产生预制拖拽预览")
	if preview != null:
		checks.equal(preview.size, Vector2(52, 156), "装备来源拖拽预览保持完整占格尺寸")
		var expected: Vector2 = Vector2(52, 156) * equipment.get_global_transform().get_scale()
		checks.expect(preview.get_global_rect().size.is_equal_approx(expected), "装备预览跟随窗口缩放，不受槽位局部拉伸影响")
	await _key(KEY_R)
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "装备来源按 R 不修改状态")
	if preview != null:
		checks.equal(preview.size, Vector2(52, 156), "装备来源不旋转预览")
	await _key(KEY_ESCAPE)
	await _button(_center(_slot(&"off_hand")), false)
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "取消拖放保持装备")
	equipment.scale = saved_scale
	source_slot.scale = saved_slot_scale
	await _settle()
	await _drag(_center(_slot(&"off_hand")), _bag_point(Vector2i(4, 5)))
	checks.expect(_record(&"off_hand").is_empty(), "拖回背包卸下副武器")
	checks.equal(lab.manager.get_item_at(lab.BAG_ID, Vector2i(4, 7)).instance.instance_id, sword.instance.instance_id, "卸下恢复完整背包占格")
	checks.expect(_slot(&"off_hand").get_node("Empty").visible, "卸下恢复空槽提示")

## 错误类型和双手互斥由服务拒绝；两个同类型戒指槽独立保存实例。
func _test_restrictions_and_rings() -> void:
	var armor: Dictionary = _find(2007)
	await _drag(_bag_point(armor.anchor), _center(_slot(&"body")))
	checks.equal(_record(&"body").instance.instance_id, armor.instance.instance_id, "新增身体槽原生拖放胸甲成功")
	checks.expect(_slot(&"body").get_node("Item").visible, "新增身体槽更新物品显示")
	var before: Dictionary = checks.value(lab.manager.get_snapshot(EQUIPMENT_ID))
	var bag_before: Dictionary = checks.value(lab.manager.get_snapshot(lab.BAG_ID))
	await _drag(_bag_point(_find(2006).anchor), _center(_slot(&"head")))
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "普通物品不能进入装备空槽")
	checks.equal(checks.value(lab.manager.get_snapshot(lab.BAG_ID)), bag_before, "非法穿戴不扣背包物品")
	await _drag(_bag_point(_find(2004).anchor), _center(_slot(&"main_hand")))
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "不适配的替换不覆盖现有装备")
	checks.equal(checks.value(lab.manager.get_snapshot(lab.BAG_ID)), bag_before, "失败交换不修改背包")
	await _drag(_bag_point(_find(2003).anchor), _center(_slot(&"main_hand")))
	checks.equal(_record(&"main_hand").instance.config_id, 2003, "副武器为空时双手武器可替换主武器")
	before = checks.value(lab.manager.get_snapshot(EQUIPMENT_ID))
	await _drag(_bag_point(_find(2002).anchor), _center(_slot(&"off_hand")))
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "双手武器阻止副武器穿戴")
	await _test_full_equipment_content()
	await _drag(_bag_point(_find(2005).anchor), _center(_slot(&"relic1")))
	lab.manager.quick_add_to_container(lab.BAG_ID, 2005)
	await _settle()
	await _drag(_bag_point(_find(2005).anchor), _center(_slot(&"relic2")))
	checks.equal(_record(&"relic1").instance.config_id, 2005, "饰品一槽装备戒指")
	checks.equal(_record(&"relic2").instance.config_id, 2005, "饰品二槽装备同类型戒指")
	checks.expect(_record(&"relic1").instance.instance_id != _record(&"relic2").instance.instance_id, "同类型多个槽位保持独立实例")
	for id in [&"relic3", &"relic4"]:
		lab.manager.quick_add_to_container(lab.BAG_ID, 2005)
		await _settle()
		await _drag(_bag_point(_find(2005).anchor), _center(_slot(id)))
		checks.equal(_record(id).instance.config_id, 2005, "新增饰品槽原生拖放成功：" + String(id))
	before = checks.value(lab.manager.get_snapshot(EQUIPMENT_ID))
	var point := _center(_slot(&"relic1"))
	await _motion(point, 0)
	await _button(point, true, MOUSE_BUTTON_MIDDLE)
	await _button(point, false, MOUSE_BUTTON_MIDDLE)
	checks.expect(not get_viewport().gui_is_dragging(), "装备槽中键不启动分割")
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "不支持的分割保持状态")

## 继承场景中手工交换武器槽位置与分组位置，刷新和重绑定不得改写布局。
func _test_manual_layout() -> void:
	var custom = $CustomHost/CustomWindow
	var custom_layout = custom.get_node("Body/Content/Scroll/Board")
	var default_layout_state := _geometry(layout)
	var state := _geometry(custom_layout)
	var subscriptions: int = lab.manager.container_changed.get_connections().size()
	equipment.hide()
	checks.code(custom.bind(lab.manager, EQUIPMENT_ID, InventoryManager.ServiceType.EQUIPMENT_SLOT, lab.lookup_config), InventoryResult.Code.OK, "绑定手工调整的装备场景")
	custom.show()
	await _settle()
	checks.equal(custom.size, Vector2(560, 600), "装备窗口保留场景定义尺寸")
	checks.equal(_geometry(custom_layout), state, "绑定不覆盖分组和槽位的场景布局")
	var custom_main: Control = custom_layout.get_node("Weapons/Slots/MainWeapon")
	var custom_off: Control = custom_layout.get_node("Weapons/Slots/SecondaryWeapon")
	checks.expect(custom_main.position.x > custom_off.position.x, "自定义场景主武器位于副武器右侧")
	checks.equal(custom_main.record_at(custom_main.size * 0.5).instance.config_id, 2003, "位置变化后仍按主武器标识显示")
	lab.manager.remove_from_container(EQUIPMENT_ID, Vector2i.ZERO)
	await _settle()
	await _drag(_bag_point(_find(2002).anchor), _center(custom_off))
	checks.equal(_record(&"off_hand").instance.config_id, 2002, "改动槽位位置后原生拖放仍定位副武器")
	checks.equal(_geometry(custom_layout), state, "数据变化与拖放不重新排列布局")
	checks.equal(_geometry(layout), default_layout_state, "独立布局实例互不影响")
	custom.unbind()
	checks.equal(lab.manager.container_changed.get_connections().size(), subscriptions, "解绑自定义窗口清理全部服务订阅")
	checks.code(custom.bind(lab.manager, EQUIPMENT_ID, InventoryManager.ServiceType.EQUIPMENT_SLOT, lab.lookup_config), InventoryResult.Code.OK, "自定义窗口可以再次绑定")
	checks.equal(_geometry(custom_layout), state, "重绑定仍保留手工布局")
	custom.unbind()
	custom.hide()
	equipment.show()
	var bad = _slot(&"off_hand")
	bad.slot_id = &"main_hand"
	checks.code(layout.validate_layout(lab.manager, EQUIPMENT_ID), InventoryResult.Code.RULE_REJECTED, "布局拒绝重复业务槽位标识")
	bad.slot_id = &"missing"
	checks.code(layout.validate_layout(lab.manager, EQUIPMENT_ID), InventoryResult.Code.INVALID_POSITION, "布局拒绝不存在的业务槽位")
	bad.slot_id = &"off_hand"

## 继承现有窗口边框拖动，移动窗口不能改变装备数据或内部槽位布局。
func _test_window_drag() -> void:
	var before: Dictionary = checks.value(lab.manager.get_snapshot(EQUIPMENT_ID))
	var geometry := _geometry(layout)
	var position_before: Vector2 = equipment.position
	var point: Vector2 = equipment.get_node("Title").global_position + Vector2(40, 15)
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(30, 12), MOUSE_BUTTON_MASK_LEFT)
	await _button(point + Vector2(30, 12), false)
	checks.expect(equipment.position != position_before, "装备窗口支持按住标题栏移动")
	checks.equal(_geometry(layout), geometry, "移动整个窗口不改变内部手工布局")
	checks.equal(checks.value(lab.manager.get_snapshot(EQUIPMENT_ID)), before, "移动窗口不改变装备状态")

## 正式 UIManager 按类型选择装备窗口，也允许传入自定义场景并清理错误布局。
func _test_workspace() -> void:
	UIManager.configure_scene(self, [UIId.INVENTORY])
	var id := "equipment_ui_workspace"
	checks.code(InventoryManager.create_container(id, lab.equipment_definition.size, InventoryManager.ServiceType.EQUIPMENT_SLOT, lab.equipment_definition.equipment_slots), InventoryResult.Code.OK, "正式 Manager 创建测试装备栏")
	var payload := {"container_id": id, "service_type": InventoryManager.ServiceType.EQUIPMENT_SLOT}
	var ui = UIManager.open(UIId.INVENTORY, payload, self)
	await _settle()
	checks.expect(ui != null, "正式工作区打开装备栏")
	if ui != null:
		checks.equal(ui.windows[0].scene_file_path, "res://UI/Inventory/equipment_window.tscn", "工作区选择装备窗口场景")
		var authored: Control = preload("res://UI/Inventory/equipment_window.tscn").instantiate()
		checks.equal(ui.windows[0].size, authored.size, "正式主题不改变装备窗口场景尺寸")
		authored.free()
	UIManager.close(UIId.INVENTORY)
	checks.equal(InventoryManager.container_changed.get_connections().size(), 0, "关闭正式装备工作区解除订阅")
	payload.window_scene = CUSTOM
	ui = UIManager.open(UIId.INVENTORY, payload, self)
	await _settle()
	checks.equal(ui.windows[0].scene_file_path, CUSTOM.resource_path, "工作区接受业务指定的布局场景")
	UIManager.close(UIId.INVENTORY)
	payload.window_scene = "invalid"
	checks.expect(UIManager.open(UIId.INVENTORY, payload, self) == null, "工作区拒绝非场景类型的布局配置")
	checks.equal(InventoryManager.container_changed.get_connections().size(), 0, "失败打开不残留数据订阅")
	var single: Array[EquipmentSlotDefinition] = [lab.equipment_definition.equipment_slots[0]]
	InventoryManager.create_container("equipment_ui_bad", Vector2i.ONE, InventoryManager.ServiceType.EQUIPMENT_SLOT, single)
	InventoryManager.create_container("equipment_ui_bag", Vector2i.ONE, InventoryManager.ServiceType.GRID)
	var mixed := {"containers": [
		{"id": "equipment_ui_bag", "service_type": InventoryManager.ServiceType.GRID},
		{"id": "equipment_ui_bad", "service_type": InventoryManager.ServiceType.EQUIPMENT_SLOT}]}
	checks.expect(UIManager.open(UIId.INVENTORY, mixed, self) == null, "默认布局与服务槽位不匹配时拒绝打开")
	checks.equal(InventoryManager.container_changed.get_connections().size(), 0, "后续布局绑定失败时清理已绑定的前一个窗口")
	checks.expect(InventoryManager.has_container("equipment_ui_bad"), "布局失败不删除业务容器")
	InventoryManager.unregister_container("equipment_ui_bad")
	InventoryManager.unregister_container("equipment_ui_bag")
	InventoryManager.unregister_container(id)

## 使用真实工作区的场景定位点，验证顺序、父级变换、缺少定位点和再次打开的行为。
func _test_workspace_positions() -> void:
	var ui = UIManager.prepare(UIId.INVENTORY, self)
	checks.equal(ui.window_positions.size(), 2, "不含仓库的布局预先声明背包和装备两个定位点")
	var markers: Array[Marker2D] = []
	markers.assign(ui.window_positions)
	var group: Node2D = ui.get_node("Workspace/WindowPositions")
	var saved_positions: Array[Vector2] = []
	for marker in markers:
		saved_positions.append(marker.position)
	var saved_group_position := group.position
	var saved_group_scale := group.scale
	group.position = Vector2(14, 18)
	group.scale = Vector2(1.1, 1.2)
	markers[0].position = Vector2(40, 40)
	markers[1].position = Vector2(350, 80)
	var containers: Array = []
	for index in range(4):
		var id := "workspace_position_%d" % index
		InventoryManager.create_container(id, Vector2i.ONE, InventoryManager.ServiceType.GRID)
		containers.append({"id": id, "service_type": InventoryManager.ServiceType.GRID})
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	for index in range(markers.size()):
		checks.expect(ui.windows[index].global_position.is_equal_approx(markers[index].global_position), "按定位数组顺序放置窗口，兼容父节点变换")
	checks.equal(ui.windows[3].position, ui.windows[2].position + Vector2(ui.windows[2].size.x + ui.window_gap, 0), "定位点不足时接续最后一个窗口自动排列")
	var first = ui.windows[0]
	var point: Vector2 = first.get_node("Title").global_position + Vector2(30, 15)
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(20, 10), MOUSE_BUTTON_MASK_LEFT)
	await _button(point + Vector2(20, 10), false)
	checks.expect(not first.global_position.is_equal_approx(markers[0].global_position), "定位后窗口仍可通过标题拖动")
	var moved_position: Vector2 = first.position
	ui._clamp_windows()
	checks.equal(first.position, moved_position, "边界检查不会把手工拖动的窗口拉回定位点")
	UIManager.close(UIId.INVENTORY)
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	checks.expect(ui.windows[0].global_position.is_equal_approx(markers[0].global_position), "重新打开时重读场景定位点")
	UIManager.close(UIId.INVENTORY)
	ui.window_positions.assign([markers[1], markers[0]])
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	checks.expect(ui.windows[0].global_position.is_equal_approx(markers[1].global_position), "调整导出数组顺序可以改变第一个窗口的位置")
	checks.expect(ui.windows[1].global_position.is_equal_approx(markers[0].global_position), "按数组顺序而非节点名称绑定第二个窗口位置")
	UIManager.close(UIId.INVENTORY)
	ui.window_positions.assign([markers[0], null, markers[1]])
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	checks.equal(ui.windows[1].position, ui.windows[0].position + Vector2(ui.windows[0].size.x + ui.window_gap, 0), "未赋值的数组项安全使用自动排列")
	checks.expect(ui.windows[2].global_position.is_equal_approx(markers[1].global_position), "未赋值项不改变后续定位点的对应索引")
	UIManager.close(UIId.INVENTORY)
	ui.window_positions.clear()
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	checks.equal(ui.windows[0].position, Vector2(24, 24), "空定位数组保持旧的默认起点")
	checks.equal(ui.windows[1].position, ui.windows[0].position + Vector2(ui.windows[0].size.x + ui.window_gap, 0), "空定位数组保持旧的横向排列")
	UIManager.close(UIId.INVENTORY)
	ui.window_positions.assign(markers)
	group.position = saved_group_position
	group.scale = saved_group_scale
	for index in range(markers.size()):
		markers[index].position = saved_positions[index]
	for entry in containers:
		InventoryManager.unregister_container(entry.id)
	checks.equal(InventoryManager.container_changed.get_connections().size(), 0, "布局回归关闭后不残留容器订阅")

## 同一工作区在两套场景定位点之间切换，只根据仓库类型选择，不依赖窗口数量或仓库索引。
func _test_workspace_layout_switching() -> void:
	var ui = UIManager.prepare(UIId.INVENTORY, self)
	checks.equal(ui.warehouse_window_positions.size(), 3, "含仓库布局导出背包、装备、仓库三个定位点")
	var regular: Array[Marker2D] = []
	var warehouse: Array[Marker2D] = []
	regular.assign(ui.window_positions)
	warehouse.assign(ui.warehouse_window_positions)
	checks.expect(regular[0].get_parent() == ui.get_node("Workspace/WindowPositions/WithoutWarehouse"), "常规定位点由场景中的独立分组管理")
	checks.expect(warehouse[0].get_parent() == ui.get_node("Workspace/WindowPositions/WithWarehouse"), "仓库定位点由场景中的独立分组管理")
	checks.expect(regular[0] != warehouse[0] and regular[1] != warehouse[1], "两套布局使用不同的背包和装备定位节点")
	var saved_regular: Array[Vector2] = []
	var saved_warehouse: Array[Vector2] = []
	for index in range(regular.size()):
		saved_regular.append(regular[index].position)
		regular[index].position = Vector2(48 + index * 330, 32)
	for index in range(warehouse.size()):
		saved_warehouse.append(warehouse[index].position)
		warehouse[index].position = Vector2(96 + index * 330, 96)
	var containers: Array = []
	for index in range(3):
		var id := "workspace_layout_%d" % index
		var type := InventoryManager.ServiceType.WAREHOUSE if index == 2 else InventoryManager.ServiceType.GRID
		InventoryManager.create_container(id, Vector2i.ONE, type)
		containers.append({"id": id, "service_type": type})
	var without_warehouse := containers.slice(0, 2)
	UIManager.open(UIId.INVENTORY, {"containers": without_warehouse}, self)
	await _settle()
	for index in range(regular.size()):
		checks.expect(ui.windows[index].global_position.is_equal_approx(regular[index].global_position), "没有仓库时使用常规定位数组")
	UIManager.close(UIId.INVENTORY)
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	for index in range(warehouse.size()):
		checks.expect(ui.windows[index].global_position.is_equal_approx(warehouse[index].global_position), "包含仓库时所有窗口改用仓库定位数组")
	UIManager.close(UIId.INVENTORY)
	UIManager.open(UIId.INVENTORY, {"containers": [containers[2], containers[0]]}, self)
	await _settle()
	checks.equal(ui.windows.size(), 2, "含仓库的界面也可以只有两个窗口")
	checks.expect(ui.windows[0].global_position.is_equal_approx(warehouse[0].global_position), "仓库位于首项时仍选择仓库布局")
	checks.expect(ui.windows[1].global_position.is_equal_approx(warehouse[1].global_position), "仓库布局内部仍按容器数组索引放置")
	UIManager.close(UIId.INVENTORY)
	UIManager.open(UIId.INVENTORY, {"containers": without_warehouse}, self)
	await _settle()
	for index in range(regular.size()):
		checks.expect(ui.windows[index].global_position.is_equal_approx(regular[index].global_position), "关闭仓库后再次打开玩家窗口恢复常规布局")
	UIManager.close(UIId.INVENTORY)
	ui.warehouse_window_positions.clear()
	UIManager.open(UIId.INVENTORY, {"containers": containers}, self)
	await _settle()
	checks.equal(ui.windows[0].position, Vector2(24, 24), "仓库定位数组为空时使用自动排列，不混用常规布局")
	UIManager.close(UIId.INVENTORY)
	ui.warehouse_window_positions.assign(warehouse)
	for index in range(regular.size()):
		regular[index].position = saved_regular[index]
	for index in range(warehouse.size()):
		warehouse[index].position = saved_warehouse[index]
	for entry in containers:
		InventoryManager.unregister_container(entry.id)
	checks.equal(InventoryManager.container_changed.get_connections().size(), 0, "两套布局切换并关闭后不残留订阅")

## 使用缺少身体槽定义的真实测试台，复现配置失败后继续拖放，验证不会调用空 Manager。
func _test_failed_binding() -> void:
	var failure = $FailureLab
	var failed_window = failure.get_node("Workspace/Equipment")
	var failed_layout = failed_window.get_node("Body/Content/Scroll/Board")
	var failed_bag = failure.get_node("Workspace/Bag/Body/Content/Scroll/Board")
	var body: EquipmentSlotView = failed_layout.get_node("Armor/Slots/Body")
	checks.expect(not failure._initialized, "布局失败不进入就绪状态")
	var error_text: String = failure.get_node("Status").text
	checks.expect(error_text.contains("body") and error_text.contains("Armor/Slots/Body"), "初始化错误明确报告槽位标识和节点路径")
	checks.expect(failure.get_node("Toolbar/Add").disabled and failure.get_node("Toolbar/Reset").disabled, "初始化失败禁用演示添加和重置")
	failure.get_node("Toolbar/Reset").pressed.emit()
	checks.equal(failure.get_node("Status").text, error_text, "重置不能覆盖初始化错误")
	for slot in failed_layout._find_slots():
		checks.expect(slot._manager == null and slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "失败布局所有槽位均未绑定且禁用鼠标输入")
		checks.expect(slot.record_at(slot.size * 0.5).is_empty(), "未绑定槽位的记录查询安全返回空")
	var sword: ItemInstance = failure.manager.add_to_container(failure.BAG_ID, 2001, 1, Vector2i.ZERO).payload
	var data := {"source_id": failure.BAG_ID, "source_pos": Vector2i.ZERO, "instance": sword}
	checks.expect(not body._can_drop_data(body.size * 0.5, data), "精确复现：未绑定槽位拒绝 can_place 预览")
	checks.expect(body._get_drag_data(body.size * 0.5) == null, "未绑定槽位不能发起拖放")
	body._drop_data(body.size * 0.5, data)
	var before: Dictionary = checks.value(failure.manager.get_snapshot(failure.BAG_ID))
	var equipment_before: Dictionary = checks.value(failure.manager.get_snapshot(failure.equipment_definition.container_id))
	lab.hide()
	failure.show()
	await _settle()
	var from: Vector2 = failed_bag.global_position + Vector2(26, 26)
	var to: Vector2 = failed_layout.get_node("Weapons/Slots/MainWeapon").global_position + Vector2(30, 60)
	await _drag(from, to)
	checks.equal(checks.value(failure.manager.get_snapshot(failure.BAG_ID)), before, "绑定失败后真实拖放保持来源物品与版本")
	checks.equal(checks.value(failure.manager.get_snapshot(failure.equipment_definition.container_id)), equipment_before, "绑定失败不写入装备容器")
	checks.equal(failure.get_node("Status").text, error_text, "失败拖放保留原始配置错误")
	checks.code(failure.manager.create_container("repaired_equipment", lab.equipment_definition.size, InventoryManager.ServiceType.EQUIPMENT_SLOT, lab.equipment_definition.equipment_slots), InventoryResult.Code.OK, "准备正确的槽位配置")
	checks.code(failed_window.bind(failure.manager, "repaired_equipment", InventoryManager.ServiceType.EQUIPMENT_SLOT, failure.lookup_config), InventoryResult.Code.OK, "正确配置可以重新绑定失败窗口")
	checks.expect(body._manager == failure.manager and body.mouse_filter != Control.MOUSE_FILTER_IGNORE, "成功重绑恢复槽位交互")
	failed_window.unbind()
	checks.expect(not body._can_drop_data(body.size * 0.5, data), "正常解绑之后也拒绝拖放预览")
	failure.hide()
	lab.show()

## 窗口加高后全部内容一次显示，滚轮不应再产生偏移或遮挡下方饰品槽。
func _test_full_equipment_content() -> void:
	var scroll: ScrollContainer = equipment.get_node("Body/Content/Scroll")
	checks.expect(not scroll.get_v_scroll_bar().visible, "默认装备窗口完整显示布局，无纵向滚动条")
	checks.expect(not scroll.get_h_scroll_bar().visible, "默认装备窗口没有横向溢出")
	for slot in layout._find_slots():
		checks.expect(scroll.get_global_rect().encloses(slot.get_global_rect()), "装备槽无需滚动即完整可见：" + String(slot.slot_id))
	checks.expect(get_viewport().get_visible_rect().encloses(equipment.get_global_rect()), "整个装备窗口位于可见屏幕内")
	var point := scroll.global_position + Vector2(4, 4)
	await _motion(point, 0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
		event.factor = 1000
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()
	checks.equal(scroll.scroll_vertical, 0, "完整显示后滚轮不产生纵向偏移")
	checks.equal(scroll.scroll_horizontal, 0, "完整显示后滚轮不产生横向偏移")

## 记录节点相对位置与尺寸，检测绑定或刷新是否意外重排用户场景。
func _geometry(root: Control) -> Dictionary:
	var result := {}
	for node: Control in root.find_children("*", "Control", true, false):
		if node is EquipmentSlotView or node.get_parent() == root:
			result[str(root.get_path_to(node))] = [node.position, node.size]
	return result

## 按槽位标识查找场景组件，不依赖它在分组中的位置。
func _slot(id: StringName) -> EquipmentSlotView:
	for slot in layout._find_slots():
		if slot.slot_id == id:
			return slot
	return null

## 读取当前装备记录，空槽不发出业务失败通知。
func _record(id: StringName) -> Dictionary:
	var pos: Vector2i = lab.manager.get_slot_position(EQUIPMENT_ID, id).payload
	var state: Dictionary = lab.manager.get_snapshot(EQUIPMENT_ID)
	return state.items.get(state.cells[0][pos.x], {})

## 在背包独立快照中查找演示物品，测试不依赖自动添加的具体位置。
func _find(config_id: int) -> Dictionary:
	for record: Dictionary in lab.manager.get_snapshot(lab.BAG_ID).items.values():
		if record.instance.config_id == config_id:
			return record
	return {}

## 将背包锚点转换为实际鼠标坐标。
func _bag_point(cell: Vector2i) -> Vector2:
	return bag.global_position + Vector2(cell * 52) + Vector2(26, 26)

## 使用场景组件的实际中心，兼容手工调整的位置和尺寸。
func _center(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5

## 发出完整原生拖放序列，失败落点也必须清理预览。
func _drag(from: Vector2, to: Vector2) -> void:
	await _begin(from)
	await _motion(to, MOUSE_BUTTON_MASK_LEFT)
	await _button(to, false)
	checks.expect(not get_viewport().gui_is_dragging(), "释放后清理装备拖拽预览")

## 按住左键并越过拖拽阈值，验证引擎实际启动拖放。
func _begin(point: Vector2) -> void:
	await _motion(point, 0)
	await _button(point, true)
	await _motion(point + Vector2(16, 0), MOUSE_BUTTON_MASK_LEFT)
	checks.expect(get_viewport().gui_is_dragging(), "真实输入启动物品拖拽")

## 发送真实鼠标移动，保持 Input 的位置与按钮状态同步。
func _motion(point: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = buttons
	event.relative = point - _last_pointer
	_last_pointer = point
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发送完整鼠标按钮状态，确保场景通过原生 GUI 接收交互。
func _button(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (1 << (int(button) - 1)) if pressed else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

## 发出键盘按下与释放，覆盖取消及装备来源旋转限制。
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

## 查找引擎挂载的实际预览，不把静态装备图标误认为拖拽预览。
func _preview() -> Control:
	for node in get_viewport().find_children("*", "PanelContainer", true, false):
		if node.scene_file_path == "res://UI/Inventory/inventory_item.tscn" \
				and node.get_parent().name != "Items" and not node.get_parent() is EquipmentSlotView:
			return node
	return null

## 等待容器排序与滚动区域布局稳定后读取实际几何信息。
func _settle() -> void:
	for frame in range(4):
		await get_tree().process_frame
