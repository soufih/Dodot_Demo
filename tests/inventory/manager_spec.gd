extends RefCounted
## 统一入口、跨类型事务、通知时机及故障恢复的集成测试。

const FaultService = preload("res://tests/inventory/fault_service.gd")
var _changes: Array = []
var _errors: Array = []

## 连接变更/失败信号，运行注册、统一命令、跨容器事务、故障与重入测试，最后清理注册表。
## manager 为主测试入口，other 用于检查服务不能被多个 Manager 同时注册。
func run(t, manager, other) -> void:
	t.code(manager.configure(t.lookup), InventoryResult.Code.OK, "注入测试配置")
	t.code(other.configure(t.lookup), InventoryResult.Code.OK, "注入第二 Manager 配置")
	manager.container_changed.connect(func(id, revision, ids): _changes.append([id, revision, ids]))
	manager.operation_failed.connect(func(code, message): _errors.append([code, message]))
	_test_registration(t, manager, other)
	_test_commands(t, manager)
	_test_transfer(t, manager)
	_test_rollback(t, manager)
	_test_stale_and_lock(t, manager)
	for id in manager._containers.keys():
		manager.unregister_container(id)

## 验证注册身份、重复容器、初始化约束、服务绑定生命周期和未知容器错误反馈。
func _test_registration(t, m, other) -> void:
	t.code(m.create_container("", Vector2i.ONE, m.ServiceType.SLOT), InventoryResult.Code.RULE_REJECTED, "拒绝空注册键")
	t.code(m.create_container("bad_size", Vector2i(-1, 1), m.ServiceType.GRID), InventoryResult.Code.INVALID_POSITION, "注册尺寸非法")
	t.code(m.create_container("bad_type", Vector2i.ONE, 99), InventoryResult.Code.UNSUPPORTED, "拒绝未知类型")
	t.code(m.create_container("slot", Vector2i(4, 2), m.ServiceType.SLOT), InventoryResult.Code.OK, "创建普通背包")
	t.code(m.create_container("slot", Vector2i.ONE, m.ServiceType.SLOT), InventoryResult.Code.DUPLICATE_CONTAINER, "重复 ID")
	t.code(m.register_container("empty", SlotService.new(t.lookup)), InventoryResult.Code.RULE_REJECTED, "未初始化服务不可注册")
	var owned: InventoryService = t.service(false, Vector2i.ONE, "owned")
	t.code(m.register_container("alias", owned), InventoryResult.Code.RULE_REJECTED, "注册键必须匹配容器 ID")
	t.code(m.register_container("owned", owned), InventoryResult.Code.OK, "注册外部初始化的服务")
	t.code(other.register_container("owned", owned), InventoryResult.Code.DUPLICATE_CONTAINER, "服务不能被两个 Manager 绑定")
	t.code(m.unregister_container("owned"), InventoryResult.Code.OK, "注销释放绑定")
	t.code(other.register_container("owned", owned), InventoryResult.Code.OK, "注销后可重新注册")
	t.code(other.unregister_container("owned"), InventoryResult.Code.OK, "清理第二注册表")
	t.code(m.unregister_container("missing"), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知容器注销")
	t.code(m.configure(t.lookup), InventoryResult.Code.RULE_REJECTED, "有数据时配置来源固定")
	t.code(m.move_in_container("missing", Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.CONTAINER_NOT_FOUND, "操作未知容器")
	t.equal(m.get_item_at("missing", Vector2i.ZERO), {}, "未知容器查询为空")
	t.equal(m.get_snapshot("missing"), {}, "未知容器快照为空")

## 验证统一命令路由、实例唯一归属、查询隔离、只读预览及成功/失败通知规则。
func _test_commands(t, m) -> void:
	_changes.clear()
	_errors.clear()
	var added: InventoryResult = m.add_to_container("slot", 2, 8, Vector2i.ZERO)
	t.code(added, InventoryResult.Code.OK, "统一入口按配置创建物品")
	var stack: ItemInstance = added.payload
	t.equal(_changes.size(), 1, "一次成功只通知一次")
	t.equal(_changes[0], ["slot", 1, [stack.instance_id]], "通知带容器版本与受影响 ID")
	stack.quantity = 0
	t.equal(m.get_item_at("slot", Vector2i.ZERO).instance.quantity, 8, "返回的新实例副本隔离")
	t.code(m.move_in_container("slot", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.OK, "原地移动")
	t.equal(_changes.size(), 1, "无变化不通知")
	var before: Dictionary = t.value(m.get_snapshot("slot"))
	t.code(m.can_place("slot", m.get_item_at("slot", Vector2i.ZERO).instance, Vector2i(1, 0), true), InventoryResult.Code.OK, "按实例副本预览")
	t.equal(t.value(m.get_snapshot("slot")), before, "Manager 预览只读")
	var snapshot: Dictionary = m.get_snapshot("slot")
	snapshot.cells[0][0] = null
	snapshot.items[stack.instance_id].instance.quantity = 999
	var found: Dictionary = m.get_item_at("slot", Vector2i.ZERO)
	found.instance.rotated = true
	t.equal(t.value(m.get_snapshot("slot")), before, "Manager 查询与快照均隔离")
	t.code(m.add_to_container("slot", 1, 1, Vector2i.ZERO), InventoryResult.Code.OCCUPIED, "统一入口失败")
	t.equal(_changes.size(), 1, "失败不发变更通知")
	t.equal(_errors.size(), 1, "失败只发失败通知")
	var copy := ItemInstance.new(2, 8, false, stack.instance_id)
	t.code(m.create_container("grid", Vector2i(4, 3), m.ServiceType.GRID), InventoryResult.Code.OK, "创建网格背包")
	var duplicate: InventoryService = t.service(false, Vector2i.ONE, "duplicate")
	t.code(duplicate.add(copy, Vector2i.ZERO), InventoryResult.Code.OK, "重复 ID 注册夹具")
	t.code(m.register_container("duplicate", duplicate), InventoryResult.Code.INVALID_ITEM, "注册现有物品也检查唯一归属")

## 验证跨类型完整转移和交换，检查实例字段保持、非锚点定位及通知前双边已提交。
func _test_transfer(t, m) -> void:
	_changes.clear()
	var id: int = m.get_item_at("slot", Vector2i.ZERO).instance.instance_id
	# 监听第一个通知时，双方已经完成提交。
	var observer := func(container_id, _revision, _ids):
		if container_id == "slot":
			t.equal(m.get_snapshot("slot").items.size(), 0, "通知时源已移除")
			t.expect(m.get_snapshot("grid").items.has(id), "通知时目标已经完成提交")
	m.container_changed.connect(observer, CONNECT_ONE_SHOT)
	t.code(m.switch_to_container("slot", "grid", Vector2i.ZERO, Vector2i(1, 1)), InventoryResult.Code.OK, "普通到网格完整转移")
	t.equal(_changes.size(), 2, "跨容器各通知一次")
	t.equal(m.get_item_at("grid", Vector2i(2, 1)).instance.instance_id, id, "转移保持实例 ID")
	t.equal(m.get_item_at("grid", Vector2i(2, 1)).instance.quantity, 8, "转移保持数量")
	t.equal(m.get_snapshot("grid").revision, 1, "跨容器目标版本只加一")
	t.code(m.rotate_in_container("grid", Vector2i(2, 1), true), InventoryResult.Code.OK, "Manager 旋转")
	t.code(m.switch_to_container("grid", "slot", Vector2i(1, 2), Vector2i(2, 1)), InventoryResult.Code.OK, "网格到普通转移")
	t.expect(m.get_item_at("slot", Vector2i(2, 1)).instance.rotated, "跨类型转移保留方向")
	t.code(m.switch_to_container("slot", "grid", Vector2i(2, 1), Vector2i(3, 2)), InventoryResult.Code.OUT_OF_BOUNDS, "目标旋转尺寸越界")
	t.code(m.add_to_container("grid", 3, 1, Vector2i.ZERO), InventoryResult.Code.OK, "目标占用夹具")
	var before_a: Dictionary = t.value(m.get_snapshot("slot"))
	var before_b: Dictionary = t.value(m.get_snapshot("grid"))
	t.code(m.switch_to_container("slot", "grid", Vector2i(2, 1), Vector2i.ZERO), InventoryResult.Code.OCCUPIED, "目标占用不隐式交换")
	t.equal(t.value(m.get_snapshot("slot")), before_a, "失败转移源不变")
	t.equal(t.value(m.get_snapshot("grid")), before_b, "失败转移目标不变")
	t.code(m.swap_between_containers("slot", "grid", Vector2i(2, 1), Vector2i(1, 1)), InventoryResult.Code.OK, "跨类型交换，点击目标非锚点")
	t.equal(m.get_item_at("grid", Vector2i(0, 1)).instance.instance_id, id, "交换解析目标原锚点")
	t.code(m.switch_to_container("grid", "grid", Vector2i(0, 1), Vector2i(3, 0)), InventoryResult.Code.OK, "同 ID 转发本地移动")
	t.code(m.swap_between_containers("grid", "grid", Vector2i(3, 0), Vector2i(3, 0)), InventoryResult.Code.OK, "同实例交换无变化")
	var detached: InventoryResult = m.remove_from_container("grid", Vector2i(3, 1))
	t.code(detached, InventoryResult.Code.OK, "统一入口移除非锚点")
	t.equal(detached.payload.instance_id, id, "移除返回可接管实例")
	var recreated: InventoryResult = m.add_to_container("slot", detached.payload.config_id, detached.payload.quantity, Vector2i.ZERO, detached.payload.rotated)
	t.code(recreated, InventoryResult.Code.OK, "移除后可按配置创建新栈")
	t.expect(recreated.payload.instance_id != id, "新增接口始终生成新身份，已有身份转移由转移接口保持")

## 注入提交后失败，验证单容器和跨容器快照恢复、失败通知以及锁释放后的重试。
func _test_rollback(t, m) -> void:
	var a = FaultService.new(t.lookup)
	var b = FaultService.new(t.lookup)
	t.code(a.initialize("fault_a", Vector2i(4, 3)), InventoryResult.Code.OK, "故障源初始化")
	t.code(b.initialize("fault_b", Vector2i(4, 3)), InventoryResult.Code.OK, "故障目标初始化")
	t.code(m.register_container("fault_a", a), InventoryResult.Code.OK, "注册故障源")
	t.code(m.register_container("fault_b", b), InventoryResult.Code.OK, "注册故障目标")
	t.code(m.add_to_container("fault_a", 2, 7, Vector2i.ZERO, true), InventoryResult.Code.OK, "故障夹具 A")
	t.code(m.add_to_container("fault_b", 1, 3, Vector2i(2, 0)), InventoryResult.Code.OK, "故障夹具 B")
	# 单容器用例也需恢复写入后失败，而不是只处理跨容器失败。
	a.fail_commit = true
	for command in [&"add", &"move", &"rotate", &"remove", &"swap"]:
		var before: Dictionary = t.value(m.get_snapshot("fault_a"))
		_changes.clear()
		var local_result: InventoryResult
		match command:
			&"add":
				local_result = m.add_to_container("fault_a", 1, 1, Vector2i(3, 2))
			&"move":
				local_result = m.move_in_container("fault_a", Vector2i.ZERO, Vector2i(1, 0))
			&"rotate":
				local_result = m.rotate_in_container("fault_a", Vector2i.ZERO, false)
			&"remove":
				local_result = m.remove_from_container("fault_a", Vector2i.ZERO)
			&"swap":
				a.fail_commit = false
				m.add_to_container("fault_a", 1, 1, Vector2i(2, 0))
				a.fail_commit = true
				before = t.value(m.get_snapshot("fault_a"))
				_changes.clear()
				local_result = m.swap_in_container("fault_a", Vector2i.ZERO, Vector2i(2, 0))
		t.code(local_result, InventoryResult.Code.INTERNAL_ERROR, "单容器提交失败 " + command)
		t.equal(t.value(m.get_snapshot("fault_a")), before, "单容器失败恢复全部状态")
		t.equal(_changes.size(), 0, "单容器回滚不发变更通知")
	a.fail_commit = false
	for fail_source in [false, true]:
		a.fail_commit = fail_source
		b.fail_commit = not fail_source
		for exchange in [false, true]:
			var before_a: Dictionary = t.value(m.get_snapshot("fault_a"))
			var before_b: Dictionary = t.value(m.get_snapshot("fault_b"))
			_changes.clear()
			_errors.clear()
			var result: InventoryResult
			if exchange:
				result = m.swap_between_containers("fault_a", "fault_b", Vector2i(0, 1), Vector2i(2, 0))
			else:
				result = m.switch_to_container("fault_a", "fault_b", Vector2i.ZERO, Vector2i.ZERO)
			t.code(result, InventoryResult.Code.INTERNAL_ERROR, "提交后失败报告内部错误")
			t.equal(t.value(m.get_snapshot("fault_a")), before_a, "回滚恢复源数量、方向、矩阵、锚点和版本")
			t.equal(t.value(m.get_snapshot("fault_b")), before_b, "回滚恢复目标完整快照")
			t.equal(_changes.size(), 0, "回滚不发成功通知")
			t.equal(_errors.size(), 1, "回滚发一次失败通知")
	a.fail_commit = false
	b.fail_commit = false
	t.code(m.switch_to_container("fault_a", "fault_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.OK, "失败后锁已释放可重试")

## 注入版本冲突与事务内重入，验证过期计划被拒绝，参与者不能在提交期间被注销或替换。
func _test_stale_and_lock(t, m) -> void:
	var a = FaultService.new(t.lookup)
	var b = FaultService.new(t.lookup)
	a.initialize("stale_a", Vector2i(3, 3))
	b.initialize("stale_b", Vector2i(3, 3))
	m.register_container("stale_a", a)
	m.register_container("stale_b", b)
	m.add_to_container("stale_a", 1, 1, Vector2i.ZERO)
	a.stale_on_validate = true
	_changes.clear()
	t.code(m.switch_to_container("stale_a", "stale_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.STALE_STATE, "整体校验后复查双方版本")
	t.equal(a.container.items.size(), 1, "版本冲突不转移源物品")
	t.equal(b.container.items.size(), 0, "版本冲突不修改目标")
	t.equal(a.container.revision, 2, "版本冲突不覆盖外部新版本")
	t.equal(_changes.size(), 0, "版本冲突不通知变更")
	a.validation_hook = func():
		t.code(m.unregister_container("stale_b"), InventoryResult.Code.RULE_REJECTED, "事务期间禁止注销参与者")
		t.code(m.create_container("during", Vector2i.ONE, m.ServiceType.SLOT), InventoryResult.Code.RULE_REJECTED, "事务期间禁止注册")
		t.code(m.move_in_container("stale_a", Vector2i.ZERO, Vector2i.ONE), InventoryResult.Code.RULE_REJECTED, "事务期间禁止重入")
	t.code(m.switch_to_container("stale_a", "stale_b", Vector2i.ZERO, Vector2i.ZERO), InventoryResult.Code.OK, "拒绝重入后外层事务仍可成功")
