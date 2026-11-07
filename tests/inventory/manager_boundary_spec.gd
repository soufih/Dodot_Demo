extends RefCounted
## Manager 的新增值参数边界与实例预览契约回归。

## 验证新增身份、返回副本、实例参数预览、半栈独立占位及只读行为。
func run(t, m) -> void:
	m.create_container("boundary_grid", Vector2i(5, 4), m.ServiceType.GRID)
	m.create_container("boundary_slot", Vector2i(4, 2), m.ServiceType.SLOT)
	_test_creation(t, m)
	_test_preview(t, m)
	m.unregister_container("boundary_grid")
	m.unregister_container("boundary_slot")

## 同配置可生成多个独立栈，调用方无需构造实例，返回数据与真实状态隔离。
func _test_creation(t, m) -> void:
	var first: InventoryResult = m.add_to_container("boundary_grid", 2, 8, Vector2i.ZERO)
	var second: InventoryResult = m.add_to_container("boundary_grid", 2, 3, Vector2i(3, 2), true)
	t.code(first, InventoryResult.Code.OK, "Manager 按配置创建第一栈")
	t.code(second, InventoryResult.Code.OK, "Manager 按相同配置创建独立栈")
	t.expect(first.payload.instance_id != second.payload.instance_id, "相同配置与数量参数不复用实例身份")
	t.equal(first.payload.config_id, 2, "创建参数为配置 ID")
	t.equal(first.payload.quantity, 8, "创建数量由 Service 校验后保存")
	t.expect(second.payload.rotated, "创建时可指定初始方向")
	first.payload.quantity = 0
	second.payload.rotated = false
	t.equal(m.get_item_at("boundary_grid", Vector2i.ZERO).instance.quantity, 8, "新增返回实例为隔离副本")
	t.expect(m.get_item_at("boundary_grid", Vector2i(3, 2)).instance.rotated, "修改返回方向不影响内部实例")
	var result: InventoryResult = m.quick_add_to_container("boundary_slot", 2, 5, true)
	t.code(result, InventoryResult.Code.OK, "快速新增只需要配置、数量及首选方向")
	t.equal(result.payload, Vector2i.ZERO, "快速新增仍返回锚点")
	var stored: ItemInstance = m.get_item_at("boundary_slot", Vector2i.ZERO).instance
	t.equal(stored.quantity, 5, "快速新增保存数量")
	t.expect(stored.rotated, "普通栏位保留创建方向")
	result = m.quick_add_to_container("boundary_slot", 1)
	t.code(result, InventoryResult.Code.OK, "快速新增默认数量为一")
	t.equal(m.get_item_at("boundary_slot", result.payload).instance.quantity, 1, "默认数量正确")
	for data in [[999, 1], [1, 0], [1, -1], [1, 11]]:
		var before: Dictionary = t.value(m.get_snapshot("boundary_grid"))
		t.code(m.add_to_container("boundary_grid", data[0], data[1], Vector2i(4, 0)), InventoryResult.Code.INVALID_ITEM, "非法配置与数量由服务拒绝")
		t.equal(t.value(m.get_snapshot("boundary_grid")), before, "创建失败不改变背包")
	var before: Dictionary = t.value(m.get_snapshot("boundary_grid"))
	t.code(m.add_to_container("boundary_grid", 3, 1, Vector2i(3, 0), true), InventoryResult.Code.RULE_REJECTED, "创建方向仍遵守配置限制")
	t.equal(t.value(m.get_snapshot("boundary_grid")), before, "非法方向不改变状态")

## 预览直接使用传入实例：整栈保留原 ID，半栈使用独立临时 ID，真实状态不变。
func _test_preview(t, m) -> void:
	var source: ItemInstance = m.get_item_at("boundary_grid", Vector2i.ZERO).instance
	var half := ItemInstance.new(source.config_id, 4, source.rotated)
	var before_grid: Dictionary = t.value(m.get_snapshot("boundary_grid"))
	var before_slot: Dictionary = t.value(m.get_snapshot("boundary_slot"))
	var changes: Array = []
	var on_change := func(id, revision, ids): changes.append([id, revision, ids])
	m.container_changed.connect(on_change)
	var id_before := ItemInstance.new(1)
	t.code(m.can_place("boundary_grid", source, Vector2i(1, 0), false), InventoryResult.Code.OK, "实例参数预览整栈重叠移动")
	t.code(m.can_place("boundary_grid", half, Vector2i(1, 0), false), InventoryResult.Code.OCCUPIED, "独立半栈预览不能覆盖原栈占位")
	t.code(m.can_place("boundary_grid", half, Vector2i(0, 1), true), InventoryResult.Code.OK, "独立半栈可按预览方向放入空位")
	t.expect(not half.rotated, "放置预览不修改输入方向")
	var result: InventoryResult = m.can_stack("boundary_slot", source, Vector2i.ZERO)
	t.code(result, InventoryResult.Code.OK, "恢复实例参数堆叠预览")
	t.equal(result.payload, 5, "整栈预览使用传入数量与目标容量")
	half.quantity = 2
	result = m.can_stack("boundary_slot", half, Vector2i.ZERO)
	t.code(result, InventoryResult.Code.OK, "半栈预览使用独立实例数量")
	t.equal(result.payload, 2, "半栈可接收数量正确")
	t.code(m.can_stack("boundary_grid", source, Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "原实例身份仍可判断自身堆叠")
	t.code(m.can_place("boundary_grid", null, Vector2i.ZERO, false), InventoryResult.Code.INVALID_ITEM, "放置预览拒绝空实例")
	t.code(m.can_stack("boundary_slot", null, Vector2i.ZERO), InventoryResult.Code.INVALID_ITEM, "堆叠预览拒绝空实例")
	for quantity in [-1, 0, 11]:
		var invalid := source.copy()
		invalid.quantity = quantity
		t.code(m.can_place("boundary_grid", invalid, Vector2i(0, 1), false), InventoryResult.Code.INVALID_ITEM, "放置预览校验传入实例数量")
		t.code(m.can_stack("boundary_slot", invalid, Vector2i.ZERO), InventoryResult.Code.INVALID_ITEM, "堆叠预览校验传入实例数量")
	t.code(m.can_place("missing", source, Vector2i.ZERO, false), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知目标容器放置预览")
	t.code(m.can_stack("missing", source, Vector2i.ZERO), InventoryResult.Code.CONTAINER_NOT_FOUND, "未知目标容器堆叠预览")
	var id_after := ItemInstance.new(1)
	t.equal(id_after.instance_id, id_before.instance_id + 1, "预览接口本身不分配新实例 ID")
	t.equal(t.value(m.get_snapshot("boundary_grid")), before_grid, "全部预览不修改来源状态")
	t.equal(t.value(m.get_snapshot("boundary_slot")), before_slot, "全部预览不修改目标状态")
	t.equal(changes.size(), 0, "全部预览不发送内容变更通知")
	m.container_changed.disconnect(on_change)
	t.code(m.switch_to_container("boundary_grid", "boundary_slot", Vector2i.ZERO, Vector2i(2, 0)), InventoryResult.Code.OK, "已有实例转移保持身份")
	var moved: ItemInstance = m.get_item_at("boundary_slot", Vector2i(2, 0)).instance
	t.equal(moved.instance_id, source.instance_id, "转移不创建替代实例")
	t.code(m.can_place("boundary_grid", moved, Vector2i.ZERO, false), InventoryResult.Code.OK, "实例副本可跨容器预览")
