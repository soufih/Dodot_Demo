extends RefCounted
## 仓库继承行为、整理守恒、装箱失败、提交回滚与跨容器事务回归。

const FaultWarehouse = preload("res://tests/inventory/warehouse_fault_service.gd")

## 使用独立配置运行全部仓库断言，测试结束清理注册表以免影响其他套件。
func run(t, manager) -> void:
	_test_inheritance(t)
	_test_organize(t)
	_test_order(t)
	_test_packing_failure(t)
	_test_commit_failure(t)
	_test_manager(t, manager)

## 以统一契约调用继承的多格、旋转、分割、堆叠、交换和移除操作。
func _test_inheritance(t) -> void:
	var service := WarehouseService.new(t.lookup)
	t.expect(service is GridService and service is InventoryService, "仓库继承网格服务和抽象契约")
	t.code(service.organize(), InventoryResult.Code.RULE_REJECTED, "未初始化仓库不能整理")
	t.code(service.initialize("bad", Vector2i.ZERO), InventoryResult.Code.INVALID_POSITION, "继承非法尺寸校验")
	t.code(service.initialize("warehouse", Vector2i(4, 3)), InventoryResult.Code.OK, "初始化网格仓库")
	var square := ItemInstance.new(3)
	t.code(service.add(square, Vector2i(2, 1)), InventoryResult.Code.OK, "仓库添加方形多格物品")
	t.equal(service.query(Vector2i(3, 2)).payload.instance.instance_id, square.instance_id, "仓库非锚点查询定位原实例")
	t.code(service.add(ItemInstance.new(2, 6), Vector2i.ZERO), InventoryResult.Code.OK, "仓库多格栈添加")
	t.code(service.rotate(Vector2i.ZERO, true), InventoryResult.Code.OK, "仓库继承旋转规则")
	t.code(service.split(Vector2i.ZERO, Vector2i(1, 0), 2), InventoryResult.Code.OK, "仓库继承原子分割")
	t.equal(service.query(Vector2i(1, 1)).payload.instance.quantity, 2, "分割保留旋转后的完整占位")
	t.equal(service.stack(Vector2i(1, 0), Vector2i.ZERO).payload, 2, "仓库继承原子堆叠")
	t.code(service.move(Vector2i.ZERO, Vector2i(0, 1)), InventoryResult.Code.OK, "仓库移动多格物品")
	t.code(service.swap(Vector2i(0, 1), Vector2i(2, 1)), InventoryResult.Code.OK, "仓库交换不同形状")
	t.equal(service.remove(Vector2i(1, 2)).payload.instance_id, square.instance_id, "仓库从非锚点移除完整实例")
	t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "继承操作后矩阵与记录一致")

## 整理一次提交并保持内容、方向和输入隔离，再次整理应为无变化成功。
func _test_organize(t) -> void:
	var service := WarehouseService.new(t.lookup)
	service.initialize("organize", Vector2i(6, 4))
	var small := ItemInstance.new(1, 9)
	var large := ItemInstance.new(3)
	var rotated := ItemInstance.new(2, 4, true)
	var bar := ItemInstance.new(2, 2)
	service.add(small, Vector2i(5, 3))
	service.add(large, Vector2i(3, 0))
	service.add(rotated, Vector2i(0, 1))
	service.add(bar, Vector2i(2, 3))
	var before := service.stage_snapshot()
	var result := service.organize()
	t.code(result, InventoryResult.Code.OK, "整理散乱的多格仓库")
	t.expect(result.changed, "整理布局变化标记 changed")
	t.equal(service.container.revision, before.revision + 1, "整体整理仅递增一次版本")
	t.equal(_contents(service.stage_snapshot()), _contents(before), "整理保留全部 ID、配置、数量和方向，不合并实例")
	t.equal(service.query(Vector2i.ZERO).payload.instance.instance_id, large.instance_id, "面积最大的物品优先摆放")
	t.equal(service.container.items[rotated.instance_id].instance.rotated, true, "整理保留已有旋转方向")
	t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "整理最终矩阵合法")
	var packed: Dictionary = t.value(service.stage_snapshot())
	result = service.organize()
	t.code(result, InventoryResult.Code.OK, "再次整理成功")
	t.expect(not result.changed and result.affected_ids.is_empty(), "再次整理不产生变化或受影响 ID")
	t.equal(t.value(service.stage_snapshot()), packed, "整理顺序稳定且不重复递增版本")
	var empty := WarehouseService.new(t.lookup)
	empty.initialize("empty", Vector2i(2, 2))
	t.expect(not empty.organize().changed, "空仓库整理不改状态")
	t.equal(empty.container.revision, 0, "空仓库整理不递增版本")

## 面积相同时按主类型、配置 ID、实例 ID 排序，不依赖原位置和字典插入顺序。
func _test_order(t) -> void:
	var material := ItemConfig.new()
	material.ItemID = 50
	material.MainItemType = 2
	var weapon := ItemConfig.new()
	weapon.ItemID = 51
	weapon.MainItemType = 1
	var lookup := func(id: int) -> ItemConfig: return material if id == 50 else weapon
	var service := WarehouseService.new(lookup)
	service.initialize("order", Vector2i(4, 2))
	var first := ItemInstance.new(50)
	var second := ItemInstance.new(50)
	var last := ItemInstance.new(51)
	service.add(second, Vector2i(3, 1))
	service.add(last, Vector2i(2, 1))
	service.add(first, Vector2i(1, 1))
	t.code(service.organize(), InventoryResult.Code.OK, "执行稳定次序整理")
	t.equal(service.query(Vector2i.ZERO).payload.instance.instance_id, last.instance_id, "同面积优先按主类型排序")
	t.equal(service.query(Vector2i(1, 0)).payload.instance.instance_id, first.instance_id, "同配置较小实例 ID 在前")
	t.equal(service.query(Vector2i(2, 0)).payload.instance.instance_id, second.instance_id, "同配置实例不会因插入顺序反复移动")
	# 相同主类型时配置 ID 排序优先于实例 ID。
	material.MainItemType = 1
	t.code(service.organize(), InventoryResult.Code.OK, "同主类型时重新整理")
	t.equal(service.query(Vector2i.ZERO).payload.instance.config_id, 50, "同面积同类型按配置 ID 排序")

## 已有合法布局未必能被简单首适配算法重新装箱，必须保持全部原状态。
func _test_packing_failure(t) -> void:
	var service := WarehouseService.new(t.lookup)
	service.initialize("packing_failure", Vector2i(3, 3))
	service.add(ItemInstance.new(2, 2), Vector2i(0, 0))
	service.add(ItemInstance.new(2, 4), Vector2i(1, 2))
	service.add(ItemInstance.new(2, 3, true), Vector2i(2, 0))
	service.add(ItemInstance.new(2, 1, true), Vector2i(0, 1))
	var before: Dictionary = t.value(service.stage_snapshot())
	t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "装箱失败夹具的原布局合法")
	t.code(service.organize(), InventoryResult.Code.NO_SPACE, "无法完整重排时明确失败")
	t.equal(t.value(service.stage_snapshot()), before, "重排失败保留全部物品、方向、锚点和版本")

## 真正提交后返回故障必须恢复快照；旧版本冲突不覆盖外部递增的版本。
func _test_commit_failure(t) -> void:
	var service := FaultWarehouse.new(t.lookup)
	service.initialize("fault", Vector2i(4, 4))
	service.add(ItemInstance.new(2, 4), Vector2i(2, 3))
	var before: Dictionary = t.value(service.stage_snapshot())
	service.fail_after_commit = true
	t.code(service.organize(), InventoryResult.Code.INTERNAL_ERROR, "模拟整理写入后故障")
	t.equal(t.value(service.stage_snapshot()), before, "故障恢复原矩阵、实例和版本")
	service.fail_after_commit = false
	service.stale_on_commit = true
	t.code(service.organize(), InventoryResult.Code.STALE_STATE, "整理提交拒绝过期计划")
	before.revision += 1
	t.equal(t.value(service.stage_snapshot()), before, "版本冲突保留外部版本且不写入整理计划")
	service.stale_on_commit = false
	t.code(service.organize(), InventoryResult.Code.OK, "故障后可重新整理")

## Manager 工厂、通知时机与背包到仓库的转移、交换、堆叠、分割均沿用统一事务。
func _test_manager(t, m) -> void:
	t.code(m.configure(t.lookup), InventoryResult.Code.OK, "仓库测试注入配置")
	t.equal(m.ServiceType.EQUIPMENT_SLOT, 2, "新增仓库类型不改变已有装备类型值")
	t.code(m.create_container("bad_warehouse", Vector2i.ZERO, m.ServiceType.WAREHOUSE), InventoryResult.Code.INVALID_POSITION, "仓库工厂校验尺寸")
	t.expect(not m.has_container("bad_warehouse"), "失败创建不残留仓库")
	var slot := EquipmentSlotDefinition.new()
	slot.slot_id = &"head"
	slot.accepted_types.append(ENUM.EquipmentType.HELMET)
	var slots: Array[EquipmentSlotDefinition] = [slot]
	t.code(m.create_container("bad_rules", Vector2i.ONE, m.ServiceType.WAREHOUSE, slots), InventoryResult.Code.RULE_REJECTED, "仓库不接受装备槽配置")
	t.code(m.create_container("warehouse", Vector2i(6, 4), m.ServiceType.WAREHOUSE), InventoryResult.Code.OK, "Manager 工厂创建仓库")
	t.code(m.create_container("bag", Vector2i(4, 3), m.ServiceType.GRID), InventoryResult.Code.OK, "创建跨容器背包")
	t.code(m.organize_warehouse("absent"), InventoryResult.Code.CONTAINER_NOT_FOUND, "整理未知容器返回错误")
	t.code(m.organize_warehouse("bag"), InventoryResult.Code.UNSUPPORTED, "普通网格不支持仓库专用命令")
	var added: ItemInstance = m.add_to_container("bag", 2, 6, Vector2i.ZERO).payload
	t.code(m.switch_to_container("bag", "warehouse", Vector2i.ZERO, Vector2i(3, 1)), InventoryResult.Code.OK, "原子存入仓库")
	t.equal(m.get_item_at("warehouse", Vector2i(4, 1)).instance.instance_id, added.instance_id, "存入保留身份及多格占位")
	t.code(m.split_between_containers("warehouse", "bag", Vector2i(3, 1), Vector2i.ZERO, 2), InventoryResult.Code.OK, "跨仓库分割取出")
	t.equal(m.get_item_at("bag", Vector2i.ZERO).instance.quantity, 2, "分割取出数量正确")
	t.equal(m.stack_between_containers("bag", "warehouse", Vector2i.ZERO, Vector2i(3, 1)).payload, 2, "跨仓库堆叠存回")
	m.add_to_container("bag", 1, 1, Vector2i(1, 1))
	t.code(m.swap_between_containers("bag", "warehouse", Vector2i(1, 1), Vector2i(3, 1)), InventoryResult.Code.OK, "仓库和背包交换不同尺寸物品")
	var notices: Array = []
	var on_change := func(id, revision, ids): notices.append([id, revision, ids])
	m.container_changed.connect(on_change)
	var bag_before: Dictionary = t.value(m.get_snapshot("bag"))
	var revision: int = m.get_snapshot("warehouse").revision
	t.code(m.organize_warehouse("warehouse"), InventoryResult.Code.OK, "Manager 路由仓库整理")
	t.equal(m.get_snapshot("warehouse").revision, revision + 1, "整理经 Manager 仅提交一次")
	t.equal(notices.size(), 1, "整理成功只通知仓库一次")
	t.equal(notices[0][0], "warehouse", "整理通知不混入背包")
	t.equal(t.value(m.get_snapshot("bag")), bag_before, "仓库整理不修改背包")
	t.expect(not m.organize_warehouse("warehouse").changed, "Manager 重复整理无变化成功")
	t.equal(notices.size(), 1, "重复整理不发无意义通知")
	var warehouse_before: Dictionary = t.value(m.get_snapshot("warehouse"))
	t.code(m.switch_to_container("warehouse", "bag", Vector2i.ZERO, Vector2i(1, 1)), InventoryResult.Code.OCCUPIED, "取出到占用位置失败")
	t.equal(t.value(m.get_snapshot("warehouse")), warehouse_before, "失败取出不删除仓库物品")
	t.equal(t.value(m.get_snapshot("bag")), bag_before, "失败取出不修改背包")
	t.code(m.switch_to_container("warehouse", "bag", Vector2i.ZERO, Vector2i(0, 2)), InventoryResult.Code.OK, "空出位置后原子取出")
	m._transaction_lock = true
	t.code(m.organize_warehouse("warehouse"), InventoryResult.Code.RULE_REJECTED, "整理遵守统一事务锁")
	m._transaction_lock = false
	var fault := FaultWarehouse.new(t.lookup)
	fault.initialize("fault_warehouse", Vector2i(4, 3))
	fault.add(ItemInstance.new(2), Vector2i(2, 2))
	m.register_container("fault_warehouse", fault)
	var before: Dictionary = t.value(m.get_snapshot("fault_warehouse"))
	notices.clear()
	fault.fail_after_commit = true
	t.code(m.organize_warehouse("fault_warehouse"), InventoryResult.Code.INTERNAL_ERROR, "Manager 整理故障返回错误")
	t.equal(t.value(m.get_snapshot("fault_warehouse")), before, "Manager 整理故障恢复状态")
	t.equal(notices.size(), 0, "失败整理不发送成功通知")
	m.container_changed.disconnect(on_change)
	for id in ["warehouse", "bag", "fault_warehouse"]:
		m.unregister_container(id)
	var definition: InventoryDefinition = preload("res://Rescource/Data/Inventory/home_warehouse.tres")
	t.code(m.create_container(definition.container_id, definition.size, definition.service_type), InventoryResult.Code.OK, "通过独立仓库资源创建会话")
	t.equal(m.get_snapshot(definition.container_id).size, Vector2i(10, 12), "仓库容量来自资源配置")
	m.unregister_container(definition.container_id)

## 将可变实例转为值以比较整理前后内容，位置另行检查，不将锚点计入内容守恒。
func _contents(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in state.items:
		var item: ItemInstance = state.items[id].instance
		result[id] = [item.config_id, item.quantity, item.rotated]
	return result
