extends RefCounted
## 仓库继承行为、整理守恒、装箱失败、提交回滚与跨容器事务回归。

const FaultWarehouse = preload("res://tests/inventory/warehouse_fault_service.gd")

## 使用独立配置运行全部仓库断言，测试结束清理注册表以免影响其他套件。
func run(t, manager, warehouse_manager) -> void:
	_test_inheritance(t)
	_test_item_counts(t)
	_test_organize(t)
	_test_order(t)
	_test_packing_failure(t)
	_test_commit_failure(t)
	_test_manager(t, manager, warehouse_manager)
	_test_manager_counts(t, manager, warehouse_manager)

## 统计按实例数量汇总；不同方向和多格物品不重复计算，布局及堆栈变化只影响对应数量。
func _test_item_counts(t) -> void:
	var service := WarehouseService.new(t.lookup)
	t.code(service.get_item_counts(), InventoryResult.Code.RULE_REJECTED, "未初始化仓库拒绝汇总查询")
	t.code(service.get_item_count(2), InventoryResult.Code.RULE_REJECTED, "未初始化仓库拒绝指定物品统计")
	t.code(service.get_total_item_count(), InventoryResult.Code.RULE_REJECTED, "未初始化仓库拒绝总数统计")
	service.initialize("counts", Vector2i(8, 6))
	t.equal(service.get_item_counts().payload, {}, "空仓库的分类汇总为空")
	t.equal(service.get_item_count(2).payload, 0, "空仓库中指定物品数量为零")
	t.equal(service.get_total_item_count().payload, 0, "空仓库总数量为零")
	var first := ItemInstance.new(2, 4)
	var second := ItemInstance.new(2, 3, true)
	service.add(first, Vector2i.ZERO)
	service.add(second, Vector2i(3, 1))
	service.add(ItemInstance.new(1, 2), Vector2i(7, 5))
	service.add(ItemInstance.new(3), Vector2i(0, 3))
	var before: Dictionary = t.value(service.stage_snapshot())
	var counts := service.get_item_counts()
	t.code(counts, InventoryResult.Code.OK, "按配置 ID 汇总仓库物品")
	t.equal(counts.payload, {1: 2, 2: 7, 3: 1}, "同配置不同堆和方向合并数量，多格实例只计一次")
	t.equal(service.get_item_count(2).payload, 7, "指定物品统计各堆数量之和")
	t.equal(service.get_item_count(999).payload, 0, "未存放的配置数量为零")
	t.equal(service.get_total_item_count().payload, 10, "总数量按 quantity 累加，不等于堆数或占格数")
	t.expect(not counts.changed and counts.affected_ids.is_empty(), "统计结果不标记数据变化")
	counts.payload[2] = 999
	counts.payload[999] = 1
	t.equal(service.get_item_counts().payload, {1: 2, 2: 7, 3: 1}, "调用方修改汇总字典不污染后续统计")
	t.equal(t.value(service.stage_snapshot()), before, "统计及修改结果副本不影响物品、矩阵和版本")
	service.move(Vector2i(3, 1), Vector2i(6, 0))
	service.rotate(Vector2i.ZERO, true)
	t.equal(service.get_item_counts().payload, {1: 2, 2: 7, 3: 1}, "移动和旋转不改变数量汇总")
	t.code(service.organize(), InventoryResult.Code.OK, "统计夹具可以完整整理")
	t.equal(service.get_total_item_count().payload, 10, "整理后总数量保持不变")
	var origin: Vector2i = service.container.items[first.instance_id].anchor
	t.code(service.split(origin, Vector2i(7, 4), 2), InventoryResult.Code.OK, "将已有物品拆为两堆")
	t.equal(service.get_item_count(2).payload, 7, "拆分增加堆数但不增加物品数量")
	t.code(service.stack(Vector2i(7, 4), origin), InventoryResult.Code.OK, "将拆分出的物品合回原堆")
	t.equal(service.get_item_counts().payload, {1: 2, 2: 7, 3: 1}, "合并减少堆数但不改变分类统计")
	service.remove(service.container.items[second.instance_id].anchor)
	t.equal(service.get_item_count(2).payload, 4, "删除其中一堆后实时扣减对应数量")
	t.equal(service.get_total_item_count().payload, 7, "删除物品后实时更新总数量")
	service.remove(service.container.items[first.instance_id].anchor)
	t.equal(service.get_item_count(2).payload, 0, "删除该配置最后一堆后返回零")
	t.equal(service.get_item_counts().payload, {1: 2, 3: 1}, "汇总不保留已清空配置的缓存记录")

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
func _test_manager(t, m, warehouses) -> void:
	t.code(m.configure(t.lookup), InventoryResult.Code.OK, "仓库测试注入配置")
	t.expect(warehouses.inventory_manager == m, "独立仓库管理器使用对应的物品管理器")
	t.expect(not m.has_method("is_warehouse") and not m.has_method("organize_warehouse"), "仓库专属接口已从 InventoryManager 移除")
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
	t.expect(warehouses.is_warehouse("warehouse"), "仓库管理器识别统一注册表中的仓库")
	t.expect(not warehouses.is_warehouse("bag") and not warehouses.is_warehouse("absent"), "普通背包和未知 ID 不识别为仓库")
	t.expect(not WarehouseManager.is_warehouse("warehouse"), "独立管理器的仓库不泄漏到全局会话")
	t.code(warehouses.organize_warehouse("absent"), InventoryResult.Code.CONTAINER_NOT_FOUND, "整理未知容器返回错误")
	t.code(warehouses.organize_warehouse("bag"), InventoryResult.Code.UNSUPPORTED, "普通网格不支持仓库专用命令")
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
	t.code(warehouses.organize_warehouse("warehouse"), InventoryResult.Code.OK, "WarehouseManager 路由仓库整理")
	t.equal(m.get_snapshot("warehouse").revision, revision + 1, "整理经 Manager 仅提交一次")
	t.equal(notices.size(), 1, "整理成功只通知仓库一次")
	t.equal(notices[0][0], "warehouse", "整理通知不混入背包")
	t.equal(t.value(m.get_snapshot("bag")), bag_before, "仓库整理不修改背包")
	t.expect(not warehouses.organize_warehouse("warehouse").changed, "Manager 重复整理无变化成功")
	t.equal(notices.size(), 1, "重复整理不发无意义通知")
	var warehouse_before: Dictionary = t.value(m.get_snapshot("warehouse"))
	t.code(m.switch_to_container("warehouse", "bag", Vector2i.ZERO, Vector2i(1, 1)), InventoryResult.Code.OCCUPIED, "取出到占用位置失败")
	t.equal(t.value(m.get_snapshot("warehouse")), warehouse_before, "失败取出不删除仓库物品")
	t.equal(t.value(m.get_snapshot("bag")), bag_before, "失败取出不修改背包")
	t.code(m.switch_to_container("warehouse", "bag", Vector2i.ZERO, Vector2i(0, 2)), InventoryResult.Code.OK, "空出位置后原子取出")
	m._transaction_lock = true
	t.code(warehouses.organize_warehouse("warehouse"), InventoryResult.Code.RULE_REJECTED, "整理遵守统一事务锁")
	m._transaction_lock = false
	var nested: Array[InventoryResult] = []
	var operation := func(_service: InventoryService) -> InventoryResult:
		nested.append(warehouses.organize_warehouse("warehouse"))
		return InventoryResult.success()
	t.code(m.execute_container_operation("warehouse", preload("res://Script/Gameplay/Inventory/Services/WarehouseService.gd"), operation), InventoryResult.Code.OK, "通用业务操作入口可执行同步服务回调")
	t.code(nested[0], InventoryResult.Code.RULE_REJECTED, "回调执行期间仓库操作不能重入统一事务锁")
	t.expect(not m._transaction_lock, "业务回调完成后释放统一事务锁")
	var fault := FaultWarehouse.new(t.lookup)
	fault.initialize("fault_warehouse", Vector2i(4, 3))
	fault.add(ItemInstance.new(2), Vector2i(2, 2))
	m.register_container("fault_warehouse", fault)
	t.expect(warehouses.is_warehouse("fault_warehouse"), "仓库管理器识别手动注册的仓库服务子类")
	var before: Dictionary = t.value(m.get_snapshot("fault_warehouse"))
	var before_counts: Dictionary = warehouses.get_item_counts("fault_warehouse").payload
	notices.clear()
	fault.fail_after_commit = true
	t.code(warehouses.organize_warehouse("fault_warehouse"), InventoryResult.Code.INTERNAL_ERROR, "Manager 整理故障返回错误")
	t.equal(t.value(m.get_snapshot("fault_warehouse")), before, "Manager 整理故障恢复状态")
	t.equal(warehouses.get_item_counts("fault_warehouse").payload, before_counts, "整理提交失败恢复后数量统计保持不变")
	t.equal(notices.size(), 0, "失败整理不发送成功通知")
	m.container_changed.disconnect(on_change)
	for id in ["warehouse", "bag", "fault_warehouse"]:
		m.unregister_container(id)
	t.expect(not warehouses.is_warehouse("warehouse"), "注销容器后仓库识别立即失效，不保留第二份注册表")
	m.create_container("warehouse", Vector2i.ONE, m.ServiceType.GRID)
	t.expect(not warehouses.is_warehouse("warehouse"), "同名 ID 改为普通背包后不会沿用旧仓库身份")
	m.unregister_container("warehouse")
	var definition: InventoryDefinition = preload("res://Rescource/Data/Inventory/home_warehouse.tres")
	t.code(m.create_container(definition.container_id, definition.size, definition.service_type), InventoryResult.Code.OK, "通过独立仓库资源创建会话")
	t.equal(m.get_snapshot(definition.container_id).size, Vector2i(10, 12), "仓库容量来自资源配置")
	m.unregister_container(definition.container_id)

## 仓库管理器暴露只读统计，并跟随跨容器事务实时更新，错误和会话边界沿用统一管理器。
func _test_manager_counts(t, m, warehouses) -> void:
	m.configure(t.lookup)
	m.create_container("count_warehouse", Vector2i(8, 6), m.ServiceType.WAREHOUSE)
	m.create_container("other_count_warehouse", Vector2i(8, 6), m.ServiceType.WAREHOUSE)
	m.create_container("count_bag", Vector2i(8, 6), m.ServiceType.GRID)
	var errors: Array = []
	var notices: Array = []
	var on_error := func(code, _message): errors.append(code)
	var on_change := func(id, _revision, _ids): notices.append(id)
	m.operation_failed.connect(on_error)
	m.container_changed.connect(on_change)
	for result in [warehouses.get_item_counts("absent"), warehouses.get_item_count("absent", 2), warehouses.get_total_item_count("absent")]:
		t.code(result, InventoryResult.Code.CONTAINER_NOT_FOUND, "统计未知仓库明确返回失败")
	for result in [warehouses.get_item_counts("count_bag"), warehouses.get_item_count("count_bag", 2), warehouses.get_total_item_count("count_bag")]:
		t.code(result, InventoryResult.Code.UNSUPPORTED, "统计接口拒绝普通背包")
	t.equal(errors.size(), 6, "每次失败统计通过统一管理器报告一次错误")
	errors.clear()
	m.add_to_container("count_warehouse", 2, 6, Vector2i(3, 2))
	m.add_to_container("count_warehouse", 2, 3, Vector2i.ZERO)
	m.add_to_container("count_warehouse", 3, 1, Vector2i(5, 4))
	m.add_to_container("other_count_warehouse", 1, 9, Vector2i.ZERO)
	var before: Dictionary = t.value(m.get_snapshot("count_warehouse"))
	notices.clear()
	var counts: InventoryResult = warehouses.get_item_counts("count_warehouse")
	t.code(counts, InventoryResult.Code.OK, "仓库管理器返回分类统计")
	t.equal(counts.payload, {2: 9, 3: 1}, "汇总只计算指定仓库，不混入其他仓库或背包")
	t.equal(warehouses.get_total_item_count("count_warehouse").payload, 10, "管理器暴露仓库总数量")
	t.equal(warehouses.get_item_count("count_warehouse", 2).payload, 9, "管理器暴露指定配置数量")
	t.equal(warehouses.get_item_count("count_warehouse", 999).payload, 0, "未存放该配置属于成功的零数量查询")
	t.expect(not counts.changed and counts.affected_ids.is_empty(), "管理器统计不标记内容变化")
	counts.payload.clear()
	t.equal(warehouses.get_item_counts("count_warehouse").payload, {2: 9, 3: 1}, "管理器返回的统计字典与仓库状态隔离")
	m._transaction_lock = true
	var total: InventoryResult = warehouses.get_total_item_count("count_warehouse")
	t.code(total, InventoryResult.Code.OK, "只读统计沿用只读查询规则，不获取写事务锁")
	t.equal(total.payload, 10, "写锁期间查询当前容器数量")
	t.expect(m._transaction_lock, "只读统计不会改变已有的事务锁状态")
	m._transaction_lock = false
	t.equal(t.value(m.get_snapshot("count_warehouse")), before, "管理器统计不修改快照或递增版本")
	t.equal(notices.size(), 0, "成功统计不发出容器变更通知")
	t.equal(errors.size(), 0, "成功或数量为零的统计不报告错误")
	t.code(m.switch_to_container("count_warehouse", "count_bag", Vector2i(3, 2), Vector2i.ZERO), InventoryResult.Code.OK, "取出一整堆用于检查数量更新")
	t.equal(warehouses.get_item_count("count_warehouse", 2).payload, 3, "取出后指定配置数量实时更新")
	t.equal(warehouses.get_total_item_count("count_warehouse").payload, 4, "取出后仓库总数量实时更新")
	t.code(m.split_between_containers("count_warehouse", "count_bag", Vector2i.ZERO, Vector2i(2, 0), 1), InventoryResult.Code.OK, "拆分取出部分仓库物品")
	t.equal(warehouses.get_item_count("count_warehouse", 2).payload, 2, "跨容器分割只扣减实际取出数量")
	t.code(m.stack_between_containers("count_bag", "count_warehouse", Vector2i(2, 0), Vector2i.ZERO), InventoryResult.Code.OK, "将取出部分堆叠存回仓库")
	t.equal(warehouses.get_item_count("count_warehouse", 2).payload, 3, "堆叠存回后正确累计数量")
	t.code(m.swap_between_containers("count_warehouse", "count_bag", Vector2i(5, 4), Vector2i.ZERO), InventoryResult.Code.OK, "交换两种物品以检查分类统计")
	t.equal(warehouses.get_item_counts("count_warehouse").payload, {2: 9}, "交换后扣除离库物品并累加入库物品")
	warehouses.organize_warehouse("count_warehouse")
	t.equal(warehouses.get_total_item_count("count_warehouse").payload, 9, "通过管理器整理后总数量保持不变")
	notices.clear()
	t.code(m.switch_to_container("count_warehouse", "count_bag", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.OCCUPIED, "取出到占用位置失败")
	t.equal(warehouses.get_item_counts("count_warehouse").payload, {2: 9}, "失败事务不会提前扣减统计数量")
	t.equal(notices.size(), 0, "失败存取后的统计也不产生变更通知")
	m.unregister_container("count_warehouse")
	t.code(warehouses.get_total_item_count("count_warehouse"), InventoryResult.Code.CONTAINER_NOT_FOUND, "注销后统计返回容器不存在，不残留旧数量")
	t.equal(warehouses.get_total_item_count("other_count_warehouse").payload, 9, "其他仓库数量不受注销影响")
	m.container_changed.disconnect(on_change)
	m.operation_failed.disconnect(on_error)
	m.unregister_container("other_count_warehouse")
	m.unregister_container("count_bag")

## 将可变实例转为值以比较整理前后内容，位置另行检查，不将锚点计入内容守恒。
func _contents(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in state.items:
		var item: ItemInstance = state.items[id].instance
		result[id] = [item.config_id, item.quantity, item.rotated]
	return result
