class_name WarehouseInteractable
extends Interactable
## 世界仓库入口：复用既有 E 交互和 UIManager，物品始终保存在全局 Manager。

@export var definition: InventoryDefinition
var initialization_result: InventoryResult
var _feedback: String = ""
var _owns_open_view: bool = false

## 创建或复用稳定 ID 的仓库；场景重载不清空仓库，不持有独立容器副本。
func _ready() -> void:
	if definition == null or definition.service_type != InventoryManager.ServiceType.WAREHOUSE:
		initialization_result = InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "交互物需要有效的仓库定义")
	elif InventoryManager.has_container(definition.container_id):
		initialization_result = InventoryResult.success() if InventoryManager.is_warehouse(definition.container_id) else InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "仓库标识已经被其他类型的容器使用")
	else:
		initialization_result = InventoryManager.create_container(definition.container_id, definition.size, definition.service_type, definition.equipment_slots)
	if not initialization_result.is_ok():
		_feedback = initialization_result.message

## 只有带正式背包的存活角色可打开仓库；其他模态窗口打开时不允许再次操作。
func can_interact(actor: Node) -> bool:
	if not initialization_result.is_ok() or UIManager.has_blocking_ui() or UIManager.has_result_or_loading():
		return false
	if actor is BaseCharacter and actor.CurrentHealth <= 0.0:
		return false
	var inventory := PlayerInventoryComponent.find_for(actor)
	return inventory != null and inventory.initialization_result.is_ok() \
		and inventory.inventory_manager == InventoryManager

## 沿用玩家背包和装备列表，再追加仓库；每次 E 交互只绑定已存在的真实容器。
func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	var inventory := PlayerInventoryComponent.find_for(actor)
	var containers := inventory.get_ui_containers()
	if containers.is_empty():
		_feedback = "玩家容器尚未就绪"
		return
	containers.append({"id": definition.container_id, "service_type": definition.service_type, "display_name": definition.display_name})
	var ui = UIManager.open(UIId.INVENTORY, {"containers": containers}, UIManager.scene_owner(self))
	if ui == null:
		_feedback = "仓库界面无法打开，请检查容器与布局配置"
		return
	_feedback = ""
	_owns_open_view = true
	if not UIManager.window_closed.is_connected(_on_window_closed):
		UIManager.window_closed.connect(_on_window_closed)

## 可重复交互的提示不会在第一次打开后永久消失。
func get_interaction_text() -> String:
	return _feedback if not _feedback.is_empty() else interaction_name

## 正常关闭后释放界面归属，避免销毁旧交互物时关闭后来打开的其他窗口。
func _on_window_closed(id: StringName) -> void:
	if id == UIId.INVENTORY:
		_owns_open_view = false
		UIManager.window_closed.disconnect(_on_window_closed)

## 销毁仓库交互物只关闭其拥有的视图，始终保留会话物品。
func _exit_tree() -> void:
	if _owns_open_view:
		UIManager.close(UIId.INVENTORY, "", &"warehouse_removed")
	if UIManager.window_closed.is_connected(_on_window_closed):
		UIManager.window_closed.disconnect(_on_window_closed)
