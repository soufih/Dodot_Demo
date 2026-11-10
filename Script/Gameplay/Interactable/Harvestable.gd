class_name Harvestable
extends Interactable
## 一次性采集点：复用玩家交互与世界掉落工厂，不直接向背包添加材料。

signal harvested(actor: Node, dropped_item: DroppedItem)

@export_category("外观")
## 采集物使用的显示精灵，在场景中绑定 Sprite2D 子节点。
@export var sprite: Sprite2D

@export_category("掉落列表")
## 每项设置物品 ID、数量上下限与掉落概率（0～100），逐项独立判定。
@export var drop_list: Array[droppedItemConfig] = []

var _harvested: bool = false

@onready var _drops: DropComponent = $Drops
@onready var _drop_origin: Marker2D = $DropOrigin


func can_interact(actor: Node) -> bool:
	if _harvested or not is_node_ready() or is_queued_for_deletion():
		return false
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	if actor is BaseCharacter and actor.CurrentHealth <= 0.0:
		return false
	return PlayerInventoryComponent.find_for(actor) != null and _has_valid_drop()


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	# 在创建掉落前锁定，避免节点加入场景或信号回调期间重入而重复产出。
	_harvested = true
	_drops.items = drop_list
	var items := _drops.roll_items()
	var dropped: DroppedItem
	if not items.is_empty():
		dropped = _drops.create_dropped_item(items, _drop_origin.global_position)
		if dropped == null:
			_harvested = false
			return
	# 本次概率判定全未命中也算采集完成；信号的 dropped_item 此时为 null。
	# 掉落属于当前地图，销毁采集点及其 Drops 子节点不会连带销毁材料。
	queue_free()
	harvested.emit(actor, dropped)


func get_interaction_text() -> String:
	if _harvested:
		return "已采集"
	return interaction_name if _has_valid_drop() else "采集配置无效"


func _has_valid_drop() -> bool:
	if drop_list.is_empty():
		return false
	for item in drop_list:
		if item == null or item.range_x < 1 or item.range_y < item.range_x:
			return false
		if not is_finite(item.possbility) or item.possbility < 0.0 or item.possbility > 100.0:
			return false
		var config := ResourceManager.get_item_config(item.id)
		if config == null or not config.validate():
			return false
	return true
