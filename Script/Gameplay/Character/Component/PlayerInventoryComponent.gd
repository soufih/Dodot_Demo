class_name PlayerInventoryComponent
extends Node
## 玩家背包业务入口：绑定会话容器、按合法栈接收物品、打开正式 UI。

signal items_received(result: InventoryResult)

@export var definition: InventoryDefinition
@export var equipment: PlayerEquipmentComponent
var inventory_manager: Node
var config_lookup: Callable
var initialization_result: InventoryResult

## 默认连接正式 Autoload；测试可在进入场景树前注入独立 Manager 与配置查询。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if inventory_manager == null:
		inventory_manager = InventoryManager
	if not config_lookup.is_valid():
		config_lookup = ResourceManager.get_item_config
	initialization_result = PlayerInventorySession.ensure(definition, inventory_manager)
	if not initialization_result.is_ok():
		push_error(initialization_result.message)

## 分批接收超过 MaxStack 的掉落；每批成功后累计数量，空间不足时保留未接收部分。
## payload 是实际接收数量；业务层据此扣减掉落，不把预览当成正式入包。
func receive_item(config_id: int, quantity: int) -> InventoryResult:
	if not initialization_result.is_ok():
		return initialization_result
	var config: ItemConfig = config_lookup.call(config_id)
	if config == null or not config.validate() or quantity <= 0:
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "掉落物配置或数量无效")
	var accepted := 0
	var ids: Array[int] = []
	var last_result: InventoryResult
	while accepted < quantity:
		var amount := mini(quantity - accepted, config.MaxStack)
		last_result = inventory_manager.quick_add_to_container(definition.container_id, config_id, amount)
		if not last_result.is_ok():
			break
		accepted += amount
		ids.append_array(last_result.affected_ids)
	var result := InventoryResult.success(accepted, ids, true) if accepted > 0 else last_result
	if accepted > 0 and accepted < quantity:
		result.message = last_result.message
	items_received.emit(result)
	return result

## 背包快捷键属于 UI 输入，不使用游戏操作禁用标记，打开后仍可按同键关闭。
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("OpenBackpack") or event.is_echo():
		return
	if UIManager.is_banned or UIManager.is_paused or UIManager.has_result_or_loading():
		return
	toggle_inventory()
	get_viewport().set_input_as_handled()

## 通过正式工作区同时显示背包与装备栏；没有装备组件的角色仍只打开背包。
func toggle_inventory() -> void:
	if not initialization_result.is_ok():
		return
	var containers := get_ui_containers()
	if not containers.is_empty():
		UIManager.toggle(UIId.INVENTORY, {"containers": containers})

## 返回玩家现有容器的界面描述，仓库交互可以复用并追加容器，不另存物品状态。
func get_ui_containers() -> Array[Dictionary]:
	if not initialization_result.is_ok():
		return []
	var containers: Array[Dictionary] = [{"id": definition.container_id, "service_type": definition.service_type, "display_name": definition.display_name}]
	if equipment != null:
		if not equipment.initialization_result.is_ok():
			return []
		containers.append({"id": equipment.definition.container_id, "service_type": equipment.definition.service_type, "display_name": equipment.definition.display_name})
	return containers

## 测试台或新游戏显式重建两个容器；关闭视图不影响运行期物品。
func start_new() -> InventoryResult:
	var result := PlayerInventorySession.start_new(definition, inventory_manager)
	if result.is_ok() and equipment != null:
		result = equipment.start_new()
	return result

## 交互适配器按组件类型寻找角色背包，不依赖 HeroProperty 或固定节点名称。
static func find_for(actor: Node) -> PlayerInventoryComponent:
	for child in actor.get_children():
		if child is PlayerInventoryComponent:
			return child
	return null
