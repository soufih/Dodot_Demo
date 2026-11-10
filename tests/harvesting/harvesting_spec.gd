extends Node
## 通过正式输入、物理交互、掉落场景和背包验证完整采集链路。

const HARVESTABLE = preload("res://Scene/Map/MapComponent/Harvestable.tscn")
const DEFINITION = preload("res://tests/inventory/gameplay_definition.tres")

var checks = preload("res://tests/inventory/spec_context.gd").new()
var actor: Node2D
var drops: Array[DroppedItem] = []
var harvest_events: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	actor = get_parent().get_node("Actor")
	UIManager.configure_scene(get_parent(), [UIId.INVENTORY])
	await _settle()
	await _test_harvest_and_pickup()
	await _test_full_backpack()
	await _test_drop_list()
	await _test_no_drop_roll()
	await _test_invalid_configuration()
	await _test_existing_drop_component()
	await _test_transformed_parent()
	_clear_inventory()
	InventoryManager.unregister_container(DEFINITION.container_id)
	print("HARVESTING_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)


func _test_harvest_and_pickup() -> void:
	var mine := _spawn(actor.global_position)
	await _settle()
	checks.equal(mine.collision_layer, 256, "采集点使用现有交互层")
	checks.equal(mine.sprite.texture.get_size(), Vector2(32, 32), "导出的精灵绑定矿点低分辨率素材")
	checks.equal(mine.drop_list.size(), 1, "默认掉落列表保留一项青晶矿材料")
	checks.equal(ResourceManager.get_item_icon(mine.drop_list[0].id).resource_path.get_file(), "item301.png", "默认矿图和掉落物品 ID 匹配")
	checks.expect(actor.get_node("Detector").get_current_interactable() == mine, "物理检测发现采集点")
	checks.equal(actor.get_node("Prompt").text, "[E] %s" % mine.get_interaction_text(), "显示配置的 E 交互提示")
	mine.drop_list = [_entry(24, 3, 3)]
	var origin: Vector2 = mine.get_node("DropOrigin").global_position
	# 信号发出时重入，确认同一个采集点无法再次产生掉落。
	mine.harvested.connect(func(_who, _dropped): mine.interact(actor))
	var token := UIManager.acquire_request(self, false, true)
	await _key(KEY_E)
	checks.expect(is_instance_valid(mine) and drops.is_empty(), "UI 屏蔽游戏输入时不能采集")
	UIManager.release_request(token)
	await _key(KEY_E)
	await _settle()
	checks.expect(not is_instance_valid(mine), "E 采集后销毁矿点")
	checks.equal(drops.size(), 1, "重复回调只生成一个世界掉落")
	checks.equal(_total(), 0, "采集材料先落到地面，不直接入包")
	if drops.is_empty():
		return
	var dropped := drops.pop_back() as DroppedItem
	checks.equal(dropped.items, [{"id": 24, "amount": 3}], "掉落清单包含配置的 ID 与数量")
	checks.expect(dropped.global_position.is_equal_approx(origin), "从矿点的世界坐标标记生成掉落")
	checks.expect(dropped.get_parent() == get_tree().current_scene, "掉落独立于已经销毁的矿点")
	checks.expect(dropped.get_node("ItemIcon").texture != null, "掉落显示正式物品图标")
	checks.expect(actor.get_node("Detector").get_current_interactable() == dropped.get_node("Pickup"), "采集后检测器切换到地面拾取")
	await _key(KEY_E)
	await _settle()
	checks.equal(_total(), 3, "再次按 E 拾取材料入包")
	checks.expect(not is_instance_valid(dropped), "拾取完毕后移除世界掉落")
	checks.expect(actor.get_node("Detector").get_current_interactable() == null, "采集与拾取结束后无残留交互引用")
	_clear_inventory()


func _test_full_backpack() -> void:
	actor.get_node("Inventory").receive_item(24, 200)
	var mine := _spawn(actor.global_position)
	# 用默认 1～3 范围，验证随机数量仍可被现有满包重试逻辑保留。
	await _settle()
	await _key(KEY_E)
	await _settle()
	checks.expect(not is_instance_valid(mine), "背包满时仍可采集到地面")
	if drops.is_empty():
		checks.expect(false, "满包采集应生成世界掉落")
		return
	var dropped := drops.pop_back() as DroppedItem
	var amount: int = dropped.items[0].amount
	checks.expect(amount >= 1 and amount <= 3, "默认掉落数量在配置范围内")
	await _key(KEY_E)
	checks.equal(_total(), 200, "满包不会额外入包")
	checks.equal(dropped.items, [{"id": 24, "amount": amount}], "满包拾取失败时保留全部采集掉落")
	_clear_inventory()
	await _key(KEY_E)
	await _settle()
	checks.equal(_total(), amount, "腾出空间后可继续拾取同一采集掉落")
	checks.expect(not is_instance_valid(dropped), "重试成功后清理掉落")
	_clear_inventory()


func _test_drop_list() -> void:
	var mine := _spawn(actor.global_position)
	var first := _entry(24, 2, 2)
	var second := _entry(29, 4, 4)
	var disabled := _entry(23, 1, 1, 0.0)
	mine.drop_list = [first, second, disabled]
	await _settle()
	await _key(KEY_E)
	await _settle()
	checks.expect(not is_instance_valid(mine), "多项掉落采集后消耗矿点")
	checks.equal(drops.size(), 1, "列表中命中的条目共用现有世界掉落清单")
	if drops.is_empty():
		return
	var dropped := drops.pop_back() as DroppedItem
	checks.equal(dropped.items, [{"id": 24, "amount": 2}, {"id": 29, "amount": 4}], "百分之百条目均命中，零概率条目不掉落")
	checks.equal(dropped.get_node("Amount").text, "2 种", "多项掉落显示物品种类数")
	checks.equal([first.range_x, first.range_y, second.range_x, second.range_y, disabled.possbility], [2, 2, 4, 4, 0.0], "采集不会修改共享掉落配置")
	await _key(KEY_E)
	await _settle()
	checks.equal(_total(), 6, "两种掉落经真实 E 输入完整入包")
	checks.equal(InventoryManager.get_snapshot(DEFINITION.container_id).items.size(), 2, "不同材料保留独立物品栈")
	checks.expect(not is_instance_valid(dropped), "多项清单全部拾取后销毁")
	_clear_inventory()


func _test_no_drop_roll() -> void:
	var mine := _spawn(actor.global_position)
	mine.drop_list = [_entry(24, 1, 3, 0.0)]
	var before := harvest_events
	mine.harvested.connect(func(_who, _dropped): mine.interact(actor))
	await _settle()
	checks.expect(mine.can_interact(actor), "零概率是合法配置")
	await _key(KEY_E)
	await _settle()
	checks.expect(not is_instance_valid(mine), "全部未命中时仍完成一次采集")
	checks.expect(drops.is_empty(), "未命中时不创建空世界掉落")
	checks.equal(harvest_events, before + 1, "空掉落只发送一次采集完成信号")
	checks.expect(actor.get_node("Detector").get_current_interactable() == null, "空掉落采集后清理交互目标")


func _test_invalid_configuration() -> void:
	var mine := _spawn(actor.global_position)
	await _settle()
	checks.expect(not mine.can_interact(null), "无角色时拒绝采集")
	checks.expect(not mine.can_interact(self), "非玩家交互者不能采集")
	mine.drop_list = [_entry(999999, 1, 3)]
	checks.expect(not mine.can_interact(actor), "未知物品 ID 不能生成无效掉落")
	await _key(KEY_E)
	checks.expect(is_instance_valid(mine) and drops.is_empty(), "配置错误不消耗矿点")
	checks.equal(mine.get_interaction_text(), "采集配置无效", "配置错误给出交互反馈")
	mine.drop_list = []
	checks.expect(not mine.can_interact(actor), "空列表不消耗矿点")
	mine.drop_list = [null]
	checks.expect(not mine.can_interact(actor), "未设置资源的列表项不能采集")
	mine.drop_list = [_entry(24, 0, 3)]
	checks.expect(not mine.can_interact(actor), "非正数量不能采集")
	mine.drop_list = [_entry(24, 5, 2)]
	checks.expect(not mine.can_interact(actor), "颠倒的数量范围不能采集")
	for chance in [-1.0, 101.0, NAN, INF]:
		mine.drop_list = [_entry(24, 1, 3, chance)]
		checks.expect(not mine.can_interact(actor), "拒绝非法概率 %s" % chance)
	mine.drop_list = [_entry(24, 1, 3), _entry(999999, 1, 1)]
	checks.expect(not mine.can_interact(actor), "列表中任何一项无效时保留整个采集点")
	mine.interact(actor)
	checks.expect(not mine.is_queued_for_deletion() and drops.is_empty(), "非法混合列表不产生部分掉落")
	mine.drop_list = [_entry(24, 1, 3)]
	checks.expect(mine.can_interact(actor), "修复配置后可以采集")
	mine.queue_free()
	await _settle()


func _test_existing_drop_component() -> void:
	# 抽出共用清单判定后，既有角色组件的 drop() 仍须保留原有生成行为。
	var component: DropComponent = actor.get_node("Drops")
	component.items = [_entry(24, 2, 2), _entry(29, 1, 1, 0.0)]
	component.drop()
	var found: Array[DroppedItem] = []
	for child in get_tree().current_scene.get_children():
		if child is DroppedItem:
			found.append(child)
	checks.equal(found.size(), 1, "既有角色掉落入口继续生成世界掉落")
	if not found.is_empty():
		checks.equal(found[0].items, [{"id": 24, "amount": 2}], "角色掉落继续使用相同的列表概率与数量规则")
		checks.expect(found[0].global_position.is_equal_approx(component.global_position), "角色掉落仍在组件世界坐标处生成")
	for dropped in found:
		dropped.queue_free()
	component.items = []
	await _settle()


func _test_transformed_parent() -> void:
	var parent: Node2D = get_parent().get_node("Transformed")
	var mine := _spawn(Vector2.ZERO, parent)
	mine.drop_list = [_entry(29, 2, 2)]
	var origin: Vector2 = mine.get_node("DropOrigin").global_position
	mine.interact(actor)
	checks.equal(drops.size(), 1, "可配置其他正式材料作为产出")
	if drops.is_empty():
		return
	var dropped := drops.pop_back() as DroppedItem
	checks.equal(dropped.items, [{"id": 29, "amount": 2}], "使用配置的替代材料和数量")
	checks.expect(dropped.global_position.is_equal_approx(origin), "父节点平移旋转缩放后仍使用正确世界坐标")
	parent.queue_free()
	await _settle()
	checks.expect(is_instance_valid(dropped), "删除采集物父节点不会丢失已生成材料")
	dropped.queue_free()
	await _settle()


func _spawn(at: Vector2, parent: Node = null) -> Harvestable:
	var mine := HARVESTABLE.instantiate() as Harvestable
	(parent if parent != null else get_parent()).add_child(mine)
	mine.position = at
	mine.harvested.connect(_on_harvested)
	return mine


func _on_harvested(_who: Node, dropped: DroppedItem) -> void:
	harvest_events += 1
	if dropped == null:
		return
	# 固定测试掉落，避免随机弹射使连续 E 拾取测试依赖帧率。
	dropped.freeze = true
	dropped.linear_velocity = Vector2.ZERO
	drops.append(dropped)


func _entry(id: int, minimum: int, maximum: int, chance: float = 100.0) -> droppedItemConfig:
	var item := droppedItemConfig.new()
	item.id = id
	item.range_x = minimum
	item.range_y = maximum
	item.possbility = chance
	return item


func _total() -> int:
	var total := 0
	for record in InventoryManager.get_snapshot(DEFINITION.container_id).items.values():
		total += record.instance.quantity
	return total


func _clear_inventory() -> void:
	for record in InventoryManager.get_snapshot(DEFINITION.container_id).items.values():
		InventoryManager.remove_from_container(DEFINITION.container_id, record.anchor)


func _settle() -> void:
	for frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
