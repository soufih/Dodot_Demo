extends RefCounted
## 装备服务的独立规则夹具、完整状态校验及真实 Manager 双容器事务回归。

const FaultEquipment = preload("res://tests/inventory/equipment_fault_service.gd")
const MAIN := Vector2i(0, 0)
const OFF := Vector2i(1, 0)
const HEAD := Vector2i(2, 0)
const LEFT_RING := Vector2i(3, 0)
const RIGHT_RING := Vector2i(4, 0)
var _configs: Dictionary = {}

## 运行服务与事务测试；只使用独立物品定义，结束后恢复 Manager 的配置查询。
func run(t, manager) -> void:
	_make_configs()
	_test_enum_types(t)
	_test_initialization(t)
	_test_operations(t)
	_test_quick_add(t)
	_test_conflicts_and_plans(t)
	_test_unsupported(t)
	_test_rollback(t)
	_test_manager_factory(t, manager)
	_test_transactions(t, manager)
	t.code(manager.configure(t.lookup), InventoryResult.Code.OK, "装备测试恢复配置查询")

## 构造单手、盾牌、头盔、戒指及双手武器；每件保留自己的背包占格。
func _make_configs() -> void:
	for data in [[201, ENUM.EquipmentType.ONE_HAND, Vector2i(1, 3)], [202, ENUM.EquipmentType.SHIELD, Vector2i(2, 2)],
			[203, ENUM.EquipmentType.HELMET, Vector2i.ONE], [204, ENUM.EquipmentType.RING, Vector2i.ONE],
			[205, ENUM.EquipmentType.TWO_HAND, Vector2i(1, 3)]]:
		var config := ItemConfig.new()
		config.ItemID = data[0]
		config.GridSize = data[2]
		config.Equipment = EquipmentItemConfig.new()
		config.Equipment.equipment_type = data[1]
		_configs[config.ItemID] = config
	_configs[205].Equipment.blocked_slot_ids.append(&"off_hand")
	var plain := ItemConfig.new()
	plain.ItemID = 206
	_configs[206] = plain
	var stackable: ItemConfig = _configs[204].duplicate(true)
	stackable.ItemID = 207
	stackable.MaxStack = 10
	_configs[207] = stackable
	var invalid: ItemConfig = _configs[204].duplicate(true)
	invalid.ItemID = 208
	invalid.Equipment.equipment_type = ENUM.EquipmentType.NONE
	_configs[208] = invalid

## 返回测试物品配置，不访问正式 ResourceManager。
func _lookup(id: int) -> ItemConfig:
	return _configs.get(id)

## 验证枚举默认值、所有合法类型、非法序列化值及迁移后资源，确保物品与槽位使用同一类型。
func _test_enum_types(t) -> void:
	var rule := EquipmentItemConfig.new()
	t.equal(rule.equipment_type, ENUM.EquipmentType.NONE, "装备类型默认未配置，不隐式变为单手武器")
	t.expect(not rule.validate(), "NONE 不能作为可穿戴装备类型")
	for value in ENUM.EquipmentType.values():
		if value == ENUM.EquipmentType.NONE:
			continue
		rule.set("equipment_type", value)
		t.expect(rule.validate(), "所有已定义装备枚举类型均可配置")
		var slot := EquipmentSlotDefinition.new()
		slot.slot_id = &"enum_slot"
		slot.accepted_types.assign([value])
		t.expect(slot.validate(), "槽位允许类型使用同一装备枚举")
		var config := ItemConfig.new()
		config.ItemID = 300
		config.Equipment = rule.duplicate(true)
		var lookup := func(id: int) -> ItemConfig: return config if id == config.ItemID else null
		var service := EquipmentSlotService.new(lookup, [slot])
		t.code(service.initialize("enum_equipment", Vector2i.ONE), InventoryResult.Code.OK, "枚举槽位可初始化装备服务")
		t.code(service.add(ItemInstance.new(300), Vector2i.ZERO), InventoryResult.Code.OK, "枚举适配的装备能够实际放入槽位")
	for value in [-1, 999]:
		rule.set("equipment_type", value)
		t.expect(not rule.validate(), "未知装备枚举值被拒绝")
		var slot := _slot(&"invalid_enum", [])
		slot.accepted_types.assign([value])
		t.expect(not slot.validate(), "槽位不能接受未定义的枚举值")
	for property in rule.get_property_list():
		if property.name == "equipment_type":
			t.equal(property.hint, PROPERTY_HINT_ENUM, "检查器中的装备类型提供枚举选择")
	var slot := _slot(&"hint", [ENUM.EquipmentType.ONE_HAND])
	for property in slot.get_property_list():
		if property.name == "accepted_types":
			t.expect(property.hint == PROPERTY_HINT_TYPE_STRING and property.hint_string.begins_with("%d/%d:" % [TYPE_INT, PROPERTY_HINT_ENUM]), "槽位允许类型数组的元素提供枚举选择")
	for path in ["res://Rescource/Data/Inventory/player_equipment.tres",
			"res://Rescource/Data/Inventory/equipment_demo_definition.tres"]:
		var definition: InventoryDefinition = load(path)
		t.expect(definition.equipment_slots.all(func(entry: EquipmentSlotDefinition) -> bool: return entry.validate()), "迁移后的装备定义可加载且枚举规则有效")
	var catalog: ItemCatalog = load("res://Rescource/Data/Inventory/equipment_demo_catalog.tres")
	t.expect(catalog.Item.all(func(config: ItemConfig) -> bool: return config.Equipment == null or config.Equipment.validate()), "迁移后的演示装备目录保存有效枚举")

## 创建配置资源；槽位名称和允许类型均由调用方指定。
func _slot(id: StringName, types: Array[ENUM.EquipmentType], priority: int = 0) -> EquipmentSlotDefinition:
	var slot := EquipmentSlotDefinition.new()
	slot.slot_id = id
	slot.accepted_types = types
	slot.auto_equip_priority = priority
	return slot

## 五个固定业务槽位；右戒指优先于左戒指，用于验证排序不依赖矩阵扫描顺序。
func _slots() -> Array[EquipmentSlotDefinition]:
	return [_slot(&"main_hand", [ENUM.EquipmentType.ONE_HAND, ENUM.EquipmentType.TWO_HAND]),
		_slot(&"off_hand", [ENUM.EquipmentType.ONE_HAND, ENUM.EquipmentType.SHIELD]), _slot(&"head", [ENUM.EquipmentType.HELMET]),
		_slot(&"ring_left", [ENUM.EquipmentType.RING]), _slot(&"ring_right", [ENUM.EquipmentType.RING], -10)]

## 初始化一个独立服务并断言成功，避免其状态与其他用例相互影响。
func _service(t, id: String = "equipment") -> EquipmentSlotService:
	var service := EquipmentSlotService.new(_lookup, _slots())
	t.code(service.initialize(id, Vector2i(5, 1)), InventoryResult.Code.OK, "初始化装备服务")
	return service

## 检查抽象契约、非法槽位、矩阵约束、名称映射以及配置输入隔离。
func _test_initialization(t) -> void:
	var script: Script = preload("res://Script/Gameplay/Inventory/Services/EquipmentSlotService.gd")
	t.expect(not script.is_abstract(), "装备服务实现全部抽象接口")
	var service := EquipmentSlotService.new(_lookup, _slots())
	t.code(service.query(MAIN), InventoryResult.Code.RULE_REJECTED, "未初始化查询拒绝")
	t.code(service.add(ItemInstance.new(201), MAIN), InventoryResult.Code.RULE_REJECTED, "未初始化添加拒绝")
	t.code(service.get_slot_position(&"main_hand"), InventoryResult.Code.RULE_REJECTED, "未初始化槽位映射拒绝")
	t.code(service.initialize("", Vector2i(5, 1)), InventoryResult.Code.RULE_REJECTED, "装备栏拒绝空标识")
	t.code(service.initialize("bad", Vector2i(1, 5)), InventoryResult.Code.INVALID_POSITION, "装备栏要求 N 乘一矩阵")
	t.expect(service.container == null, "失败初始化不绑定容器")
	t.code(service.initialize("valid", Vector2i(5, 1)), InventoryResult.Code.OK, "失败后可重新初始化")
	t.code(service.initialize("again", Vector2i(5, 1)), InventoryResult.Code.RULE_REJECTED, "装备栏拒绝重复初始化")
	t.equal(service.get_slot_position(&"ring_right").payload, RIGHT_RING, "槽位名称映射到内部坐标")
	t.equal(service.get_slot_id(OFF).payload, &"off_hand", "坐标映射回槽位名称")
	t.code(service.get_slot_position(&"missing"), InventoryResult.Code.INVALID_POSITION, "未知槽位不回退到主手")
	t.code(service.get_slot_id(Vector2i(5, 0)), InventoryResult.Code.OUT_OF_BOUNDS, "槽位查询检查越界")
	for definitions in [[], [null], [_slot(&"", [ENUM.EquipmentType.RING])], [_slot(&"head", [])],
			[_slot(&"head", [ENUM.EquipmentType.NONE])], [_slot(&"head", [ENUM.EquipmentType.HELMET]), _slot(&"head", [ENUM.EquipmentType.RING])]]:
		var typed: Array[EquipmentSlotDefinition] = []
		typed.assign(definitions)
		var invalid := EquipmentSlotService.new(_lookup, typed)
		t.expect(not invalid.initialize("invalid", Vector2i(typed.size(), 1)).is_ok(), "拒绝空、重复或缺失规则的装备槽")
		t.expect(invalid.container == null, "非法槽位未创建容器")
	var definitions := _slots()
	var isolated := EquipmentSlotService.new(_lookup, definitions)
	definitions[0].slot_id = &"changed"
	definitions[0].accepted_types.clear()
	definitions.clear()
	t.code(isolated.initialize("isolated", Vector2i(5, 1)), InventoryResult.Code.OK, "服务复制槽位配置")
	t.code(isolated.add(ItemInstance.new(201), MAIN), InventoryResult.Code.OK, "调用方修改配置不改变服务规则")

## 验证类型、数量、单格占用、移动交换、方向保留与查询副本隔离。
func _test_operations(t) -> void:
	var service: InventoryService = _service(t)
	for id in [206, 207, 208, 999]:
		t.code(service.add(ItemInstance.new(id), LEFT_RING), InventoryResult.Code.INVALID_ITEM, "拒绝普通、可堆叠或无效装备")
	t.code(service.add(null, MAIN), InventoryResult.Code.INVALID_ITEM, "装备拒绝空实例")
	t.code(service.add(ItemInstance.new(201, 2), MAIN), InventoryResult.Code.INVALID_ITEM, "装备数量必须为一")
	t.code(service.add(ItemInstance.new(201, 0), MAIN), InventoryResult.Code.INVALID_ITEM, "装备拒绝零数量")
	t.code(service.add(ItemInstance.new(201), Vector2i(-1, 0)), InventoryResult.Code.INVALID_POSITION, "装备拒绝负坐标")
	t.code(service.add(ItemInstance.new(201), Vector2i(0, 1)), InventoryResult.Code.OUT_OF_BOUNDS, "装备只有一行")
	t.code(service.add(ItemInstance.new(201), HEAD), InventoryResult.Code.RULE_REJECTED, "武器不能放入头盔槽")
	var sword := ItemInstance.new(201, 1, true)
	t.code(service.validate_add(sword, MAIN), InventoryResult.Code.OK, "装备添加预览有效")
	t.equal(service.container.revision, 0, "预览不改变版本")
	t.code(service.add(sword, MAIN), InventoryResult.Code.OK, "网格武器可以装备到单槽")
	t.equal(service.container.cells[0], [sword.instance_id, null, null, null, null], "装备忽略背包矩形尺寸")
	t.equal(service.query(MAIN).payload.instance.rotated, true, "装备保留来自背包的方向元数据")
	t.code(service.add(sword, OFF), InventoryResult.Code.INVALID_ITEM, "装备不能重复加入同一实例")
	t.code(service.add(ItemInstance.new(201), MAIN), InventoryResult.Code.OCCUPIED, "装备添加不隐式替换")
	var before: Dictionary = t.value(service.stage_snapshot())
	t.code(service.can_place(sword, MAIN, true), InventoryResult.Code.OK, "原位装备预览释放自身占用")
	t.equal(t.value(service.stage_snapshot()), before, "装备预览保持真实状态")
	var record: Dictionary = service.query(MAIN).payload
	record.instance.quantity = 99
	sword.quantity = 0
	t.equal(service.query(MAIN).payload.instance.quantity, 1, "装备隔离输入和查询副本")
	t.code(service.move(MAIN, HEAD), InventoryResult.Code.RULE_REJECTED, "移动到错误类型失败")
	t.equal(t.value(service.stage_snapshot()), before, "失败移动不改变完整状态")
	t.code(service.move(MAIN, MAIN), InventoryResult.Code.OK, "装备原地移动成功")
	t.equal(t.value(service.stage_snapshot()), before, "原地移动不递增版本")
	t.code(service.move(MAIN, OFF), InventoryResult.Code.OK, "单手武器可移动到副手")
	t.code(service.add(ItemInstance.new(201), MAIN), InventoryResult.Code.OK, "主手再装备一把武器")
	t.code(service.swap(MAIN, OFF), InventoryResult.Code.OK, "双向适配的装备可交换")
	t.equal(service.query(MAIN).payload.instance.instance_id, sword.instance_id, "交换保留装备身份")
	service.remove(OFF)
	service.add(ItemInstance.new(202), OFF)
	before = t.value(service.stage_snapshot())
	t.code(service.swap(MAIN, OFF), InventoryResult.Code.RULE_REJECTED, "盾牌不能反向进入主手导致整体交换失败")
	t.equal(t.value(service.stage_snapshot()), before, "失败交换不移动任一装备")
	var removed := service.remove(MAIN)
	t.code(removed, InventoryResult.Code.OK, "装备移除成功")
	t.equal(removed.payload.instance_id, sword.instance_id, "移除返回原实例身份")
	t.code(service.query(MAIN), InventoryResult.Code.ITEM_NOT_FOUND, "移除后装备槽为空")

## 自动装备跳过不适配槽，按优先级选择，不自动替换；同优先级按配置顺序。
func _test_quick_add(t) -> void:
	var service := _service(t)
	var ring := ItemInstance.new(204)
	t.equal(service.quick_add(ring).payload, RIGHT_RING, "自动装备优先右戒指槽")
	t.code(service.quick_add(ring), InventoryResult.Code.INVALID_ITEM, "自动装备拒绝重复实例")
	t.equal(service.quick_add(ItemInstance.new(204)).payload, LEFT_RING, "首选槽占用后选择下一个兼容空槽")
	var before: Dictionary = t.value(service.stage_snapshot())
	t.code(service.quick_add(ItemInstance.new(204)), InventoryResult.Code.NO_SPACE, "兼容槽全满时不自动替换")
	t.equal(t.value(service.stage_snapshot()), before, "自动装备失败状态不变")
	t.equal(service.quick_add(ItemInstance.new(203)).payload, HEAD, "自动装备跳过不兼容槽位")
	t.equal(service.quick_add(ItemInstance.new(201)).payload, MAIN, "相同优先级按配置顺序选择")
	t.code(service.quick_add(ItemInstance.new(206)), InventoryResult.Code.INVALID_ITEM, "无效装备不误报无空间")

## 双手与副手互斥必须双向检查，直接伪造最终计划也不能绕过类型和组合规则。
func _test_conflicts_and_plans(t) -> void:
	var service := _service(t)
	service.add(ItemInstance.new(202), OFF)
	var before: Dictionary = t.value(service.stage_snapshot())
	t.code(service.add(ItemInstance.new(205), MAIN), InventoryResult.Code.RULE_REJECTED, "副手非空时拒绝双手武器")
	t.equal(t.value(service.stage_snapshot()), before, "冲突不自动卸下副手")
	service.remove(OFF)
	var two_hand := ItemInstance.new(205)
	t.code(service.add(two_hand, MAIN), InventoryResult.Code.OK, "副手为空时双手武器可装备")
	before = t.value(service.stage_snapshot())
	t.code(service.add(ItemInstance.new(202), OFF), InventoryResult.Code.RULE_REJECTED, "已有双手武器阻止装备副手")
	t.code(service.can_place(ItemInstance.new(201), OFF, false), InventoryResult.Code.RULE_REJECTED, "放置预览执行双向阻塞规则")
	t.equal(t.value(service.stage_snapshot()), before, "冲突预览和添加均不修改版本")
	var staged := service.stage_snapshot()
	var staged_before: Dictionary = t.value(staged)
	t.code(service.stage_add(staged, ItemInstance.new(202), OFF), InventoryResult.Code.RULE_REJECTED, "暂存添加不能绕过互斥")
	t.equal(t.value(staged), staged_before, "失败暂存添加也保持计划不变")
	var shield := ItemInstance.new(202)
	staged.items[shield.instance_id] = {"instance": shield, "anchor": OFF}
	staged.cells[0][1] = shield.instance_id
	t.code(service.validate_plan(staged), InventoryResult.Code.RULE_REJECTED, "伪造双手与副手最终组合被拒绝")
	# 反转记录插入顺序，确保校验不依赖字典遍历顺序。
	var reversed: Dictionary = {}
	reversed[shield.instance_id] = staged.items[shield.instance_id]
	reversed[two_hand.instance_id] = staged.items[two_hand.instance_id]
	staged.items = reversed
	t.code(service.commit(staged), InventoryResult.Code.RULE_REJECTED, "反向记录顺序也拒绝冲突提交")
	t.equal(t.value(service.stage_snapshot()), before, "非法计划提交后状态未变")
	staged = service.stage_snapshot()
	staged.items[two_hand.instance_id].anchor = HEAD
	staged.cells[0][0] = null
	staged.cells[0][2] = two_hand.instance_id
	t.code(service.commit(staged), InventoryResult.Code.RULE_REJECTED, "直接提交也检查槽位类型")
	staged = service.stage_snapshot()
	staged.cells[0][0] = null
	t.code(service.commit(staged), InventoryResult.Code.INTERNAL_ERROR, "拒绝矩阵与记录不一致")
	var stale := service.stage_snapshot()
	service.remove(MAIN)
	t.code(service.commit(stale), InventoryResult.Code.STALE_STATE, "装备服务拒绝旧版本计划")
	var saved := service.stage_snapshot()
	service.add(ItemInstance.new(204), RIGHT_RING)
	t.code(service.restore(saved), InventoryResult.Code.OK, "装备服务恢复事务前快照")
	t.equal(t.value(service.stage_snapshot()), t.value(saved), "恢复包含原占位和版本")
	# 自身槽不能被自身阻塞，未出现在布局中的槽位标识则不产生虚拟占位。
	var single := EquipmentSlotService.new(_lookup, [_slot(&"off_hand", [ENUM.EquipmentType.TWO_HAND])])
	single.initialize("self_block", Vector2i.ONE)
	t.code(single.add(ItemInstance.new(205), MAIN), InventoryResult.Code.RULE_REJECTED, "拒绝装备阻塞自身槽位")
	single = EquipmentSlotService.new(_lookup, [_slot(&"main_hand", [ENUM.EquipmentType.TWO_HAND])])
	single.initialize("without_off", Vector2i.ONE)
	t.code(single.add(ItemInstance.new(205), MAIN), InventoryResult.Code.OK, "不同布局忽略不存在的阻塞槽位")

## 所有堆叠和分割入口明确拒绝，方向不变时无操作成功，改变方向时不支持。
func _test_unsupported(t) -> void:
	var service := _service(t)
	var item := ItemInstance.new(201, 1, true)
	service.add(item, MAIN)
	var before: Dictionary = t.value(service.stage_snapshot())
	var staged := service.stage_snapshot()
	for result in [service.stack(MAIN, OFF), service.can_stack(item, MAIN), service.can_split(MAIN),
			service.split(MAIN, OFF), service.stage_stack(staged, item, MAIN),
			service.stage_split(staged, MAIN), service.stage_place_split(staged, item, OFF),
			service.rotate(MAIN, false), service.can_place(item, OFF, false),
			service.move(MAIN, OFF, false), service.swap(MAIN, MAIN, false)]:
		t.code(result, InventoryResult.Code.UNSUPPORTED, "装备服务禁止堆叠、分割和方向修改")
	t.code(service.rotate(MAIN, true), InventoryResult.Code.OK, "保持装备方向无变化成功")
	t.expect(not service.rotate(MAIN, true).changed, "方向不变不提交")
	t.equal(t.value(service.stage_snapshot()), before, "不支持的操作不改变真实状态")
	t.equal(t.value(staged), before, "不支持的操作不改变暂存状态")

## 本地提交真实写入后故障，应恢复装备与版本，并允许后续正常重试。
func _test_rollback(t) -> void:
	var service := FaultEquipment.new(_lookup, _slots())
	service.initialize("equipment_fault", Vector2i(5, 1))
	var before: Dictionary = t.value(service.stage_snapshot())
	service.fail_after_commit = true
	t.code(service.add(ItemInstance.new(201), MAIN), InventoryResult.Code.INTERNAL_ERROR, "模拟装备本地写入后失败")
	t.equal(t.value(service.stage_snapshot()), before, "本地失败恢复数据和版本")
	service.fail_after_commit = false
	t.code(service.add(ItemInstance.new(201), MAIN), InventoryResult.Code.OK, "恢复后可正常重试")

## 经统一工厂创建装备栏，检查失败清理、类型兼容、槽位映射、命令路由及通知。
func _test_manager_factory(t, m) -> void:
	t.code(m.configure(_lookup), InventoryResult.Code.OK, "工厂注入装备测试配置")
	t.equal(m.ServiceType.SLOT, 0, "增加装备类型保留普通背包枚举值")
	t.equal(m.ServiceType.GRID, 1, "增加装备类型保留网格背包枚举值")
	var notices: Array = []
	var errors: Array = []
	var on_change := func(id, revision, ids): notices.append([id, revision, ids])
	var on_error := func(code, message): errors.append([code, message])
	m.container_changed.connect(on_change)
	m.operation_failed.connect(on_error)
	t.code(m.create_container("missing_rules", Vector2i.ONE, m.ServiceType.EQUIPMENT_SLOT), InventoryResult.Code.INVALID_POSITION, "装备工厂拒绝缺少槽位规则")
	t.expect(not m.has_container("missing_rules"), "装备工厂失败不注册容器")
	t.code(m.create_container("bad_size", Vector2i(5, 2), m.ServiceType.EQUIPMENT_SLOT, _slots()), InventoryResult.Code.INVALID_POSITION, "装备工厂校验槽位数量及单行尺寸")
	t.expect(not m.has_container("bad_size"), "错误尺寸不残留容器")
	var repeated: Array[EquipmentSlotDefinition] = [_slot(&"ring", [ENUM.EquipmentType.RING]), _slot(&"ring", [ENUM.EquipmentType.RING])]
	t.code(m.create_container("bad_slots", Vector2i(2, 1), m.ServiceType.EQUIPMENT_SLOT, repeated), InventoryResult.Code.RULE_REJECTED, "装备工厂拒绝重复槽位标识")
	t.expect(not m.has_container("bad_slots"), "错误槽位不残留容器")
	t.code(m.create_container("wrong_grid", Vector2i(5, 1), m.ServiceType.GRID, _slots()), InventoryResult.Code.RULE_REJECTED, "网格工厂不静默忽略装备配置")
	t.code(m.create_container("wrong_slot", Vector2i(5, 1), m.ServiceType.SLOT, _slots()), InventoryResult.Code.RULE_REJECTED, "普通工厂不静默忽略装备配置")
	t.code(m.create_container("unknown_type", Vector2i.ONE, 99, _slots()), InventoryResult.Code.UNSUPPORTED, "未知服务类型仍明确失败")
	t.equal(errors.size(), 6, "工厂每次失败经统一入口报告一次")
	t.equal(notices.size(), 0, "工厂失败不发送容器内容变化通知")
	var definitions := _slots()
	t.code(m.create_container("factory_equipment", Vector2i(5, 1), m.ServiceType.EQUIPMENT_SLOT, definitions), InventoryResult.Code.OK, "Manager 工厂创建装备服务")
	definitions[0].accepted_types.clear()
	t.expect(m.has_container("factory_equipment"), "装备工厂成功后可查询注册状态")
	t.code(m.get_slot_position("factory_equipment", &"main_hand"), InventoryResult.Code.OK, "Manager 转换装备槽位标识")
	t.equal(m.get_slot_position("factory_equipment", &"main_hand").payload, MAIN, "主手槽位映射正确")
	t.equal(m.get_slot_id("factory_equipment", RIGHT_RING).payload, &"ring_right", "Manager 反向查询槽位标识")
	t.code(m.get_slot_position("factory_equipment", &"missing"), InventoryResult.Code.INVALID_POSITION, "Manager 拒绝未知槽位标识")
	t.code(m.get_slot_id("factory_equipment", Vector2i(5, 0)), InventoryResult.Code.OUT_OF_BOUNDS, "Manager 装备槽位查询检查边界")
	t.code(m.get_slot_position("absent", &"main_hand"), InventoryResult.Code.CONTAINER_NOT_FOUND, "槽位标识查询拒绝未知容器")
	t.code(m.get_slot_id("absent", MAIN), InventoryResult.Code.CONTAINER_NOT_FOUND, "槽位坐标查询拒绝未知容器")
	var initial: Dictionary = t.value(m.get_snapshot("factory_equipment"))
	t.code(m.create_container("factory_equipment", Vector2i(5, 1), m.ServiceType.EQUIPMENT_SLOT, _slots()), InventoryResult.Code.DUPLICATE_CONTAINER, "装备工厂遵守重复容器限制")
	t.equal(t.value(m.get_snapshot("factory_equipment")), initial, "重复创建不覆盖已注册装备栏")
	t.code(m.create_container("factory_bag", Vector2i(3, 3), m.ServiceType.GRID), InventoryResult.Code.OK, "旧三参数网格创建接口兼容")
	t.code(m.create_container("factory_slot", Vector2i.ONE, m.ServiceType.SLOT), InventoryResult.Code.OK, "旧三参数普通创建接口兼容")
	for id in ["factory_bag", "factory_slot"]:
		t.code(m.get_slot_position(id, &"main_hand"), InventoryResult.Code.UNSUPPORTED, "普通容器不提供装备槽位标识映射")
		t.code(m.get_slot_id(id, MAIN), InventoryResult.Code.UNSUPPORTED, "普通容器不提供装备槽位坐标映射")
	notices.clear()
	var added: InventoryResult = m.add_to_container("factory_equipment", 201, 1, MAIN)
	t.code(added, InventoryResult.Code.OK, "工厂服务继承统一配置查询且隔离外部槽位修改")
	t.equal(notices.size(), 1, "工厂装备添加经 Manager 通知一次")
	t.code(m.move_in_container("factory_equipment", MAIN, OFF), InventoryResult.Code.OK, "Manager 路由装备移动")
	t.code(m.add_to_container("factory_equipment", 201, 1, MAIN), InventoryResult.Code.OK, "Manager 添加另一件装备")
	t.code(m.swap_in_container("factory_equipment", MAIN, OFF), InventoryResult.Code.OK, "Manager 路由装备栏内交换")
	t.equal(m.get_item_at("factory_equipment", MAIN).instance.instance_id, added.payload.instance_id, "Manager 装备交换保留身份")
	t.code(m.can_place("factory_equipment", added.payload, MAIN, false), InventoryResult.Code.OK, "Manager 路由装备自身放置预览")
	var before: Dictionary = t.value(m.get_snapshot("factory_equipment"))
	notices.clear()
	t.code(m.add_to_container("factory_equipment", 203, 1, MAIN), InventoryResult.Code.RULE_REJECTED, "Manager 添加仍校验装备类型")
	t.code(m.rotate_in_container("factory_equipment", MAIN, true), InventoryResult.Code.UNSUPPORTED, "Manager 不绕过装备旋转限制")
	t.code(m.stack_in_container("factory_equipment", MAIN, OFF), InventoryResult.Code.UNSUPPORTED, "Manager 不绕过装备堆叠限制")
	t.code(m.split_in_container("factory_equipment", MAIN, OFF), InventoryResult.Code.UNSUPPORTED, "Manager 不绕过装备分割限制")
	t.equal(t.value(m.get_snapshot("factory_equipment")), before, "失败命令保持工厂装备栏状态")
	t.equal(notices.size(), 0, "失败命令不通知内容变化")
	t.equal(m.quick_add_to_container("factory_equipment", 204).payload, RIGHT_RING, "Manager 自动装备遵守优先级")
	t.equal(m.quick_add_to_container("factory_equipment", 204).payload, LEFT_RING, "Manager 自动装备选择备用空槽")
	t.code(m.quick_add_to_container("factory_equipment", 204), InventoryResult.Code.NO_SPACE, "Manager 自动装备不替换满槽")
	t.code(m.switch_to_container("factory_equipment", "factory_bag", MAIN, MAIN), InventoryResult.Code.OK, "工厂装备服务原子卸下到网格背包")
	t.code(m.swap_between_containers("factory_bag", "factory_equipment", MAIN, OFF), InventoryResult.Code.OK, "工厂装备服务支持跨容器交换")
	t.code(m.remove_from_container("factory_equipment", OFF), InventoryResult.Code.OK, "Manager 路由装备移除")
	t.code(m.switch_to_container("factory_bag", "factory_equipment", MAIN, MAIN), InventoryResult.Code.OK, "工厂装备服务原子穿戴")
	t.code(m.unregister_container("factory_equipment"), InventoryResult.Code.OK, "工厂装备服务可以注销")
	t.code(m.get_slot_id("factory_equipment", MAIN), InventoryResult.Code.CONTAINER_NOT_FOUND, "注销后不再暴露槽位映射")
	m.unregister_container("factory_bag")
	m.unregister_container("factory_slot")
	m.container_changed.disconnect(on_change)
	m.operation_failed.disconnect(on_error)

## 注册到现有 Manager，验证跨容器穿戴、替换、卸下失败和双边故障回滚。
func _test_transactions(t, m) -> void:
	t.code(m.configure(_lookup), InventoryResult.Code.OK, "事务注入装备测试配置")
	var equipment := FaultEquipment.new(_lookup, _slots())
	equipment.initialize("equipped", Vector2i(5, 1))
	t.code(m.register_container("equipped", equipment), InventoryResult.Code.OK, "装备服务通过现有注册接口接入")
	t.code(m.create_container("equip_bag", Vector2i(3, 3), m.ServiceType.GRID), InventoryResult.Code.OK, "创建事务网格背包")
	var notices: Array = []
	var on_change := func(id, revision, ids): notices.append([id, revision, ids])
	m.container_changed.connect(on_change)
	var sword: ItemInstance = m.add_to_container("equip_bag", 201, 1, MAIN, true).payload
	var bag_before: Dictionary = t.value(m.get_snapshot("equip_bag"))
	var equipment_before: Dictionary = t.value(m.get_snapshot("equipped"))
	notices.clear()
	equipment.fail_after_commit = true
	t.code(m.switch_to_container("equip_bag", "equipped", MAIN, MAIN), InventoryResult.Code.INTERNAL_ERROR, "装备目标写入后故障")
	t.equal(t.value(m.get_snapshot("equip_bag")), bag_before, "故障恢复源背包和版本")
	t.equal(t.value(m.get_snapshot("equipped")), equipment_before, "故障恢复目标装备和版本")
	t.equal(notices.size(), 0, "故障不发送成功通知")
	equipment.fail_after_commit = false
	t.code(m.switch_to_container("equip_bag", "equipped", MAIN, MAIN), InventoryResult.Code.OK, "背包到装备槽原子穿戴")
	t.equal(m.get_item_at("equipped", MAIN).instance.instance_id, sword.instance_id, "穿戴保留实例身份")
	t.expect(m.get_item_at("equipped", MAIN).instance.rotated, "跨容器保留背包方向")
	t.equal(m.get_snapshot("equip_bag").items.size(), 0, "穿戴清空源物品所有网格占位")
	t.equal(notices.size(), 2, "成功事务通知双方一次")
	var other: ItemInstance = m.add_to_container("equip_bag", 201, 1, MAIN).payload
	t.code(m.swap_between_containers("equip_bag", "equipped", MAIN, MAIN), InventoryResult.Code.OK, "背包装备替换复用交换事务")
	t.equal(m.get_item_at("equipped", MAIN).instance.instance_id, other.instance_id, "新装备进入目标槽")
	t.equal(m.get_item_at("equip_bag", Vector2i(2, 0)).instance.instance_id, sword.instance_id, "旧装备按原方向完整放回网格")
	m.add_to_container("equip_bag", 203, 1, Vector2i(1, 1))
	bag_before = t.value(m.get_snapshot("equip_bag"))
	equipment_before = t.value(m.get_snapshot("equipped"))
	notices.clear()
	t.code(m.switch_to_container("equip_bag", "equipped", Vector2i(1, 1), OFF), InventoryResult.Code.RULE_REJECTED, "跨容器不能绕过槽位类型")
	t.code(m.switch_to_container("equipped", "equip_bag", MAIN, Vector2i(2, 1)), InventoryResult.Code.OUT_OF_BOUNDS, "卸下遇到放不下的背包位置时失败")
	t.code(m.stack_between_containers("equip_bag", "equipped", MAIN, MAIN), InventoryResult.Code.UNSUPPORTED, "跨容器不能向装备栏堆叠")
	t.equal(t.value(m.get_snapshot("equip_bag")), bag_before, "失败操作保持背包完整状态")
	t.equal(t.value(m.get_snapshot("equipped")), equipment_before, "失败操作保持装备完整状态")
	t.equal(notices.size(), 0, "失败操作不发送容器变更")
	t.code(m.switch_to_container("equipped", "equip_bag", MAIN, MAIN), InventoryResult.Code.OCCUPIED, "卸下到占用位置不覆盖物品")
	m.remove_from_container("equip_bag", MAIN)
	t.code(m.switch_to_container("equipped", "equip_bag", MAIN, MAIN), InventoryResult.Code.OK, "空出背包位置后原子卸下")
	t.equal(m.get_snapshot("equipped").items.size(), 0, "卸下后装备槽为空")
	t.equal(m.get_item_at("equip_bag", MAIN).instance.instance_id, other.instance_id, "卸下保留物品身份")
	m.container_changed.disconnect(on_change)
	m.unregister_container("equip_bag")
	m.unregister_container("equipped")
