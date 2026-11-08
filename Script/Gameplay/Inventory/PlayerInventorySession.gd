class_name PlayerInventorySession
extends RefCounted
## 玩家容器的会话生命周期，运行期状态仍由传入的 Manager 唯一持有。

## 首次创建容器；切关或重建角色时复用已有容器，不重置物品。
static func ensure(definition: InventoryDefinition, manager: Node) -> InventoryResult:
	if definition == null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "未配置玩家背包")
	if manager.has_container(definition.container_id):
		return InventoryResult.success()
	return manager.create_container(definition.container_id, definition.size, definition.service_type, definition.equipment_slots)

## 明确开始新游戏时重建玩家容器；关闭窗口和退出角色场景均不调用此方法。
static func start_new(definition: InventoryDefinition, manager: Node) -> InventoryResult:
	if definition == null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "未配置玩家背包")
	if manager.has_container(definition.container_id):
		var removed: InventoryResult = manager.unregister_container(definition.container_id)
		if not removed.is_ok():
			return removed
	return ensure(definition, manager)
