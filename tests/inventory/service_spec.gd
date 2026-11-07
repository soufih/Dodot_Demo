extends RefCounted
## 验证两类服务的业务行为、快照隔离和占位不变量。

## 运行抽象契约、普通背包、网格背包和非法输入测试，使用 t 累计断言。
func run(t) -> void:
	_test_abstract_contract(t)
	var invalid := SlotService.new(t.lookup)
	t.code(invalid.initialize("", Vector2i.ONE), InventoryResult.Code.RULE_REJECTED, "拒绝空 ID")
	t.code(invalid.initialize("bad", Vector2i(0, 1)), InventoryResult.Code.INVALID_POSITION, "拒绝零尺寸")
	t.expect(invalid.container == null, "初始化失败不绑定容器")
	t.code(invalid.query(Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "未初始化查询")
	var slot: InventoryService = t.service(false, Vector2i(3, 2))
	t.code(slot.initialize("again", Vector2i.ONE), InventoryResult.Code.RULE_REJECTED, "拒绝重复初始化")
	var large := ItemInstance.new(3)
	t.code(slot.add(large, Vector2i(1, 0)), InventoryResult.Code.OK, "普通背包忽略物品尺寸")
	t.equal(slot.container.cells[0], [null, large.instance_id, null], "普通背包单格占位")
	t.equal(slot.container.cells[1], [null, null, null], "矩阵行相互独立")
	t.code(slot.add(large, Vector2i(0, 1)), InventoryResult.Code.INVALID_ITEM, "拒绝本容器重复 ID")
	t.code(slot.add(ItemInstance.new(1), Vector2i(1, 0)), InventoryResult.Code.OCCUPIED, "普通背包不自动合并")
	t.code(slot.add(ItemInstance.new(1), Vector2i(-1, 0)), InventoryResult.Code.INVALID_POSITION, "负坐标")
	t.code(slot.add(ItemInstance.new(1), Vector2i(3, 0)), InventoryResult.Code.OUT_OF_BOUNDS, "超出右边界")
	t.code(slot.query(Vector2i(0, 1)), InventoryResult.Code.ITEM_NOT_FOUND, "空格查询")
	var snapshot: Dictionary = t.value(slot.stage_snapshot())
	t.code(slot.move(Vector2i(1, 0), Vector2i(1, 0)), InventoryResult.Code.OK, "原地移动成功")
	t.equal(t.value(slot.stage_snapshot()), snapshot, "原地移动不增加版本")
	t.code(slot.move(Vector2i(1, 0), Vector2i(2, 1)), InventoryResult.Code.OK, "普通背包二维移动")
	t.code(slot.add(ItemInstance.new(1, 4), Vector2i.ZERO), InventoryResult.Code.OK, "添加栈")
	t.code(slot.swap(Vector2i.ZERO, Vector2i(2, 1)), InventoryResult.Code.OK, "普通背包交换")
	t.equal(slot.query(Vector2i.ZERO).payload.instance.instance_id, large.instance_id, "交换更新索引")
	t.code(slot.move(Vector2i.ZERO, Vector2i(2, 1)), InventoryResult.Code.OCCUPIED, "移动不隐式交换")
	var removed := slot.remove(Vector2i.ZERO)
	t.code(removed, InventoryResult.Code.OK, "移除返回实例")
	t.equal(removed.payload.instance_id, large.instance_id, "移除保留实例 ID")
	t.code(slot.add(removed.payload, Vector2i(1, 1)), InventoryResult.Code.OK, "移除实例可重新添加")
	_test_grid(t)
	_test_validation(t)

## 检查原生抽象类标记，并以 InventoryService 类型调用两种服务，验证多态行为和各自占位规则。
func _test_abstract_contract(t) -> void:
	var contract: Script = preload("res://Script/Gameplay/Inventory/Services/InventoryService.gd")
	var slot_script: Script = preload("res://Script/Gameplay/Inventory/Services/SlotService.gd")
	var grid_script: Script = preload("res://Script/Gameplay/Inventory/Services/GridService.gd")
	t.expect(contract.is_abstract(), "统一服务契约为原生抽象类")
	t.expect(not slot_script.is_abstract(), "普通背包完整实现抽象契约")
	t.expect(not grid_script.is_abstract(), "网格背包完整实现抽象契约")
	# 调用方仅持有基类类型，两种实现按各自规则响应同一接口。
	var services: Array[InventoryService] = [SlotService.new(t.lookup), GridService.new(t.lookup)]
	for index in range(services.size()):
		var service: InventoryService = services[index]
		t.code(service.initialize("contract", Vector2i(3, 2)), InventoryResult.Code.OK, "经统一契约初始化")
		var item := ItemInstance.new(2, 5)
		t.code(service.validate_add(item, Vector2i.ZERO), InventoryResult.Code.OK, "经统一契约校验")
		t.code(service.add(item, Vector2i.ZERO), InventoryResult.Code.OK, "经统一契约添加")
		t.equal(service.stage_snapshot().cells[0][1], null if index == 0 else item.instance_id, "不同实现遵循各自占位规则")
		t.code(service.move(Vector2i.ZERO, Vector2i(1, 1)), InventoryResult.Code.OK, "经统一契约移动")
		t.code(service.remove(Vector2i(1, 1)), InventoryResult.Code.OK, "经统一契约移除")
		t.equal(service.stage_snapshot().items.size(), 0, "统一操作后容器为空")

## 验证多格占位、非锚点查询、重叠移动、旋转、快照隔离以及交换失败的原子性。
func _test_grid(t) -> void:
	var grid: InventoryService = t.service(true, Vector2i(5, 4))
	var item := ItemInstance.new(2, 9)
	t.code(grid.add(item, Vector2i.ZERO), InventoryResult.Code.OK, "网格添加多格栈")
	t.equal(grid.container.cells[0], [item.instance_id, item.instance_id, null, null, null], "数量不影响占位面积")
	t.equal(grid.query(Vector2i(1, 0)).payload.anchor, Vector2i.ZERO, "非锚点查询定位实例")
	t.code(grid.move(Vector2i(1, 0), Vector2i(1, 0)), InventoryResult.Code.OK, "相同点击坐标移动无变化")
	t.code(grid.move(Vector2i.ZERO, Vector2i(1, 0)), InventoryResult.Code.OK, "允许新旧矩形重叠移动")
	t.equal(grid.query(Vector2i(2, 0)).payload.anchor, Vector2i(1, 0), "重叠移动更新锚点")
	var before: Dictionary = t.value(grid.stage_snapshot())
	t.code(grid.move(Vector2i(2, 0), Vector2i(4, 0)), InventoryResult.Code.OUT_OF_BOUNDS, "多格右越界失败")
	t.equal(t.value(grid.stage_snapshot()), before, "失败移动完整状态不变")
	t.code(grid.can_place(item, Vector2i(1, 0), true), InventoryResult.Code.OK, "本地旋转预览忽略自身占位")
	t.equal(t.value(grid.stage_snapshot()), before, "预览不改状态或版本")
	t.code(grid.rotate(Vector2i(2, 0), true), InventoryResult.Code.OK, "从任意占位格旋转")
	t.equal(grid.query(Vector2i(1, 1)).payload.instance.rotated, true, "旋转后高为二")
	t.equal(item.rotated, false, "写入后外部原实例与内部隔离")
	var read := grid.query(Vector2i(1, 1))
	read.payload.instance.quantity = 0
	read.payload.instance.rotated = false
	t.equal(grid.query(Vector2i(1, 1)).payload.instance.quantity, 9, "查询实例副本隔离")
	var copy := grid.stage_snapshot()
	copy.cells[0][1] = null
	copy.items[item.instance_id].instance.quantity = 0
	t.code(grid.validate_plan(copy), InventoryResult.Code.INVALID_ITEM, "校验计划拒绝非法数量")
	t.equal(grid.query(Vector2i(1, 1)).payload.instance.quantity, 9, "快照实例深复制")
	var broken := grid.stage_snapshot()
	broken.cells[0][1] = null
	t.code(grid.commit(broken), InventoryResult.Code.INTERNAL_ERROR, "拒绝矩阵与记录不一致")
	var stale := grid.stage_snapshot()
	t.code(grid.add(ItemInstance.new(1), Vector2i(4, 3)), InventoryResult.Code.OK, "建立新版本")
	t.code(grid.commit(stale), InventoryResult.Code.STALE_STATE, "拒绝旧版本提交")
	t.code(grid.remove(Vector2i(1, 1)), InventoryResult.Code.OK, "从非锚点格移除所有占位")
	t.equal(grid.container.cells[0][1], null, "移除清空第一格")
	t.equal(grid.container.cells[1][1], null, "移除清空第二格")
	# 两个最终矩形可能彼此重叠，必须在完整最终状态上校验。
	var overlap: InventoryService = t.service(true, Vector2i(4, 2))
	t.code(overlap.add(ItemInstance.new(2), Vector2i.ZERO), InventoryResult.Code.OK, "交换夹具 A")
	t.code(overlap.add(ItemInstance.new(1), Vector2i(2, 0)), InventoryResult.Code.OK, "交换夹具 B")
	before = t.value(overlap.stage_snapshot())
	t.code(overlap.swap(Vector2i(1, 0), Vector2i(2, 0)), InventoryResult.Code.OK, "不同尺寸交换成功")
	t.equal(overlap.query(Vector2i(3, 0)).payload.anchor, Vector2i(2, 0), "交换使用锚点")
	var collide: InventoryService = t.service(true, Vector2i(4, 2))
	var wide := ItemInstance.new(4)
	t.code(collide.add(wide, Vector2i.ZERO), InventoryResult.Code.OK, "长物品夹具")
	t.code(collide.add(ItemInstance.new(1), Vector2i(3, 0)), InventoryResult.Code.OK, "边界物品夹具")
	before = t.value(collide.stage_snapshot())
	t.code(collide.swap(Vector2i.ZERO, Vector2i(3, 0)), InventoryResult.Code.OUT_OF_BOUNDS, "交换后放不下则失败")
	t.equal(t.value(collide.stage_snapshot()), before, "失败交换保持原状")
	var mutual: InventoryService = t.service(true, Vector2i(5, 4))
	t.code(mutual.add(ItemInstance.new(4), Vector2i.ZERO), InventoryResult.Code.OK, "相交夹具 A")
	t.code(mutual.add(ItemInstance.new(4, 1, true), Vector2i(0, 1)), InventoryResult.Code.OK, "相交夹具 B")
	before = t.value(mutual.stage_snapshot())
	t.code(mutual.swap(Vector2i.ZERO, Vector2i(0, 1)), InventoryResult.Code.OCCUPIED, "交换后双方矩形相交")
	t.equal(t.value(mutual.stage_snapshot()), before, "双方矩形相交不提交")

## 验证非法实例、配置和旋转限制，并确认校验期间版本变化不会被提交覆盖。
func _test_validation(t) -> void:
	var grid: InventoryService = t.service(true, Vector2i(3, 3))
	for item in [null, ItemInstance.new(999), ItemInstance.new(1, 0), ItemInstance.new(1, -1),
			ItemInstance.new(1, 11), ItemInstance.new(1, 1, false, -5)]:
		t.code(grid.add(item, Vector2i.ZERO), InventoryResult.Code.INVALID_ITEM, "拒绝非法实例")
	t.code(grid.add(ItemInstance.new(3, 1, true), Vector2i.ZERO), InventoryResult.Code.RULE_REJECTED, "禁止旋转的网格物品")
	var slot: InventoryService = t.service(false, Vector2i.ONE)
	t.code(slot.add(ItemInstance.new(3, 1, true), Vector2i.ZERO), InventoryResult.Code.OK, "普通背包忽略旋转标记")
	t.code(grid.rotate(Vector2i.ZERO, true), InventoryResult.Code.ITEM_NOT_FOUND, "空格不能旋转")
	var config := ItemConfig.new()
	t.expect(config.validate(), "旧物品默认配置有效")
	t.equal(config.GridSize, Vector2i.ONE, "旧资源默认单格")
	t.expect(not config.CanRotate, "旧资源默认不可旋转")
	config.MaxStack = 0
	t.expect(not config.validate(), "配置拒绝非正堆叠上限")
	config.MaxStack = 1
	config.GridSize = Vector2i(0, 1)
	t.expect(not config.validate(), "配置拒绝非法尺寸")
	# validate_plan 扩展在校验时改变版本，提交也不能覆盖这个新版本。
	var fault = preload("res://tests/inventory/fault_service.gd").new(t.lookup)
	fault.initialize("commit_stale", Vector2i.ONE)
	var plan: Dictionary = fault.stage_snapshot()
	fault.stage_add(plan, ItemInstance.new(1), Vector2i.ZERO)
	fault.stale_on_validate = true
	t.code(fault.commit(plan), InventoryResult.Code.STALE_STATE, "提交复查校验期间版本变化")
	t.equal(fault.container.items.size(), 0, "校验期间版本变化不写入物品")
	t.equal(fault.container.revision, 1, "保留校验期间的新版本")
