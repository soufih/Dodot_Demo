extends RefCounted
## 堆叠契约、数量守恒、跨服务事务与故障恢复测试。

const FaultService = preload("res://tests/inventory/fault_service.gd")

## 通过抽象服务和 Manager 入口运行堆叠测试，沿用独立配置与断言上下文。
func run(t, manager) -> void:
	for grid in [false, true]:
		_test_service(t, grid)
		_test_rejections(t, grid)
	_test_manager(t, manager)
	_test_faults(t, manager)
	_test_quantities(t)

## 验证多格非锚点、方向不同的合并、只读预览、部分余量以及源占位全部释放。
func _test_service(t, grid: bool) -> void:
	var service: InventoryService = t.service(grid, Vector2i(6, 3))
	var source := ItemInstance.new(2, 7, true)
	var target := ItemInstance.new(2, 8)
	t.code(service.add(source, Vector2i.ZERO), InventoryResult.Code.OK, "堆叠源栈")
	t.code(service.add(target, Vector2i(3, 0)), InventoryResult.Code.OK, "堆叠目标栈")
	var source_pos := Vector2i(0, 1) if grid else Vector2i.ZERO
	var target_pos := Vector2i(4, 0) if grid else Vector2i(3, 0)
	var before: Dictionary = t.value(service.stage_snapshot())
	var preview := service.can_stack(source, target_pos)
	t.code(preview, InventoryResult.Code.OK, "不同方向可以堆叠")
	t.equal(preview.payload, 2, "预览目标剩余容量")
	t.expect(not preview.changed, "堆叠预览不标记变化")
	t.equal(t.value(service.stage_snapshot()), before, "预览不改变任何状态")
	var staged := service.stage_snapshot()
	var stage_result := service.stage_stack(staged, source, target_pos)
	t.code(stage_result, InventoryResult.Code.OK, "目标暂存堆叠")
	t.equal(stage_result.payload, 2, "暂存返回实际接收数量")
	t.equal(staged.items[target.instance_id].instance.quantity, 10, "暂存目标达到上限")
	t.equal(source.quantity, 7, "暂存不扣减调用方实例")
	t.equal(t.value(service.stage_snapshot()), before, "暂存与真实容器隔离")
	var result := service.stack(source_pos, target_pos)
	t.code(result, InventoryResult.Code.OK, "非锚点部分堆叠")
	t.equal(result.payload, 2, "部分堆叠返回实际数量")
	t.expect(result.changed and result.affected_ids.has(source.instance_id) and result.affected_ids.has(target.instance_id), "堆叠结果包含双方实例")
	t.equal(service.container.revision, before.revision + 1, "本地堆叠版本只增加一次")
	t.equal(service.query(source_pos).payload.instance.quantity, 5, "余量保留源位置")
	t.expect(service.query(source_pos).payload.instance.rotated, "余量保留源方向")
	t.equal(service.query(target_pos).payload.instance.quantity, 10, "目标数量达到上限")
	t.expect(not service.query(target_pos).payload.instance.rotated, "目标保留原方向")
	t.equal(service.container.cells, before.cells, "部分堆叠不改变双方占位")
	var whole: InventoryService = t.service(grid, Vector2i(6, 3))
	whole.add(ItemInstance.new(2, 2, true, source.instance_id), Vector2i.ZERO)
	whole.add(ItemInstance.new(2, 3, false, target.instance_id), Vector2i(3, 0))
	result = whole.stack(source_pos, target_pos)
	t.code(result, InventoryResult.Code.OK, "完整合并")
	t.equal(result.payload, 2, "完整合并返回源全部数量")
	t.expect(not whole.container.items.has(source.instance_id), "完整合并移除源记录")
	for row in whole.container.cells:
		t.expect(not row.has(source.instance_id), "完整合并释放源全部占位")
	t.equal(whole.query(target_pos).payload.instance.instance_id, target.instance_id, "保留目标实例 ID")
	t.equal(whole.query(target_pos).payload.instance.quantity, 5, "合并后总数量正确")
	t.code(whole.validate_plan(whole.stage_snapshot()), InventoryResult.Code.OK, "合并后记录与矩阵一致")
	before = t.value(whole.stage_snapshot())
	result = whole.stack(target_pos, Vector2i(3, 0))
	t.code(result, InventoryResult.Code.OK, "同一实例堆叠视为无变化")
	t.equal(result.payload, 0, "同一实例不转移数量")
	t.expect(not result.changed, "同一实例不标记变化")
	t.equal(t.value(whole.stage_snapshot()), before, "同一实例不提交")

## 验证不兼容、满栈、不可堆叠、非法输入及空位置的拒绝行为和失败原子性。
func _test_rejections(t, grid: bool) -> void:
	var service: InventoryService = t.service(grid, Vector2i(6, 3))
	service.add(ItemInstance.new(2, 4), Vector2i.ZERO)
	service.add(ItemInstance.new(1, 10), Vector2i(3, 0))
	service.add(ItemInstance.new(3), Vector2i(4, 0))
	var before: Dictionary = t.value(service.stage_snapshot())
	for positions in [[Vector2i.ZERO, Vector2i(3, 0)], [Vector2i(3, 0), Vector2i.ZERO]]:
		t.code(service.stack(positions[0], positions[1]), InventoryResult.Code.RULE_REJECTED, "不同配置拒绝堆叠")
		t.equal(t.value(service.stage_snapshot()), before, "不兼容堆叠不改变状态")
	for incoming in [ItemInstance.new(1, 2), ItemInstance.new(3)]:
		var pos := Vector2i(3, 0) if incoming.config_id == 1 else Vector2i(4, 0)
		t.code(service.can_stack(incoming, pos), InventoryResult.Code.RULE_REJECTED, "满栈或不可堆叠物品拒绝预览")
		t.code(service.stage_stack(service.stage_snapshot(), incoming, pos), InventoryResult.Code.RULE_REJECTED, "满栈或不可堆叠物品拒绝暂存")
	for incoming in [null, ItemInstance.new(999), ItemInstance.new(2, 0), ItemInstance.new(2, 11)]:
		t.code(service.can_stack(incoming, Vector2i.ZERO), InventoryResult.Code.INVALID_ITEM, "堆叠拒绝非法源实例")
		t.code(service.stage_stack(service.stage_snapshot(), incoming, Vector2i.ZERO), InventoryResult.Code.INVALID_ITEM, "暂存拒绝非法源实例")
	var own: ItemInstance = service.query(Vector2i.ZERO).payload.instance
	t.code(service.can_stack(own, Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "预览拒绝向自身堆叠")
	for data in [[Vector2i(2, 2), InventoryResult.Code.ITEM_NOT_FOUND],
			[Vector2i(-1, 0), InventoryResult.Code.INVALID_POSITION],
			[Vector2i(6, 0), InventoryResult.Code.OUT_OF_BOUNDS]]:
		t.code(service.stack(Vector2i.ZERO, data[0]), data[1], "堆叠目标坐标校验")
		t.code(service.stack(data[0], Vector2i.ZERO), data[1], "堆叠源坐标校验")
		t.code(service.stage_stack(service.stage_snapshot(), own, data[0]), data[1], "暂存目标坐标校验")
	t.equal(t.value(service.stage_snapshot()), before, "所有拒绝操作保持完整状态")
	var uninitialized: InventoryService = GridService.new(t.lookup) if grid else SlotService.new(t.lookup)
	t.code(uninitialized.stack(Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.RULE_REJECTED, "未初始化堆叠")
	t.code(uninitialized.can_stack(own, Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "未初始化堆叠预览")

## 覆盖全部服务组合、同容器路由、双边通知时机、受影响 ID 及满栈失败不通知。
func _test_manager(t, m) -> void:
	t.code(m.configure(t.lookup), InventoryResult.Code.OK, "堆叠测试注入配置")
	t.code(m.stack_in_container("missing", Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.CONTAINER_NOT_FOUND, "本地堆叠未知容器")
	t.code(m.stack_between_containers("missing", "other", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.CONTAINER_NOT_FOUND, "跨容器堆叠未知容器")
	t.code(m.can_stack("missing", ItemInstance.new(1), Vector2i.ZERO), InventoryResult.Code.CONTAINER_NOT_FOUND, "预览未知容器")
	for a_type in [m.ServiceType.SLOT, m.ServiceType.GRID]:
		for b_type in [m.ServiceType.SLOT, m.ServiceType.GRID]:
			m.create_container("stack_a", Vector2i(4, 3), a_type)
			m.create_container("stack_b", Vector2i(4, 3), b_type)
			var source: ItemInstance
			var target: ItemInstance
			source = m.add_to_container("stack_a", 2, 7, Vector2i.ZERO, true).payload
			target = m.add_to_container("stack_b", 2, 8, Vector2i.ZERO).payload
			var changes: Array = []
			var observer := func(id, revision, ids):
				changes.append([id, revision, ids])
				t.equal(m.get_snapshot("stack_a").items[source.instance_id].instance.quantity, 5, "首个通知时源数量已提交")
				t.equal(m.get_snapshot("stack_b").items[target.instance_id].instance.quantity, 10, "首个通知时目标数量已提交")
			m.container_changed.connect(observer)
			var preview: InventoryResult = m.can_stack("stack_b", source, Vector2i.ZERO)
			t.equal(preview.payload, 2, "Manager 暴露堆叠预览")
			t.equal(changes.size(), 0, "堆叠预览不发变更通知")
			var a_pos := Vector2i(0, 1) if a_type == m.ServiceType.GRID else Vector2i.ZERO
			var b_pos := Vector2i(1, 0) if b_type == m.ServiceType.GRID else Vector2i.ZERO
			var result: InventoryResult = m.stack_between_containers("stack_a", "stack_b", a_pos, b_pos)
			t.code(result, InventoryResult.Code.OK, "任意服务组合跨容器堆叠")
			t.equal(result.payload, 2, "跨容器返回接收数量")
			t.equal(changes, [["stack_a", 2, [source.instance_id]], ["stack_b", 2, [target.instance_id]]], "跨容器各通知一次且只包含自身受影响 ID")
			t.expect(result.affected_ids.has(source.instance_id) and result.affected_ids.has(target.instance_id), "跨容器汇总双方受影响 ID")
			m.container_changed.disconnect(observer)
			var rejected_changes: Array = []
			var on_change := func(id, revision, ids): rejected_changes.append([id, revision, ids])
			m.container_changed.connect(on_change)
			var before_a: Dictionary = t.value(m.get_snapshot("stack_a"))
			var before_b: Dictionary = t.value(m.get_snapshot("stack_b"))
			t.code(m.stack_between_containers("stack_a", "stack_b", a_pos, b_pos), InventoryResult.Code.RULE_REJECTED, "目标已满拒绝正式堆叠")
			t.equal(t.value(m.get_snapshot("stack_a")), before_a, "满栈失败源不变")
			t.equal(t.value(m.get_snapshot("stack_b")), before_b, "满栈失败目标不变")
			t.equal(rejected_changes.size(), 0, "满栈失败不发变更通知")
			m.container_changed.disconnect(on_change)
			m.remove_from_container("stack_b", b_pos)
			m.add_to_container("stack_b", 2, 2, Vector2i.ZERO)
			result = m.stack_between_containers("stack_a", "stack_b", a_pos, b_pos)
			t.code(result, InventoryResult.Code.OK, "跨容器完整合并")
			t.equal(result.payload, 5, "跨容器完整合并数量")
			t.expect(m.get_snapshot("stack_a").items.is_empty(), "跨容器完整合并源清空")
			t.equal(m.get_item_at("stack_b", b_pos).instance.quantity, 7, "跨容器完整合并守恒")
			m.add_to_container("stack_b", 2, 2, Vector2i(3, 0), true)
			result = m.stack_between_containers("stack_b", "stack_b", Vector2i(3, 0), b_pos)
			t.code(result, InventoryResult.Code.OK, "同容器跨入口路由 Service.stack")
			t.equal(result.payload, 2, "同容器路由正确返回数量")
			m.unregister_container("stack_a")
			m.unregister_container("stack_b")

## 注入提交后失败、版本冲突与重入，验证本地/跨容器堆叠恢复数量、占位及版本。
func _test_faults(t, m) -> void:
	var a = FaultService.new(t.lookup)
	var b = FaultService.new(t.lookup)
	a.initialize("stack_fault_a", Vector2i(5, 3))
	b.initialize("stack_fault_b", Vector2i(5, 3))
	m.register_container("stack_fault_a", a)
	m.register_container("stack_fault_b", b)
	m.add_to_container("stack_fault_a", 2, 7, Vector2i.ZERO, true)
	m.add_to_container("stack_fault_a", 2, 8, Vector2i(2, 0))
	m.add_to_container("stack_fault_b", 2, 8, Vector2i.ZERO)
	var changes: Array = []
	var errors: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	var on_error := func(code, message): errors.append([code, message])
	m.container_changed.connect(on_change)
	m.operation_failed.connect(on_error)
	for amount in [8, 3]:
		a.fail_commit = false
		b.fail_commit = false
		m.remove_from_container("stack_fault_b", Vector2i.ZERO)
		m.add_to_container("stack_fault_b", 2, amount, Vector2i.ZERO)
		changes.clear()
		for fail_source in [true, false]:
			a.fail_commit = fail_source
			b.fail_commit = not fail_source
			var before_a: Dictionary = t.value(a.stage_snapshot())
			var before_b: Dictionary = t.value(b.stage_snapshot())
			t.code(m.stack_between_containers("stack_fault_a", "stack_fault_b", Vector2i(0, 1), Vector2i(1, 0)), InventoryResult.Code.INTERNAL_ERROR, "部分/完整跨容器堆叠提交后失败")
			t.equal(t.value(a.stage_snapshot()), before_a, "堆叠回滚恢复源全部字段和版本")
			t.equal(t.value(b.stage_snapshot()), before_b, "堆叠回滚恢复目标全部字段和版本")
			t.equal(changes.size(), 0, "堆叠回滚不通知成功")
	t.equal(errors.size(), 4, "每次跨容器失败报告一次")
	for amount in [8, 3]:
		a.fail_commit = false
		b.fail_commit = false
		m.remove_from_container("stack_fault_a", Vector2i(2, 0))
		m.add_to_container("stack_fault_a", 2, amount, Vector2i(2, 0))
		changes.clear()
		a.fail_commit = true
		var local_before: Dictionary = t.value(a.stage_snapshot())
		t.code(m.stack_in_container("stack_fault_a", Vector2i.ZERO, Vector2i(2, 0)), InventoryResult.Code.INTERNAL_ERROR, "部分/完整本地堆叠提交后失败")
		t.equal(t.value(a.stage_snapshot()), local_before, "本地堆叠回滚完整状态")
		t.equal(changes.size(), 0, "本地堆叠回滚不通知成功")
	var before: Dictionary = t.value(a.stage_snapshot())
	a.fail_commit = false
	a.stale_on_validate = true
	t.code(m.stack_between_containers("stack_fault_a", "stack_fault_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.STALE_STATE, "堆叠拒绝过期事务")
	var expected := before.duplicate(true)
	expected.revision += 1
	t.equal(t.value(a.stage_snapshot()), expected, "过期堆叠保留外部新版本与原数量")
	a.validation_hook = func():
		t.code(m.stack_in_container("stack_fault_a", Vector2i.ZERO, Vector2i(2, 0)), InventoryResult.Code.RULE_REJECTED, "堆叠事务拒绝重入")
		t.code(m.unregister_container("stack_fault_b"), InventoryResult.Code.RULE_REJECTED, "堆叠事务禁止注销")
	t.code(m.stack_between_containers("stack_fault_a", "stack_fault_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.OK, "失败后可重试并完成堆叠")
	t.equal(changes.size(), 2, "成功重试双边各通知一次")
	m.container_changed.disconnect(on_change)
	m.operation_failed.disconnect(on_error)
	m.unregister_container("stack_fault_a")
	m.unregister_container("stack_fault_b")

## 穷举两类服务的合法数量组合，检查容量边界、总数守恒及失败不改变版本。
func _test_quantities(t) -> void:
	for grid in [false, true]:
		for source_amount in range(1, 11):
			for target_amount in range(1, 11):
				var service: InventoryService = t.service(grid, Vector2i(2, 1))
				var source := ItemInstance.new(1, source_amount)
				var target := ItemInstance.new(1, target_amount)
				service.add(source, Vector2i.ZERO)
				service.add(target, Vector2i(1, 0))
				var before: Dictionary = t.value(service.stage_snapshot())
				var result := service.stack(Vector2i.ZERO, Vector2i(1, 0))
				if target_amount == 10:
					t.code(result, InventoryResult.Code.RULE_REJECTED, "穷举满栈拒绝")
					t.equal(t.value(service.stage_snapshot()), before, "穷举失败完整状态不变")
					continue
				var moved := mini(source_amount, 10 - target_amount)
				t.code(result, InventoryResult.Code.OK, "穷举合法堆叠")
				t.equal(result.payload, moved, "穷举合并数量")
				var remaining: int = service.container.items[source.instance_id].instance.quantity if service.container.items.has(source.instance_id) else 0
				var final_target: int = service.container.items[target.instance_id].instance.quantity
				t.equal(remaining, source_amount - moved, "穷举源余量")
				t.equal(final_target, target_amount + moved, "穷举目标数量")
				t.equal(remaining + final_target, source_amount + target_amount, "穷举数量守恒")
				t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "穷举最终占位一致")
