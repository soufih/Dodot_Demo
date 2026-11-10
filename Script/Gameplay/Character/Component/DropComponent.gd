class_name DropComponent
extends Node2D
## 人物掉落组件，在组件的世界坐标处生成掉落物。

@export var items: Array[droppedItemConfig] = []:
	set(value):
		items = value

## 提供调试控制台的掉落服务。
@export var register_debug_drop_service: bool = false

func _ready() -> void:
	if register_debug_drop_service:
		DebugTool.register_service(&"dropped_items", self)

func _exit_tree() -> void:
	if DebugTool.get_service(&"dropped_items") == self:
		DebugTool.unregister_service(&"dropped_items")


func drop() -> void:
	var result := roll_items()
	if not result.is_empty():
		create_dropped_item(result, global_position)

## 按列表逐项独立判定概率与数量，返回本次清单，不修改共享掉落配置。
func roll_items() -> Array:
	var result: Array = []
	for item in items:
		if item == null or item.possbility <= 0.0:
			continue
		if randf_range(0.0, 100.0) > item.possbility:
			continue
		var amount := randi_range(item.range_x, item.range_y)
		result.append({"id": item.id, "amount": amount})
	return result

## 掉落物归当前场景所有，人物销毁后继续存在，切换场景时自动清理。
func create_dropped_item(item_list: Array, spawn_position: Vector2) -> DroppedItem:
	if item_list.is_empty():
		return null
	var scene := load(Path.DROPPED_ITEM_SCENE) as PackedScene
	if scene == null:
		push_error("Failed to load dropped item scene")
		return null
	var dropped := scene.instantiate() as DroppedItem
	dropped.configure(item_list)
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(dropped)
	dropped.global_position = spawn_position
	return dropped
