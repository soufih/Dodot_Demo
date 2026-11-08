extends Node
## 仓库业务入口；容器、物品状态和事务锁统一由注入的 InventoryManager 持有。

const WAREHOUSE_SERVICE = preload("res://Script/Gameplay/Inventory/Services/WarehouseService.gd")

## 正式单例默认使用全局 InventoryManager；独立场景通过节点引用注入自己的实例。
@export var inventory_manager: Node

## 只绑定既有管理器，不复制容器注册表，也不订阅或转发第二套物品通知。
func _ready() -> void:
	if inventory_manager == null:
		inventory_manager = InventoryManager

## 只读判断稳定 ID 是否注册了仓库服务，未知 ID 或其他容器返回 false。
func is_warehouse(id: String) -> bool:
	return inventory_manager.is_container_service(id, WAREHOUSE_SERVICE)

## 返回指定仓库各配置的数量汇总，payload 为独立的 {config_id: quantity} 字典。
func get_item_counts(id: String) -> InventoryResult:
	return inventory_manager.query_container_service(id, WAREHOUSE_SERVICE,
		func(service: WarehouseService) -> InventoryResult: return service.get_item_counts())

## 返回指定配置的数量合计，未存放时为 0；未知仓库与非仓库容器仍明确返回失败。
func get_item_count(id: String, config_id: int) -> InventoryResult:
	return inventory_manager.query_container_service(id, WAREHOUSE_SERVICE,
		func(service: WarehouseService) -> InventoryResult: return service.get_item_count(config_id))

## 返回指定仓库全部物品的数量总和，不计背包或其他仓库，不改变版本或触发变更通知。
func get_total_item_count(id: String) -> InventoryResult:
	return inventory_manager.query_container_service(id, WAREHOUSE_SERVICE,
		func(service: WarehouseService) -> InventoryResult: return service.get_total_item_count())

## 仓库专属整理入口；通过通用操作入口执行，沿用统一事务锁、回滚和变更通知。
func organize_warehouse(id: String) -> InventoryResult:
	return inventory_manager.execute_container_operation(id, WAREHOUSE_SERVICE, _organize)

## 类型已由 InventoryManager 校验，整理算法及失败恢复仍由仓库服务负责。
func _organize(service: WarehouseService) -> InventoryResult:
	return service.organize()
