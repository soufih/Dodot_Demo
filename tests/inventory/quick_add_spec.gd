extends RefCounted
## 快速添加的首个适配位置、占位规则、统一入口及失败原子性测试。

const FaultService = preload("res://tests/inventory/fault_service.gd")

## 经抽象服务契约验证两类背包，再覆盖 Manager 路由、唯一归属与故障恢复。
func run(t, manager) -> void:
	_test_slot(t)
	_test_grid(t)
	_test_fill_existing(t)
	_test_stacking_remainder(t)
	_test_stacking_no_space(t)
	_test_stacking_rotation(t)
	_test_rotation_fallback(t)
	_test_no_fit(t)
	_test_invalid(t)
	_test_manager(t, manager)
	_test_commit_failures(t, manager)
	_test_rotation_failures(t, manager)
	_test_stacking_commit_failures(t, manager)

## 普通背包优先补堆，新堆按行选择空格，保留实际实例的 ID、数量与方向。
func _test_slot(t) -> void:
	var service: InventoryService = t.service(false, Vector2i(3, 2))
	var existing := ItemInstance.new(1, 2)
	service.add(existing, Vector2i.ZERO)
	service.add(ItemInstance.new(1), Vector2i(2, 0))
	var item := ItemInstance.new(2, 4, true)
	var result := service.quick_add(item)
	t.code(result, InventoryResult.Code.OK, "普通背包快速添加")
	t.equal(result.payload, Vector2i(1, 0), "先填第一行空格再找下一行")
	t.expect(result.changed, "快速添加标记变化")
	t.equal(result.affected_ids, [item.instance_id], "只影响新增实例")
	t.equal(service.container.revision, 3, "成功只增加一次版本")
	t.equal(service.query(Vector2i(1, 0)).payload.instance.instance_id, item.instance_id, "快速添加保留实例 ID")
	t.expect(service.query(Vector2i(1, 0)).payload.instance.rotated, "普通背包保留方向元数据")
	t.equal(service.container.cells[1], [null, null, null], "普通背包忽略配置占位尺寸")
	item.quantity = 0
	t.equal(service.query(Vector2i(1, 0)).payload.instance.quantity, 4, "快速添加复制输入实例")
	result = service.quick_add(ItemInstance.new(1, 4))
	t.code(result, InventoryResult.Code.OK, "同类已有物品优先堆叠")
	t.equal(result.payload, Vector2i.ZERO, "完全合并返回第一个接收物品的锚点")
	t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 6, "快速添加累计到已有物品堆")
	for x in range(3):
		service.add(ItemInstance.new(3), Vector2i(x, 1))
	var before: Dictionary = t.value(service.stage_snapshot())
	t.code(service.quick_add(ItemInstance.new(3)), InventoryResult.Code.NO_SPACE, "满背包且不能堆叠时返回无空间")
	t.equal(t.value(service.stage_snapshot()), before, "无空间保持完整状态")
	t.code(service.quick_add(existing), InventoryResult.Code.INVALID_ITEM, "满背包也准确报告重复实例")

## 网格首个空锚点未必适配：检查完整矩形，并按行优先跨越碰撞、零散空格和右边界。
func _test_grid(t) -> void:
	var service: InventoryService = t.service(true, Vector2i(5, 4))
	service.add(ItemInstance.new(1), Vector2i(1, 0))
	service.add(ItemInstance.new(1), Vector2i(4, 0))
	var square := ItemInstance.new(3)
	var result := service.quick_add(square)
	t.code(result, InventoryResult.Code.OK, "快速添加方形物品")
	t.equal(result.payload, Vector2i(2, 0), "跳过锚点空但完整矩形碰撞的位置")
	for pos in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)]:
		t.equal(service.query(pos).payload.instance.instance_id, square.instance_id, "方形完整占位一致")
	var vertical := ItemInstance.new(2, 7, true)
	result = service.quick_add(vertical)
	t.code(result, InventoryResult.Code.OK, "按当前旋转方向寻找位置")
	t.equal(result.payload, Vector2i.ZERO, "旋转后的纵向矩形适配最左上空位")
	t.equal(service.query(Vector2i(0, 1)).payload.instance.quantity, 7, "栈数量不改变占位")
	var horizontal := ItemInstance.new(4)
	result = service.quick_add(horizontal)
	t.code(result, InventoryResult.Code.OK, "跳过前两行零散空位")
	t.equal(result.payload, Vector2i(0, 2), "先上后下找到第一条完整横向区域")
	result = service.quick_add(ItemInstance.new(2, 3))
	t.code(result, InventoryResult.Code.OK, "多格物品优先合并到已有栈")
	t.equal(result.payload, Vector2i.ZERO, "空位之前先补已有同类物品堆")
	t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 10, "合并数量保持物品上限")
	result = service.quick_add(ItemInstance.new(2))
	t.code(result, InventoryResult.Code.OK, "同类堆已满后再寻找空位")
	t.equal(result.payload, Vector2i(3, 2), "新堆靠右边界恰好适配时优先填当前行")
	t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "快速添加后矩阵和记录一致")

## 普通背包、网格和仓库共享同一补堆语义，测试节点仍全部来自既有场景。
func _stacking_services(t, dimensions: Vector2i) -> Array[InventoryService]:
	var services: Array[InventoryService] = [SlotService.new(t.lookup), GridService.new(t.lookup), WarehouseService.new(t.lookup)]
	for service in services:
		service.initialize("stacking", dimensions)
	return services

## 满背包仍可补堆，按锚点而非字典插入顺序补满多个目标，保留目标身份和输入副本。
func _test_fill_existing(t) -> void:
	for service in _stacking_services(t, Vector2i(2, 1)):
		var later := ItemInstance.new(1, 8)
		var earlier := ItemInstance.new(1, 9)
		service.add(later, Vector2i(1, 0))
		service.add(earlier, Vector2i.ZERO)
		var item := ItemInstance.new(1, 3)
		var before := service.stage_snapshot()
		var result := service.quick_add(item)
		t.code(result, InventoryResult.Code.OK, "无空格但已有堆容量足够时快速添加成功")
		t.equal(result.payload, Vector2i.ZERO, "多个目标按场景锚点从左到右补堆")
		t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 10, "先补满左侧物品堆")
		t.equal(service.query(Vector2i(1, 0)).payload.instance.quantity, 10, "剩余数量继续补到下一堆")
		t.equal(service.container.cells, before.cells, "完全合并不改变物品占位和已有身份")
		t.expect(not service.container.items.has(item.instance_id), "完全合并不残留空的新实例")
		t.equal(item.quantity, 3, "补堆不扣减调用方传入的实例")
		t.equal(service.container.revision, before.revision + 1, "同时补多个堆也只提交一次版本")
		t.expect(result.affected_ids.size() == 2 and result.affected_ids.has(earlier.instance_id) and result.affected_ids.has(later.instance_id), "补堆结果包含所有变化目标而不包含已合并的新身份")
		before = service.stage_snapshot()
		t.code(service.quick_add(earlier), InventoryResult.Code.INVALID_ITEM, "已属于容器的实例不能再次快速添加或堆叠自身")
		t.equal(t.value(service.stage_snapshot()), t.value(before), "重复实例失败保持全部状态")

## 先补堆再放置余量；暂存规划不改真实状态，真实提交只更新一次且返回新堆锚点。
func _test_stacking_remainder(t) -> void:
	for service in _stacking_services(t, Vector2i(4, 2)):
		var target := ItemInstance.new(2, 8)
		service.add(target, Vector2i(2, 0))
		var item := ItemInstance.new(2, 5)
		var before := service.stage_snapshot()
		var staged := service.stage_snapshot()
		var planned: InventoryResult = service.call("stage_quick_add", staged, item)
		t.code(planned, InventoryResult.Code.OK, "暂存快速添加支持补堆和余量放置")
		t.equal(staged.items[target.instance_id].instance.quantity, 10, "暂存计划补满已有堆")
		t.equal(staged.items[item.instance_id].instance.quantity, 3, "暂存新堆只保存尚未接收的余量")
		t.equal(t.value(service.stage_snapshot()), t.value(before), "暂存规划不提交或修改真实容器")
		var result := service.quick_add(item)
		t.code(result, InventoryResult.Code.OK, "部分合并后余量可放入空位")
		t.equal(result.payload, Vector2i.ZERO, "存在余量新堆时返回其实际锚点")
		t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 3, "余量数量准确")
		t.equal(service.query(Vector2i.ZERO).payload.instance.instance_id, item.instance_id, "余量保留新实例身份")
		t.equal(service.query(Vector2i(2, 0)).payload.instance.quantity, 10, "已有堆身份、锚点和上限不变")
		t.equal(item.quantity, 5, "拆分接收不修改传入数量")
		t.equal(service.container.revision, before.revision + 1, "补堆和新增合为一次提交")
		t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "补堆后记录和占位矩阵一致")

## 多个目标有部分容量但仍接收不完整时，真实容器和调用方暂存计划均不能留下部分堆叠。
func _test_stacking_no_space(t) -> void:
	for service in _stacking_services(t, Vector2i(2, 1)):
		service.add(ItemInstance.new(1, 9), Vector2i.ZERO)
		service.add(ItemInstance.new(1, 8), Vector2i(1, 0))
		var item := ItemInstance.new(1, 4)
		var before := service.stage_snapshot()
		var staged := service.stage_snapshot()
		t.code(service.call("stage_quick_add", staged, item), InventoryResult.Code.NO_SPACE, "暂存补堆后余量没有空位时失败")
		t.equal(t.value(staged), t.value(before), "暂存失败不提前补满任何目标堆")
		t.code(service.quick_add(item), InventoryResult.Code.NO_SPACE, "真实快速添加必须完整接收请求数量")
		t.equal(t.value(service.stage_snapshot()), t.value(before), "无空间回滚所有计划中的补堆和占位")
		t.equal(item.quantity, 4, "失败不扣减调用方数量")

## 同类不同方向可合并，余量可以旋转适配；没有足够完整区域时连同补堆一起回滚。
func _test_stacking_rotation(t) -> void:
	for warehouse in [false, true]:
		var service: GridService = WarehouseService.new(t.lookup) if warehouse else GridService.new(t.lookup)
		service.initialize("rotation_stacking", Vector2i(1, 4))
		var target := ItemInstance.new(2, 8, true)
		service.add(target, Vector2i.ZERO)
		var item := ItemInstance.new(2, 5)
		var result := service.quick_add(item)
		t.code(result, InventoryResult.Code.OK, "补堆后的多格余量可自动旋转放入")
		t.equal(result.payload, Vector2i(0, 2), "旋转余量放入首个完整区域")
		t.expect(service.query(Vector2i.ZERO).payload.instance.rotated, "原目标堆保持原有方向")
		t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 10, "不同方向也可向同类物品堆补满")
		t.expect(service.query(Vector2i(0, 2)).payload.instance.rotated, "新余量保存实际放置方向")
		t.equal(service.query(Vector2i(0, 2)).payload.instance.quantity, 3, "自动旋转后余量数量不变")
		t.expect(not item.rotated and item.quantity == 5, "补堆与旋转均不修改调用方实例")
		service = WarehouseService.new(t.lookup) if warehouse else GridService.new(t.lookup)
		service.initialize("rotation_no_space", Vector2i(1, 3))
		service.add(ItemInstance.new(2, 8, true), Vector2i.ZERO)
		var before := service.stage_snapshot()
		t.code(service.quick_add(ItemInstance.new(2, 5)), InventoryResult.Code.NO_SPACE, "余量两种方向都放不下时失败")
		t.equal(t.value(service.stage_snapshot()), t.value(before), "多格无空间失败不会提前增加已有堆数量")
		service = WarehouseService.new(t.lookup) if warehouse else GridService.new(t.lookup)
		service.initialize("invalid_rotation", Vector2i.ONE)
		service.add(ItemInstance.new(1, 9), Vector2i.ZERO)
		t.code(service.quick_add(ItemInstance.new(1, 1, true)), InventoryResult.Code.RULE_REJECTED, "优先补堆也不能绕过禁止旋转的输入校验")

## 总空格数足够但没有连续矩形，或两个方向均过大时，无变化地报告无空间。
func _test_no_fit(t) -> void:
	var fragmented: InventoryService = t.service(true, Vector2i(3, 3))
	for pos in [Vector2i.ZERO, Vector2i.ONE, Vector2i(2, 2)]:
		fragmented.add(ItemInstance.new(1), pos)
	var before: Dictionary = t.value(fragmented.stage_snapshot())
	t.code(fragmented.quick_add(ItemInstance.new(3)), InventoryResult.Code.NO_SPACE, "零散空位不足以容纳完整矩形")
	t.equal(t.value(fragmented.stage_snapshot()), before, "查找失败不填入部分占位")
	var narrow: InventoryService = t.service(true, Vector2i(2, 2))
	var item := ItemInstance.new(4)
	before = t.value(narrow.stage_snapshot())
	t.code(narrow.quick_add(item), InventoryResult.Code.NO_SPACE, "两个方向均无法完整放入时失败")
	t.equal(t.value(narrow.stage_snapshot()), before, "尺寸不适配时状态不变")
	t.expect(not item.rotated, "查找不修改输入方向")
	item.rotated = true
	t.code(narrow.quick_add(item), InventoryResult.Code.NO_SPACE, "已旋转输入两个方向均不适配时失败")
	t.expect(item.rotated, "失败时保留调用方的已旋转标记")
	t.equal(t.value(narrow.stage_snapshot()), before, "两次扫描都失败时不提交")

## 验证两方向回退、当前方向优先于更早的旋转空位，以及配置禁止旋转的限制。
func _test_rotation_fallback(t) -> void:
	for initially_rotated in [false, true]:
		var size := Vector2i(1, 3) if not initially_rotated else Vector2i(3, 1)
		var service: InventoryService = t.service(true, size)
		var item := ItemInstance.new(4, 1, initially_rotated)
		var result := service.quick_add(item)
		t.code(result, InventoryResult.Code.OK, "原方向不适配时尝试另一方向")
		t.equal(result.payload, Vector2i.ZERO, "自动旋转后恰好填满容器")
		var stored: ItemInstance = service.query(Vector2i.ZERO).payload.instance
		t.equal(stored.rotated, not initially_rotated, "容器保存最终适配方向")
		t.equal(item.rotated, initially_rotated, "自动旋转不修改传入实例")
		t.equal(stored.instance_id, item.instance_id, "自动旋转保留实例 ID")
		t.equal(stored.quantity, item.quantity, "自动旋转保留栈数量")
		t.equal(service.container.revision, 1, "自动旋转仅提交一次")
		t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "自动旋转后矩阵与记录一致")
	var preferred: InventoryService = t.service(true, Vector2i(3, 2))
	preferred.add(ItemInstance.new(1), Vector2i(1, 0))
	var result := preferred.quick_add(ItemInstance.new(2, 6))
	t.code(result, InventoryResult.Code.OK, "当前方向存在合法位置")
	t.equal(result.payload, Vector2i(0, 1), "当前方向下一行位置优先于旋转后的左上空位")
	t.expect(not preferred.query(Vector2i(0, 1)).payload.instance.rotated, "当前方向可放下时不旋转")
	var obstructed: InventoryService = t.service(true, Vector2i(3, 3))
	for y in range(3):
		obstructed.add(ItemInstance.new(1), Vector2i(1, y))
	var item := ItemInstance.new(2, 7)
	result = obstructed.quick_add(item)
	t.code(result, InventoryResult.Code.OK, "碰撞导致原方向失败时也尝试旋转")
	t.equal(result.payload, Vector2i.ZERO, "旋转后仍按行选取首个适配位置")
	t.equal(obstructed.query(Vector2i(0, 1)).payload.instance.quantity, 7, "旋转保留多格栈数量及完整占位")
	t.expect(obstructed.query(Vector2i.ZERO).payload.instance.rotated, "碰撞回退保存正确方向")
	var fixed_config := ItemConfig.new()
	fixed_config.ItemID = 5
	fixed_config.GridSize = Vector2i(2, 1)
	fixed_config.CanRotate = false
	var lookup := func(id: int) -> ItemConfig: return fixed_config if id == 5 else t.lookup(id)
	var fixed_service := GridService.new(lookup)
	fixed_service.initialize("fixed", Vector2i(1, 2))
	var before: Dictionary = t.value(fixed_service.stage_snapshot())
	t.code(fixed_service.quick_add(ItemInstance.new(5)), InventoryResult.Code.NO_SPACE, "禁止旋转的长条即使另一方向适配也不能旋转")
	t.equal(t.value(fixed_service.stage_snapshot()), before, "禁止旋转时容器不变")

## 自动旋转后仍仅提交一次；提交失败或版本冲突不会通过再次旋转重试来掩盖错误。
func _test_rotation_failures(t, m) -> void:
	var service = FaultService.new(t.lookup)
	service.initialize("quick_rotation_fault", Vector2i(1, 3))
	m.register_container("quick_rotation_fault", service)
	var changes: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	m.container_changed.connect(on_change)
	var before: Dictionary = t.value(service.stage_snapshot())
	service.fail_commit = true
	t.code(m.quick_add_to_container("quick_rotation_fault", 4, 1), InventoryResult.Code.INTERNAL_ERROR, "自动旋转后提交失败保留错误")
	t.equal(t.value(service.stage_snapshot()), before, "自动旋转后提交失败恢复完整状态")
	t.equal(changes.size(), 0, "旋转回滚无成功通知")
	service.fail_commit = false
	service.stale_on_validate = true
	t.code(m.quick_add_to_container("quick_rotation_fault", 4, 1), InventoryResult.Code.STALE_STATE, "自动旋转后仍拒绝过期提交")
	var expected := before.duplicate(true)
	expected.revision += 1
	t.equal(t.value(service.stage_snapshot()), expected, "过期旋转计划保留外部版本")
	t.equal(changes.size(), 0, "过期旋转计划不通知成功")
	var result: InventoryResult = m.quick_add_to_container("quick_rotation_fault", 4, 1)
	t.code(result, InventoryResult.Code.OK, "旋转提交失败后可以正常重试")
	t.equal(result.payload, Vector2i.ZERO, "重试返回正确锚点")
	t.equal(changes.size(), 1, "旋转重试成功只发送一次通知")
	t.expect(service.query(Vector2i.ZERO).payload.instance.rotated, "Manager 入口保存自动旋转结果")
	t.equal(t.lookup(4).GridSize, Vector2i(3, 1), "自动旋转不修改共享物品配置")
	m.container_changed.disconnect(on_change)
	m.unregister_container("quick_rotation_fault")

## 实例与初始化错误保留原错误码，避免被无空间覆盖。
func _test_invalid(t) -> void:
	for grid in [false, true]:
		var service: InventoryService = t.service(grid, Vector2i(2, 2))
		var before: Dictionary = t.value(service.stage_snapshot())
		for item in [null, ItemInstance.new(999), ItemInstance.new(1, 0), ItemInstance.new(1, 11), ItemInstance.new(1, 1, false, -1)]:
			t.code(service.quick_add(item), InventoryResult.Code.INVALID_ITEM, "快速添加拒绝非法实例")
		t.equal(t.value(service.stage_snapshot()), before, "非法输入不改变状态")
		var uninitialized: InventoryService = GridService.new(t.lookup) if grid else SlotService.new(t.lookup)
		t.code(uninitialized.quick_add(ItemInstance.new(1)), InventoryResult.Code.RULE_REJECTED, "快速添加要求已初始化")
	var grid_service: InventoryService = t.service(true, Vector2i(3, 3))
	t.code(grid_service.quick_add(ItemInstance.new(3, 1, true)), InventoryResult.Code.RULE_REJECTED, "禁止旋转的配置保留规则错误")

## Manager 暴露无位置参数的入口，并保持唯一归属、一次通知和失败通知规则。
func _test_manager(t, m) -> void:
	var changes: Array = []
	var errors: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	var on_error := func(code, message): errors.append([code, message])
	m.container_changed.connect(on_change)
	m.operation_failed.connect(on_error)
	m.create_container("quick_slot", Vector2i.ONE, m.ServiceType.SLOT)
	m.create_container("quick_grid", Vector2i(3, 2), m.ServiceType.GRID)
	var result: InventoryResult = m.quick_add_to_container("quick_grid", 2, 6)
	t.code(result, InventoryResult.Code.OK, "Manager 统一快速添加入口")
	var item: ItemInstance = m.get_item_at("quick_grid", result.payload).instance
	t.equal(result.payload, Vector2i.ZERO, "统一入口返回实际锚点")
	t.equal(changes, [["quick_grid", 1, [item.instance_id]]], "快速添加只发送一次正确通知")
	var before: Dictionary = t.value(m.get_snapshot("quick_grid"))
	t.code(m.quick_add_to_container("quick_slot", 999, 1), InventoryResult.Code.INVALID_ITEM, "未知配置不能创建物品")
	t.expect(m.get_snapshot("quick_slot").items.is_empty(), "非法配置失败目标不变")
	t.equal(t.value(m.get_snapshot("quick_grid")), before, "失败不影响其他容器")
	t.code(m.quick_add_to_container("quick_slot", 3, 1), InventoryResult.Code.OK, "普通背包路由对应服务")
	t.code(m.quick_add_to_container("quick_slot", 1, 1), InventoryResult.Code.NO_SPACE, "统一入口报告无适配位置")
	t.code(m.quick_add_to_container("missing", 1, 1), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知容器快速添加")
	t.code(m.quick_add_to_container("quick_grid", 1, 0), InventoryResult.Code.INVALID_ITEM, "统一入口拒绝零数量")
	t.equal(changes.size(), 2, "所有失败都不发变更通知")
	t.equal(errors.size(), 4, "每次失败报告一次")
	m.container_changed.disconnect(on_change)
	m.operation_failed.disconnect(on_error)
	m.unregister_container("quick_slot")
	m.unregister_container("quick_grid")

## 首个适配位置仍须受控提交；提交后失败恢复快照，版本冲突和重入遵守统一事务约束。
func _test_commit_failures(t, m) -> void:
	var service = FaultService.new(t.lookup)
	service.initialize("quick_fault", Vector2i(3, 2))
	m.register_container("quick_fault", service)
	m.add_to_container("quick_fault", 1, 1, Vector2i.ZERO)
	var changes: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	m.container_changed.connect(on_change)
	var before: Dictionary = t.value(service.stage_snapshot())
	service.fail_commit = true
	t.code(m.quick_add_to_container("quick_fault", 2, 4), InventoryResult.Code.INTERNAL_ERROR, "快速添加提交后失败")
	t.equal(t.value(service.stage_snapshot()), before, "快速添加回滚恢复全部状态")
	t.equal(changes.size(), 0, "回滚不通知成功")
	service.fail_commit = false
	service.stale_on_validate = true
	t.code(m.quick_add_to_container("quick_fault", 2, 4), InventoryResult.Code.STALE_STATE, "快速添加提交复查版本")
	var expected := before.duplicate(true)
	expected.revision += 1
	t.equal(t.value(service.stage_snapshot()), expected, "过期提交保留外部版本且不写入物品")
	t.equal(changes.size(), 0, "过期提交无成功通知")
	service.validation_hook = func():
		t.code(m.quick_add_to_container("quick_fault", 1, 1), InventoryResult.Code.RULE_REJECTED, "快速添加事务禁止重入")
		t.code(m.unregister_container("quick_fault"), InventoryResult.Code.RULE_REJECTED, "快速添加事务禁止注销参与者")
	var result: InventoryResult = m.quick_add_to_container("quick_fault", 2, 4)
	t.code(result, InventoryResult.Code.OK, "失败后可以重试快速添加")
	t.equal(result.payload, Vector2i(1, 0), "重试仍选择第一个适配位置")
	t.equal(changes.size(), 1, "重试成功只通知一次")
	m.container_changed.disconnect(on_change)
	m.unregister_container("quick_fault")

## 同时补堆与新增余量时，真实写入后故障或版本冲突都恢复原数量，成功只发一次完整通知。
func _test_stacking_commit_failures(t, m) -> void:
	var service = FaultService.new(t.lookup)
	service.initialize("stacking_fault", Vector2i(4, 2))
	var target := ItemInstance.new(2, 8)
	service.add(target, Vector2i(2, 0))
	m.register_container("stacking_fault", service)
	var changes: Array = []
	var on_change := func(_id, _revision, ids): changes.append(ids)
	m.container_changed.connect(on_change)
	var before := service.stage_snapshot()
	service.fail_commit = true
	t.code(m.quick_add_to_container("stacking_fault", 2, 5), InventoryResult.Code.INTERNAL_ERROR, "补堆与新增写入后模拟提交失败")
	t.equal(t.value(service.stage_snapshot()), t.value(before), "提交故障同时恢复已有堆和新堆占位")
	t.equal(changes.size(), 0, "失败补堆不通知成功")
	service.fail_commit = false
	service.stale_on_validate = true
	t.code(m.quick_add_to_container("stacking_fault", 2, 5), InventoryResult.Code.STALE_STATE, "补堆计划仍检查原始版本")
	before.revision += 1
	t.equal(t.value(service.stage_snapshot()), t.value(before), "过期补堆计划保留外部版本而不写入数量")
	var result: InventoryResult = m.quick_add_to_container("stacking_fault", 2, 5)
	t.code(result, InventoryResult.Code.OK, "补堆故障后可正常重试")
	t.equal(result.payload, Vector2i.ZERO, "补堆后返回余量新堆的锚点")
	t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 3, "重试后新堆只保存余量")
	t.equal(service.query(Vector2i(2, 0)).payload.instance.quantity, 10, "重试后目标堆恰好填满")
	t.equal(changes.size(), 1, "同时补堆与新增只通知一次")
	t.expect(changes[0].size() == 2 and changes[0].has(target.instance_id) and changes[0].has(service.query(Vector2i.ZERO).payload.instance.instance_id), "成功通知包含所有数量变化的实例")
	m.container_changed.disconnect(on_change)
	m.unregister_container("stacking_fault")
