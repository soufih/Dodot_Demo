extends RefCounted
## 分割服务契约、实例身份、占位、数量守恒及跨容器原子性回归。

const FaultService = preload("res://tests/inventory/fault_service.gd")

## 通过抽象服务与 Manager 运行数量边界、跨类型放置和故障注入测试。
func run(t, manager) -> void:
	for grid in [false, true]:
		_test_service(t, grid)
		_test_rejections(t, grid)
	_test_manager(t, manager)
	_test_failures(t, manager)

## 穷举奇偶数量，验证原栈保留 ID、方向及占位，新栈独立分配 ID 并遵守占位规则。
func _test_service(t, grid: bool) -> void:
	for amount in range(2, 11):
		var service: InventoryService = t.service(grid, Vector2i(6, 3))
		var original := ItemInstance.new(2, amount, true)
		service.add(original, Vector2i.ZERO)
		var source_pos := Vector2i(0, 1) if grid else Vector2i.ZERO
		var before: Dictionary = t.value(service.stage_snapshot())
		var preview := service.can_split(source_pos)
		t.code(preview, InventoryResult.Code.OK, "合法数量可以对半分割")
		t.equal(preview.payload, amount / 2, "分割数量向下取整")
		t.expect(not preview.changed, "分割预览只读")
		t.equal(t.value(service.stage_snapshot()), before, "预览不改变真实状态")
		var staged := service.stage_snapshot()
		var detached := service.stage_split(staged, source_pos)
		t.code(detached, InventoryResult.Code.OK, "暂存分割")
		t.equal(staged.items[original.instance_id].instance.quantity, amount - amount / 2, "暂存扣除准确数量")
		t.expect(detached.payload.instance_id != original.instance_id, "暂存新栈分配独立 ID")
		t.equal(t.value(service.stage_snapshot()), before, "暂存不提前改变容器")
		var result := service.split(source_pos, Vector2i(3, 0))
		t.code(result, InventoryResult.Code.OK, "通过统一服务契约对半分割")
		var item: ItemInstance = result.payload
		t.expect(item.instance_id != original.instance_id, "新栈与原栈身份独立")
		t.equal(item.quantity, amount / 2, "新栈数量正确")
		t.equal(item.config_id, original.config_id, "分割保留配置")
		t.expect(item.rotated, "分割保留方向")
		t.equal(service.container.items[original.instance_id].instance.quantity, amount - amount / 2, "奇数多出的一个留在原栈")
		t.equal(service.container.revision, before.revision + 1, "同容器分割只提交一次")
		t.expect(result.affected_ids.has(original.instance_id) and result.affected_ids.has(item.instance_id), "分割影响源与新实例")
		for row in range(before.cells.size()):
			for column in range(before.cells[row].size()):
				if before.cells[row][column] == original.instance_id:
					t.equal(service.container.cells[row][column], original.instance_id, "原栈全部占位保持不变")
		t.equal(service.container.cells[1][3], item.instance_id if grid else null, "新栈按具体服务规则占位")
		t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "分割后矩阵与记录一致")
		item.quantity = 0
		t.equal(service.query(Vector2i(3, 0)).payload.instance.quantity, amount / 2, "结果实例与内部状态隔离")
		t.equal(original.quantity, amount, "输入原实例未被修改")
	var service: InventoryService = t.service(grid, Vector2i(6, 3))
	var source := ItemInstance.new(2, 9, true)
	var target := ItemInstance.new(2, 3)
	service.add(source, Vector2i.ZERO)
	service.add(target, Vector2i(3, 0))
	var result := service.split(Vector2i.ZERO, Vector2i(4, 0) if grid else Vector2i(3, 0))
	t.code(result, InventoryResult.Code.OK, "半栈完整合入同类目标")
	t.equal(result.payload.instance_id, target.instance_id, "分割合并保留目标身份")
	t.equal(result.payload.quantity, 7, "分割合并目标数量正确")
	t.expect(not result.payload.rotated, "分割合并保留目标方向")
	t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 5, "分割合并只扣一半")
	var before: Dictionary = t.value(service.stage_snapshot())
	result = service.split(Vector2i.ZERO, Vector2i.ZERO)
	t.code(result, InventoryResult.Code.OK, "分割后放回自身无变化")
	t.expect(not result.changed, "放回自身不提交")
	t.equal(t.value(service.stage_snapshot()), before, "放回自身保持完整状态")
	result = service.split(Vector2i.ZERO, Vector2i(2, 1), 1)
	t.code(result, InventoryResult.Code.OK, "支持显式分割数量")
	t.equal(result.payload.quantity, 1, "显式数量准确")

## 验证单件、空位置、非法数量、占用、边界和目标容量不足时完全不修改状态。
func _test_rejections(t, grid: bool) -> void:
	var service: InventoryService = t.service(grid, Vector2i(6, 3))
	service.add(ItemInstance.new(2, 9, true), Vector2i.ZERO)
	service.add(ItemInstance.new(2, 8), Vector2i(2, 0))
	service.add(ItemInstance.new(3), Vector2i(4, 0))
	if grid:
		service.add(ItemInstance.new(1), Vector2i(1, 1))
	var before: Dictionary = t.value(service.stage_snapshot())
	for quantity in [-1, 9, 10]:
		t.code(service.can_split(Vector2i.ZERO, quantity), InventoryResult.Code.RULE_REJECTED, "拒绝非法分割数量")
		t.code(service.split(Vector2i.ZERO, Vector2i(2, 1), quantity), InventoryResult.Code.RULE_REJECTED, "正式分割拒绝非法数量")
	for data in [[Vector2i(1, 2), InventoryResult.Code.ITEM_NOT_FOUND],
			[Vector2i(-1, 0), InventoryResult.Code.INVALID_POSITION],
			[Vector2i(6, 0), InventoryResult.Code.OUT_OF_BOUNDS]]:
		t.code(service.can_split(data[0]), data[1], "预览校验源坐标")
		t.code(service.split(data[0], Vector2i(2, 1)), data[1], "分割校验源坐标")
	t.code(service.split(Vector2i.ZERO, Vector2i(2, 0)), InventoryResult.Code.RULE_REJECTED, "目标必须完整接收一半而非部分合并")
	t.code(service.split(Vector2i.ZERO, Vector2i(4, 0)), InventoryResult.Code.RULE_REJECTED, "分割不能交换其他物品")
	t.code(service.split(Vector2i.ZERO, Vector2i(-1, 0)), InventoryResult.Code.INVALID_POSITION, "负目标坐标")
	t.code(service.split(Vector2i.ZERO, Vector2i(6, 0)), InventoryResult.Code.OUT_OF_BOUNDS, "目标超出边界")
	if grid:
		t.code(service.split(Vector2i.ZERO, Vector2i(1, 0)), InventoryResult.Code.OCCUPIED, "分割新矩形不能重叠原占位")
		t.code(service.split(Vector2i.ZERO, Vector2i(1, 2)), InventoryResult.Code.OUT_OF_BOUNDS, "旋转分割栈放不下时失败")
	t.equal(t.value(service.stage_snapshot()), before, "失败分割保留矩阵、数量及版本")
	var single: InventoryService = t.service(grid, Vector2i(3, 3))
	single.add(ItemInstance.new(1), Vector2i.ZERO)
	t.code(single.can_split(Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "单件不能对半分割")
	t.code(single.split(Vector2i.ZERO, Vector2i(1, 0)), InventoryResult.Code.RULE_REJECTED, "不能生成空栈")
	var empty: InventoryService = GridService.new(t.lookup) if grid else SlotService.new(t.lookup)
	t.code(empty.can_split(Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "未初始化预览拒绝")
	t.code(empty.split(Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.RULE_REJECTED, "未初始化分割拒绝")

## 覆盖四种服务组合，检查双边通知前全部提交、版本递增及实例唯一归属。
func _test_manager(t, m) -> void:
	t.code(m.can_split("missing", Vector2i.ZERO), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知容器预览")
	t.code(m.split_in_container("missing", Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知容器分割")
	t.code(m.split_between_containers("missing", "other", Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知跨容器分割")
	for a_type in [m.ServiceType.SLOT, m.ServiceType.GRID]:
		for b_type in [m.ServiceType.SLOT, m.ServiceType.GRID]:
			m.create_container("split_a", Vector2i(5, 3), a_type)
			m.create_container("split_b", Vector2i(5, 3), b_type)
			var original: ItemInstance
			original = m.add_to_container("split_a", 2, 9, Vector2i.ZERO, true).payload
			var changes: Array = []
			var observer := func(id, revision, ids):
				changes.append([id, revision, ids])
				t.equal(m.get_snapshot("split_a").items[original.instance_id].instance.quantity, 5, "首个通知时源已扣减一半")
				t.equal(m.get_snapshot("split_b").items.size(), 1, "首个通知时目标已有新栈")
			m.container_changed.connect(observer)
			var preview: InventoryResult = m.can_split("split_a", Vector2i.ZERO)
			t.equal(preview.payload, 4, "Manager 暴露分割预览")
			t.equal(changes.size(), 0, "只读预览无变更通知")
			var result: InventoryResult = m.split_between_containers("split_a", "split_b", Vector2i.ZERO, Vector2i.ZERO)
			t.code(result, InventoryResult.Code.OK, "任意容器组合原子分割")
			t.equal(changes.size(), 2, "跨容器双方各通知一次")
			t.equal(m.get_snapshot("split_a").revision, 2, "源版本递增一次")
			t.equal(m.get_snapshot("split_b").revision, 1, "目标版本递增一次")
			t.expect(result.payload.instance_id != original.instance_id, "跨容器分割分配新 ID")
			t.expect(not m.get_snapshot("split_a").items.has(result.payload.instance_id), "新实例只属于目标")
			t.equal(result.payload.quantity, 4, "跨容器数量正确")
			m.container_changed.disconnect(observer)
			result = m.split_between_containers("split_a", "split_a", Vector2i.ZERO, Vector2i(3, 0))
			t.code(result, InventoryResult.Code.OK, "相同容器 ID 路由本地分割")
			t.equal(result.payload.quantity, 2, "同容器路由再次对半")
			result = m.split_between_containers("split_a", "split_b", Vector2i.ZERO, Vector2i.ZERO)
			t.code(result, InventoryResult.Code.OK, "跨容器分割可合入目标已有栈")
			t.equal(result.payload.quantity, 5, "跨容器合并后数量守恒")
			m.unregister_container("split_a")
			m.unregister_container("split_b")

## 注入本地及双边提交后失败、版本冲突和重入，验证恢复完整状态且不通知成功。
func _test_failures(t, m) -> void:
	var a = FaultService.new(t.lookup)
	var b = FaultService.new(t.lookup)
	a.initialize("split_fault_a", Vector2i(5, 3))
	b.initialize("split_fault_b", Vector2i(5, 3))
	m.register_container("split_fault_a", a)
	m.register_container("split_fault_b", b)
	m.add_to_container("split_fault_a", 2, 9, Vector2i.ZERO, true)
	var changes: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	m.container_changed.connect(on_change)
	var before: Dictionary = t.value(a.stage_snapshot())
	a.fail_commit = true
	t.code(m.split_in_container("split_fault_a", Vector2i.ZERO, Vector2i(3, 0)), InventoryResult.Code.INTERNAL_ERROR, "本地分割提交后失败")
	t.equal(t.value(a.stage_snapshot()), before, "本地失败恢复完整状态")
	for merge_target in [false, true]:
		a.fail_commit = false
		b.fail_commit = false
		if merge_target:
			m.add_to_container("split_fault_b", 2, 2, Vector2i.ZERO)
		changes.clear()
		for fail_source in [true, false]:
			a.fail_commit = fail_source
			b.fail_commit = not fail_source
			var before_b: Dictionary = t.value(b.stage_snapshot())
			t.code(m.split_between_containers("split_fault_a", "split_fault_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.INTERNAL_ERROR, "跨容器分割提交后失败")
			t.equal(t.value(a.stage_snapshot()), before, "分割回滚恢复源数量、方向及占位")
			t.equal(t.value(b.stage_snapshot()), before_b, "分割回滚恢复目标完整状态")
			t.equal(changes.size(), 0, "失败分割不发送变更通知")
	a.fail_commit = false
	b.fail_commit = false
	a.stale_on_validate = true
	t.code(m.split_between_containers("split_fault_a", "split_fault_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.STALE_STATE, "拒绝过期分割事务")
	t.equal(a.query(Vector2i.ZERO).payload.instance.quantity, 9, "过期事务不扣减源数量")
	t.equal(b.query(Vector2i.ZERO).payload.instance.quantity, 2, "过期事务不增加目标数量")
	t.equal(changes.size(), 0, "过期事务无成功通知")
	a.validation_hook = func():
		t.code(m.split_in_container("split_fault_a", Vector2i.ZERO, Vector2i(3, 0)), InventoryResult.Code.RULE_REJECTED, "分割事务禁止重入")
	t.code(m.split_between_containers("split_fault_a", "split_fault_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.OK, "失败后可以重试分割")
	t.equal(changes.size(), 2, "重试成功双方通知一次")
	m.container_changed.disconnect(on_change)
	m.unregister_container("split_fault_a")
	m.unregister_container("split_fault_b")
