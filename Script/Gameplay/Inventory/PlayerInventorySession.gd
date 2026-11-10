class_name PlayerInventorySession
extends RefCounted
## 玩家容器的会话生命周期，运行期状态仍由传入的 Manager 唯一持有。

## 首次创建容器并按资源配置发放初始物品；切关或重建角色时复用会话，不重复发放。
static func ensure(definition: InventoryDefinition, manager: Node) -> InventoryResult:
	if definition == null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "未配置玩家背包")
	if manager.has_container(definition.container_id):
		return InventoryResult.success()
	var result: InventoryResult = manager.create_container(definition.container_id, definition.size, definition.service_type, definition.equipment_slots)
	if not result.is_ok():
		return result
	result = _populate_initial_items(definition, manager)
	if not result.is_ok():
		manager.unregister_container(definition.container_id)
	return result

## 所有初始物品通过统一接口添加，装备按槽位标识放置；调用方在失败时注销新建的半成品容器。
static func _populate_initial_items(definition: InventoryDefinition, manager: Node) -> InventoryResult:
	for item in definition.initial_items:
		if item == null:
			return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "初始物品配置不能为空")
		var result: InventoryResult
		if item.slot_id == &"":
			result = manager.quick_add_to_container(definition.container_id, item.config_id, item.quantity, item.rotated)
		else:
			var slot: InventoryResult = manager.get_slot_position(definition.container_id, item.slot_id)
			if not slot.is_ok():
				return slot
			result = manager.add_to_container(definition.container_id, item.config_id, item.quantity, slot.payload, item.rotated)
		if not result.is_ok():
			return result
	return InventoryResult.success()

## 明确开始新游戏时重建玩家容器；关闭窗口和退出角色场景均不调用此方法。
static func start_new(definition: InventoryDefinition, manager: Node) -> InventoryResult:
	if definition == null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "未配置玩家背包")
	if manager.has_container(definition.container_id):
		var removed: InventoryResult = manager.unregister_container(definition.container_id)
		if not removed.is_ok():
			return removed
	return ensure(definition, manager)
