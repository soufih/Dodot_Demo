class_name PlayerEquipmentComponent
extends Node
## 玩家装备适配器：管理会话绑定与当前武器选择，物品及槽位状态只由 Manager 保存。

signal equipment_changed
signal weapon_changed

@export var definition: InventoryDefinition
@export var weapon_slots: Array[StringName] = [&"main_hand", &"off_hand"]
var inventory_manager: Node
var initialization_result: InventoryResult
var _active_slot: StringName
var _active_instance_id: int = -1

## 创建或复用玩家装备会话，随后订阅已提交的容器变化，不订阅 UI 的拖放预览。
func _ready() -> void:
	if inventory_manager == null:
		inventory_manager = InventoryManager
	initialization_result = PlayerInventorySession.ensure(definition, inventory_manager)
	if initialization_result.is_ok():
		for slot_id in weapon_slots:
			initialization_result = inventory_manager.get_slot_position(definition.container_id, slot_id)
			if not initialization_result.is_ok():
				break
	if not initialization_result.is_ok():
		push_error(initialization_result.message)
		return
	inventory_manager.container_changed.connect(_on_container_changed)
	refresh()

## 角色退出只解除订阅，装备实例继续留在会话容器中。
func _exit_tree() -> void:
	if is_instance_valid(inventory_manager) and inventory_manager.container_changed.is_connected(_on_container_changed):
		inventory_manager.container_changed.disconnect(_on_container_changed)

## 查询当前武器配置 ID；未装备时返回 -1，不复制维护一份武器列表。
func get_current_weapon() -> int:
	var item := _item_in_slot(_active_slot)
	return item.config_id if item != null else -1

## 查询当前槽之后的下一把已装备武器，没有其他武器时返回 -1。
func get_next_weapon() -> int:
	var slot_id := _next_weapon_slot()
	var item := _item_in_slot(slot_id)
	return item.config_id if item != null else -1

## 切换当前使用槽位，不移动装备实例或改变容器版本；没有备用武器时明确失败。
func switch_weapon() -> InventoryResult:
	var next := _next_weapon_slot()
	if next == &"":
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "没有可切换的备用武器")
	_active_slot = next
	refresh()
	return InventoryResult.success()

## 根据真实容器恢复当前选择；卸下当前武器后回退到第一个非空武器槽。
func refresh() -> void:
	if not initialization_result.is_ok():
		return
	if _item_in_slot(_active_slot) == null:
		_active_slot = &""
		for slot_id in weapon_slots:
			if _item_in_slot(slot_id) != null:
				_active_slot = slot_id
				break
	var current := _item_in_slot(_active_slot)
	var instance_id := current.instance_id if current != null else -1
	if instance_id != _active_instance_id:
		_active_instance_id = instance_id
		weapon_changed.emit()
	equipment_changed.emit()

## 显式新游戏重建装备会话并刷新消费者；普通切关和关闭背包不会调用此方法。
func start_new() -> InventoryResult:
	var result := PlayerInventorySession.start_new(definition, inventory_manager)
	if result.is_ok():
		refresh()
	return result

## 只响应本角色装备容器的成功提交，背包移动及失败命令不会触发武器刷新。
func _on_container_changed(id: String, _revision: int, _ids: Array[int]) -> void:
	if id == definition.container_id:
		refresh()

## 从隔离快照读取命名槽的物品；空标识代表未选择，空槽不会发送失败通知。
func _item_in_slot(slot_id: StringName) -> ItemInstance:
	if slot_id == &"":
		return null
	var position: InventoryResult = inventory_manager.get_slot_position(definition.container_id, slot_id)
	if not position.is_ok():
		return null
	var state: Dictionary = inventory_manager.get_snapshot(definition.container_id)
	var id: Variant = state.cells[0][position.payload.x]
	return state.items[id].instance if id != null else null

## 按配置顺序循环查找备用槽，跳过当前槽与空槽。
func _next_weapon_slot() -> StringName:
	if weapon_slots.is_empty() or initialization_result == null or not initialization_result.is_ok():
		return &""
	var start := weapon_slots.find(_active_slot)
	for offset in range(1, weapon_slots.size() + 1):
		var slot_id := weapon_slots[(start + offset) % weapon_slots.size()]
		if slot_id != _active_slot and _item_in_slot(slot_id) != null:
			return slot_id
	return &""

## 状态机按组件类型查找装备入口，不依赖旧的全局装备单例。
static func find_for(actor: Node) -> PlayerEquipmentComponent:
	for child in actor.get_children():
		if child is PlayerEquipmentComponent:
			return child
	return null
