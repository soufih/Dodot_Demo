extends RefCounted
## 拖动方向与落地命令的原子提交测试，不在预览期间修改真实实例。

const FaultService = preload("res://tests/inventory/fault_service.gd")

## 通过抽象契约验证本地移动/交换/分割，再验证四种跨服务组合及故障回滚。
func run(t, manager) -> void:
	for grid in [false, true]:
		_test_local(t, grid)
	_test_cross(t, manager)
	_test_rollback(t, manager)

## 方向与位置同次提交；原位也可旋转，分割源方向不受新栈方向影响。
func _test_local(t, grid: bool) -> void:
	var service: InventoryService = t.service(grid, Vector2i(4, 3))
	var original := ItemInstance.new(2, 7)
	service.add(original, Vector2i.ZERO)
	var result := service.move(Vector2i.ZERO, Vector2i(2, 1), true)
	t.code(result, InventoryResult.Code.OK, "旋转并移动一次提交")
	t.equal(service.container.revision, 2, "旋转移动只增加一次版本")
	t.expect(service.query(Vector2i(2, 1)).payload.instance.rotated, "落地保存指定方向")
	t.equal(service.query(Vector2i(2, 1)).payload.instance.instance_id, original.instance_id, "旋转移动保留实例身份")
	t.expect(not original.rotated, "旋转移动不修改传入的原实例")
	t.code(service.move(Vector2i(2, 1), Vector2i(2, 1), false), InventoryResult.Code.OK, "原位移动可提交新方向")
	t.expect(not service.query(Vector2i(2, 1)).payload.instance.rotated, "原位旋转恢复横向")
	t.equal(service.container.revision, 3, "原位旋转只增加一次版本")
	t.code(service.swap(Vector2i(2, 1), Vector2i(2, 1), true), InventoryResult.Code.OK, "拖回自身可提交旋转")
	var other := ItemInstance.new(1, 2)
	service.add(other, Vector2i.ZERO)
	t.code(service.swap(Vector2i(2, 1), Vector2i.ZERO, false), InventoryResult.Code.OK, "旋转并交换")
	t.equal(service.query(Vector2i.ZERO).payload.instance.instance_id, original.instance_id, "旋转交换源到目标")
	t.expect(not service.query(Vector2i.ZERO).payload.instance.rotated, "旋转交换使用预览方向")
	t.equal(service.query(Vector2i(2, 1)).payload.instance.instance_id, other.instance_id, "交换对方回到源锚点")
	result = service.split(Vector2i.ZERO, Vector2i(3, 0), 3, true)
	t.code(result, InventoryResult.Code.OK, "按新方向放下分割栈")
	t.expect(result.payload.rotated, "分割新栈保存预览方向")
	t.equal(result.payload.quantity, 3, "分割旋转保留指定数量")
	t.expect(not service.query(Vector2i.ZERO).payload.instance.rotated, "分割只旋转新栈，原栈方向不变")
	t.equal(service.query(Vector2i.ZERO).payload.instance.quantity, 4, "旋转分割源数量正确")
	t.code(service.validate_plan(service.stage_snapshot()), InventoryResult.Code.OK, "旋转命令后记录与矩阵一致")
	if grid:
		var before: Dictionary = t.value(service.stage_snapshot())
		t.code(service.move(Vector2i.ZERO, Vector2i(3, 2), true), InventoryResult.Code.OUT_OF_BOUNDS, "新方向放不下时旋转移动失败")
		t.equal(t.value(service.stage_snapshot()), before, "失败旋转移动保持方向、数量、位置和版本")

## 跨类型转移、分割与交换使用拖动方向；每个容器每次只提交一次并通知一次。
func _test_cross(t, m) -> void:
	for a_type in [m.ServiceType.SLOT, m.ServiceType.GRID]:
		for b_type in [m.ServiceType.SLOT, m.ServiceType.GRID]:
			m.create_container("drag_a", Vector2i(4, 3), a_type)
			m.create_container("drag_b", Vector2i(4, 3), b_type)
			var original: ItemInstance
			original = m.add_to_container("drag_a", 2, 7, Vector2i.ZERO).payload
			var changes: Array = []
			var on_change := func(id, revision, ids): changes.append([id, revision, ids])
			m.container_changed.connect(on_change)
			t.code(m.switch_to_container("drag_a", "drag_b", Vector2i.ZERO, Vector2i(2, 1), true), InventoryResult.Code.OK, "跨类型按预览方向转移")
			t.expect(m.get_snapshot("drag_a").items.is_empty(), "旋转转移释放源占位")
			t.expect(m.get_item_at("drag_b", Vector2i(2, 1)).instance.rotated, "跨类型转移保存新方向")
			t.equal(changes.size(), 2, "旋转转移双边各通知一次")
			changes.clear()
			var result: InventoryResult = m.split_between_containers("drag_b", "drag_a", Vector2i(2, 1), Vector2i.ZERO, 3, false)
			t.code(result, InventoryResult.Code.OK, "跨类型按新方向分割")
			t.expect(not result.payload.rotated, "跨类型新栈使用新方向")
			t.expect(m.get_item_at("drag_b", Vector2i(2, 1)).instance.rotated, "跨类型分割源方向保持不变")
			t.equal(m.get_item_at("drag_b", Vector2i(2, 1)).instance.quantity, 4, "旋转分割数量守恒")
			t.equal(changes.size(), 2, "旋转分割双边各通知一次")
			changes.clear()
			t.code(m.swap_between_containers("drag_a", "drag_b", Vector2i.ZERO, Vector2i(2, 1), true), InventoryResult.Code.OK, "跨类型按新方向交换")
			t.expect(m.get_item_at("drag_b", Vector2i(2, 1)).instance.rotated, "跨类型交换拖动实例采用新方向")
			t.equal(m.get_item_at("drag_a", Vector2i.ZERO).instance.instance_id, original.instance_id, "跨类型交换保留对方原实例")
			t.expect(m.get_item_at("drag_a", Vector2i.ZERO).instance.rotated, "被交换实例保持原方向")
			t.equal(changes.size(), 2, "旋转交换双边各通知一次")
			t.equal(m.get_snapshot("drag_a").revision, 4, "连续旋转命令源版本正确")
			t.equal(m.get_snapshot("drag_b").revision, 3, "连续旋转命令目标版本正确")
			m.container_changed.disconnect(on_change)
			m.unregister_container("drag_a")
			m.unregister_container("drag_b")

## 注入提交后的真实失败，验证旋转不会先行留在原栈，双边提交失败恢复完整快照。
func _test_rollback(t, m) -> void:
	var a = FaultService.new(t.lookup)
	var b = FaultService.new(t.lookup)
	a.initialize("drag_fault_a", Vector2i(4, 3))
	b.initialize("drag_fault_b", Vector2i(4, 3))
	m.register_container("drag_fault_a", a)
	m.register_container("drag_fault_b", b)
	m.add_to_container("drag_fault_a", 2, 7, Vector2i.ZERO)
	m.add_to_container("drag_fault_a", 1, 1, Vector2i(3, 0))
	m.add_to_container("drag_fault_b", 1, 1, Vector2i.ZERO)
	var changes: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	m.container_changed.connect(on_change)
	for operation in ["move", "swap", "split"]:
		a.fail_commit = true
		var before: Dictionary = t.value(a.stage_snapshot())
		var result: InventoryResult
		match operation:
			"move": result = m.move_in_container("drag_fault_a", Vector2i.ZERO, Vector2i(2, 1), true)
			"swap": result = m.swap_in_container("drag_fault_a", Vector2i.ZERO, Vector2i(3, 0), true)
			"split": result = m.split_in_container("drag_fault_a", Vector2i.ZERO, Vector2i(2, 1), 3, true)
		t.code(result, InventoryResult.Code.INTERNAL_ERROR, "本地旋转提交失败 " + operation)
		t.equal(t.value(a.stage_snapshot()), before, "本地失败恢复原方向及全部状态")
	for fail_source in [false, true]:
		a.fail_commit = fail_source
		b.fail_commit = not fail_source
		for operation in ["move", "swap", "split"]:
			var before_a: Dictionary = t.value(a.stage_snapshot())
			var before_b: Dictionary = t.value(b.stage_snapshot())
			var result: InventoryResult
			match operation:
				"move": result = m.switch_to_container("drag_fault_a", "drag_fault_b", Vector2i.ZERO, Vector2i(2, 1), true)
				"swap": result = m.swap_between_containers("drag_fault_a", "drag_fault_b", Vector2i.ZERO, Vector2i.ZERO, true)
				"split": result = m.split_between_containers("drag_fault_a", "drag_fault_b", Vector2i.ZERO, Vector2i(2, 1), 3, true)
			t.code(result, InventoryResult.Code.INTERNAL_ERROR, "跨容器旋转提交失败 " + operation)
			t.equal(t.value(a.stage_snapshot()), before_a, "跨容器失败恢复源完整状态")
			t.equal(t.value(b.stage_snapshot()), before_b, "跨容器失败恢复目标完整状态")
	t.equal(changes.size(), 0, "所有回滚均不通知成功")
	m.container_changed.disconnect(on_change)
	m.unregister_container("drag_fault_a")
	m.unregister_container("drag_fault_b")
