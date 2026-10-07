class_name DropComponent
extends Node2D
## 人物掉落组件，在组件的世界坐标处生成掉落物。

@export var items: Array[droppedItemConfig] = []:
	set(value):
		items = value

## 玩家组件接收拾取提示，并提供调试控制台的掉落服务。
@export var show_pickup_mentions: bool = false

var _pending_mentions: Array[Dictionary] = []
var _showing_mentions: bool = false

func _ready() -> void:
	if show_pickup_mentions:
		SignalBus.items_picked_up.connect(create_pickup_mention)
		DebugTool.register_service(&"dropped_items", self)

func _exit_tree() -> void:
	if SignalBus.items_picked_up.is_connected(create_pickup_mention):
		SignalBus.items_picked_up.disconnect(create_pickup_mention)
	if DebugTool.get_service(&"dropped_items") == self:
		DebugTool.unregister_service(&"dropped_items")


func drop() -> void:
	var result: Array = []
	for item in items:
		if item == null or item.possbility <= 0.0:
			continue
		if randf_range(0.0, 100.0) > item.possbility:
			continue
		var amount := randi_range(item.range_x, item.range_y)
		result.append({"id": item.id, "amount": amount})
	if not result.is_empty():
		create_dropped_item(result, global_position)

## 掉落物归当前场景所有，人物销毁后继续存在，切换场景时自动清理。
func create_dropped_item(item_list: Array, spawn_position: Vector2) -> DroppedItem:
	if item_list.is_empty():
		return null
	var scene := load(Path.DROPPED_ITEM_SCENE) as PackedScene
	if scene == null:
		push_error("Failed to load dropped item scene")
		return null
	var dropped := scene.instantiate() as DroppedItem
	dropped.add_item(item_list)
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(dropped)
	dropped.global_position = spawn_position
	return dropped

## 连续拾取时按顺序显示提示，避免多次等待结束后同时弹出。
func create_pickup_mention(item: Dictionary) -> void:
	_pending_mentions.append(item.duplicate())
	if _showing_mentions:
		return
	_showing_mentions = true
	while not _pending_mentions.is_empty():
		var scene := load(Path.FLOATING_PICKUP_MENTION_UI_SCENE) as PackedScene
		if scene == null:
			push_error("Failed to load pickup mention scene")
			_pending_mentions.clear()
			break
		var mention := scene.instantiate() as pickupMention
		UIManager.UILayer.add_child(mention)
		mention.set_display(_pending_mentions.pop_front())
		await get_tree().create_timer(1.25).timeout
	_showing_mentions = false
