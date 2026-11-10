extends Node

const FaultWarehouse = preload("res://tests/inventory/warehouse_fault_service.gd")
var t = preload("res://tests/inventory/spec_context.gd").new()
@onready var m = $Manager
@onready var crafting = $Crafting

func _ready() -> void:
	m.configure(t.lookup)
	_test_catalog()
	_test_routing_and_isolation()
	_test_stacks_and_preview()
	_test_capacity_and_rotation()
	_test_batch_and_outputs()
	_test_faults()
	print("CRAFTING_TEST_RESULT assertions=%d failures=%d" % [t.assertions, t.failures])
	get_tree().quit(0 if t.failures == 0 else 1)

func _recipe(inputs: Dictionary[int, int], outputs: Dictionary[int, int], id: StringName = &"test") -> CraftingRecipe:
	var recipe := CraftingRecipe.new()
	recipe.recipe_id = id
	recipe.inputs = inputs
	recipe.outputs = outputs
	return recipe

func _setup(recipe: CraftingRecipe, size: Vector2i = Vector2i(6, 5)) -> void:
	for id in m.get_container_ids():
		m.unregister_container(id)
	var catalog := CraftingCatalog.new()
	catalog.recipes.append(recipe)
	t.code(crafting.configure(catalog, t.lookup), InventoryResult.Code.OK, "配置测试配方")
	t.code(m.create_container("warehouse", size, m.ServiceType.WAREHOUSE), InventoryResult.Code.OK, "创建测试仓库")

func _state(id: String = "warehouse") -> Dictionary:
	return t.value(m.get_snapshot(id))

func _count(config_id: int, id: String = "warehouse") -> int:
	var total := 0
	for record: Dictionary in m.get_snapshot(id).items.values():
		if record.instance.config_id == config_id:
			total += record.instance.quantity
	return total

func _test_catalog() -> void:
	var real: CraftingCatalog = load("res://Rescource/Data/Crafting/catalog.tres")
	t.code(real.validate(ResourceManager.get_item_config), InventoryResult.Code.OK, "真实目录配置有效")
	t.equal(real.recipes.size(), 5, "完整迁移五份配方")
	t.equal(ResourceManager.get_item_recipe(10), {21: 1, 22: 2, 23: 4}, "兼容查询保留旧配方")
	t.equal(ResourceManager.get_item_products(20), [21], "反向关系由真实配方生成")
	var catalog := CraftingCatalog.new()
	var first := _recipe({1: 1}, {2: 1})
	catalog.recipes.append(first)
	t.code(crafting.configure(catalog, t.lookup), InventoryResult.Code.OK, "装入有效目录")
	var variant := _recipe({1: 2}, {2: 1}, &"alternate")
	catalog.recipes.append(variant)
	t.code(crafting.configure(catalog, t.lookup), InventoryResult.Code.OK, "同产物支持不同配方")
	t.equal(crafting.list_recipes().size(), 2, "按配方而非产物保存")
	first.inputs[1] = 9
	var copies: Array[CraftingRecipe] = crafting.list_recipes()
	t.equal(copies[0].inputs[1], 1, "配置后修改原资源不污染目录")
	copies[0].inputs[1] = 8
	t.equal(crafting.list_recipes()[0].inputs[1], 1, "列表返回独立配方副本")
	catalog.recipes.append(first)
	t.code(crafting.configure(catalog, t.lookup), InventoryResult.Code.INVALID_RECIPE, "重复标识拒绝整份目录")
	t.equal(crafting.list_recipes().size(), 2, "加载失败保留原目录")
	for recipe in [_recipe({}, {1: 1}), _recipe({1: 0}, {2: 1}), _recipe({9999: 1}, {1: 1}), _recipe({1: 1}, {})]:
		t.code(recipe.validate(t.lookup), InventoryResult.Code.INVALID_RECIPE, "拒绝空配方、非法数量或未知配置")

func _test_routing_and_isolation() -> void:
	_setup(_recipe({1: 5}, {2: 1}))
	m.create_container("bag", Vector2i(4, 4), m.ServiceType.GRID)
	m.add_to_container("bag", 1, 10, Vector2i.ZERO)
	var bag := _state("bag")
	t.code(crafting.craft("missing", &"test"), InventoryResult.Code.CONTAINER_NOT_FOUND, "未注册仓库明确失败")
	t.code(crafting.craft("bag", &"test"), InventoryResult.Code.UNSUPPORTED, "普通背包不能作为合成容器")
	t.code(crafting.preview("bag", &"test"), InventoryResult.Code.UNSUPPORTED, "预览同样拒绝背包")
	t.code(crafting.craft("warehouse", &"unknown"), InventoryResult.Code.INVALID_RECIPE, "未知配方失败")
	var preview: InventoryResult = crafting.preview("warehouse", &"test")
	t.expect(preview.is_ok() and not preview.payload.can_craft, "背包有材料不计入仓库材料")
	t.equal(preview.payload.materials[0].missing, 5, "预览给出缺少数量")
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.MATERIALS_MISSING, "不会隐式消耗背包材料")
	m.add_to_container("warehouse", 1, 5, Vector2i.ZERO)
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.OK, "仓库材料足够则合成")
	t.equal(_count(2), 1, "产物进入指定仓库")
	t.equal(_state("bag"), bag, "背包物品、布局、版本均不改变")
	m.create_container("other", Vector2i(3, 3), m.ServiceType.WAREHOUSE)
	m.add_to_container("other", 1, 10, Vector2i.ZERO)
	var other := _state("other")
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.MATERIALS_MISSING, "不从其他仓库自动补料")
	t.equal(_state("other"), other, "其他仓库保持原样")

func _test_stacks_and_preview() -> void:
	_setup(_recipe({1: 5}, {2: 12}))
	m.add_to_container("warehouse", 1, 3, Vector2i.ZERO)
	m.add_to_container("warehouse", 1, 4, Vector2i(1, 0))
	m.add_to_container("warehouse", 2, 9, Vector2i(2, 0), true)
	var source: ItemInstance = m.get_item_at("warehouse", Vector2i(1, 0)).instance
	var target: ItemInstance = m.get_item_at("warehouse", Vector2i(2, 0)).instance
	var before := _state()
	var next_id := ItemInstance._next_id
	var events: Array = []
	var listener := func(id: String, revision: int, ids: Array[int]): events.append([id, revision, ids])
	m.container_changed.connect(listener)
	for index in range(3):
		var preview: InventoryResult = crafting.preview("warehouse", &"test")
		t.expect(preview.is_ok() and preview.payload.can_craft and not preview.changed, "预览可执行且无状态变化")
		t.expect(not preview.payload.has("plan"), "公开预览不泄漏暂存实例")
	t.equal(_state(), before, "重复预览不修改库存或版本")
	t.equal(ItemInstance._next_id, next_id, "预览不消耗真实实例 ID")
	t.equal(events.size(), 0, "预览不通知库存变化")
	var result: InventoryResult = crafting.craft("warehouse", &"test")
	t.code(result, InventoryResult.Code.OK, "跨栈扣料并拆栈产出")
	t.equal(_count(1), 2, "材料按数量跨栈扣除")
	var remaining: ItemInstance = m.get_item_at("warehouse", Vector2i(1, 0)).instance
	t.equal([remaining.instance_id, remaining.quantity], [source.instance_id, 2], "部分扣栈保留实例身份与位置")
	var merged: ItemInstance = m.get_item_at("warehouse", Vector2i(2, 0)).instance
	t.equal([merged.instance_id, merged.quantity, merged.rotated], [target.instance_id, 10, true], "优先补已有栈且保留方向和身份")
	t.equal(_count(2), 21, "总产出正确，余量按最大堆叠拆分")
	t.equal(events.size(), 1, "整个合成只发送一次变化通知")
	t.equal(_state().revision, before.revision + 1, "整个合成只增加一次版本")
	t.equal(events[0][1], _state().revision, "通知为提交后版本")
	m.container_changed.disconnect(listener)
	# 预览通过后修改库存，执行必须重新规划。
	m.remove_from_container("warehouse", Vector2i(1, 0))
	before = _state()
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.MATERIALS_MISSING, "旧预览不会绕过执行时校验")
	t.equal(_state(), before, "旧预览失败无副作用")

func _test_capacity_and_rotation() -> void:
	_setup(_recipe({1: 2}, {2: 1}), Vector2i(2, 1))
	m.add_to_container("warehouse", 1, 1, Vector2i.ZERO)
	m.add_to_container("warehouse", 1, 1, Vector2i(1, 0))
	t.expect(crafting.preview("warehouse", &"test").payload.can_craft, "满仓可利用材料耗尽腾出的连续空间")
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.OK, "先扣料再按最终布局放置多格产物")
	_setup(_recipe({1: 1}, {2: 1}), Vector2i(1, 2))
	m.add_to_container("warehouse", 1, 1, Vector2i.ZERO)
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.OK, "产物自动旋转适配网格")
	t.expect(m.get_item_at("warehouse", Vector2i.ZERO).instance.rotated, "实际保存旋转方向")
	t.configs[2].CanRotate = false
	_setup(_recipe({1: 1}, {2: 1}), Vector2i(1, 2))
	m.add_to_container("warehouse", 1, 1, Vector2i.ZERO)
	var fixed_before := _state()
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.NO_SPACE, "禁止旋转的产物不会擅自旋转")
	t.equal(_state(), fixed_before, "禁止旋转放置失败时保留材料")
	t.configs[2].CanRotate = true
	_setup(_recipe({1: 1}, {3: 1}), Vector2i(2, 1))
	m.add_to_container("warehouse", 1, 2, Vector2i.ZERO)
	var before := _state()
	var preview: InventoryResult = crafting.preview("warehouse", &"test")
	t.expect(not preview.payload.can_craft and preview.payload.material_limit == 2, "材料上限与空间可执行性分开")
	t.equal(preview.payload.blocking_code, InventoryResult.Code.NO_SPACE, "预览明确提示空间不足")
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.NO_SPACE, "多格产物无空间时失败")
	t.equal(_state(), before, "空间不足不扣料、不改变版本或占位")

func _test_batch_and_outputs() -> void:
	_setup(_recipe({1: 2}, {2: 3, 3: 1}))
	m.add_to_container("warehouse", 1, 8, Vector2i.ZERO)
	t.code(crafting.craft("warehouse", &"test", 3), InventoryResult.Code.OK, "多产物批量合成")
	t.equal([_count(1), _count(2), _count(3)], [2, 9, 3], "批量消耗和各产物数量正确")
	for times in [0, -1, 1000]:
		var before := _state()
		t.code(crafting.craft("warehouse", &"test", times), InventoryResult.Code.INVALID_QUANTITY, "拒绝非法批量次数")
		t.equal(_state(), before, "非法次数无状态变化")
	_setup(_recipe({1: 1}, {1: 1, 3: 1}), Vector2i(2, 1))
	m.add_to_container("warehouse", 1, 2, Vector2i.ZERO)
	var before := _state()
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.NO_SPACE, "第二种产物放不下时拒绝整次合成")
	t.equal(_state(), before, "多产物失败回滚暂存中的扣料和前一产物")
	_setup(_recipe({1: 3}, {2: 1}))
	m.add_to_container("warehouse", 1, 5, Vector2i.ZERO)
	before = _state()
	t.code(crafting.craft("warehouse", &"test", 2), InventoryResult.Code.MATERIALS_MISSING, "批量材料不足不自动改为部分完成")
	t.equal(_state(), before, "批量失败整体不变")
	_setup(_recipe({1: 1}, {2: 9223372036854775807}))
	t.code(crafting.preview("warehouse", &"test", 2), InventoryResult.Code.INVALID_QUANTITY, "数量乘法溢出前拒绝")

func _test_faults() -> void:
	_setup(_recipe({1: 2}, {2: 1}))
	m.unregister_container("warehouse")
	var service := FaultWarehouse.new(t.lookup)
	service.initialize("warehouse", Vector2i(3, 3))
	service.add(ItemInstance.new(1, 4), Vector2i.ZERO)
	m.register_container("warehouse", service)
	var before := _state()
	var events: Array = []
	var listener := func(_id: String, _revision: int, _ids: Array[int]): events.append(true)
	m.container_changed.connect(listener)
	service.fail_after_commit = true
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.INTERNAL_ERROR, "真实提交后模拟故障")
	t.equal(_state(), before, "故障恢复物品、位置、数量和版本")
	t.equal(events.size(), 0, "故障不发送成功通知")
	service.fail_after_commit = false
	service.stale_on_commit = true
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.STALE_STATE, "提交拒绝过期版本")
	before.revision += 1
	t.equal(_state(), before, "版本冲突保留外部新版本，不覆盖它")
	t.equal(events.size(), 0, "版本冲突不发送变化通知")
	service.stale_on_commit = false
	t.code(crafting.craft("warehouse", &"test"), InventoryResult.Code.OK, "失败后事务锁已释放，可重新合成")
	t.equal(events.size(), 1, "恢复后正常合成只通知一次")
	m.container_changed.disconnect(listener)
