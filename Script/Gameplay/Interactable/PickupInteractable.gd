class_name PickupInteractable
extends Interactable
## 将现有角色交互系统适配到掉落清单与背包组件。

@export var dropped_item: DroppedItem
var _feedback: String = ""

## 仅带背包组件的角色可以拾取尚有内容且未销毁的掉落。
func can_interact(actor: Node) -> bool:
	return not dropped_item.items.is_empty() and not dropped_item.is_queued_for_deletion() \
		and PlayerInventoryComponent.find_for(actor) != null

## 只在正式接收成功后扣减掉落，失败或部分成功时保留清单供再次交互。
func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	var inventory := PlayerInventoryComponent.find_for(actor)
	var result := dropped_item.collect(inventory.receive_item)
	_feedback = result.message

## 提示始终读取当前剩余清单，背包满时继续显示可重试的反馈。
func get_interaction_text() -> String:
	if not _feedback.is_empty():
		return _feedback
	return dropped_item.get_pickup_text()
