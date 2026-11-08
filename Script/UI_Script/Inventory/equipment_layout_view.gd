extends Control
## 装备布局只发现和绑定场景中已有的槽位；不按业务矩阵创建或排列任何节点。

signal item_selected(container_id: String, record: Dictionary)
signal operation_completed(result: InventoryResult)
var _slots: Array[EquipmentSlotView] = []

## 从任意深度的手工分组中收集槽位，不要求特定的分组名称或排列方式。
func _find_slots() -> Array[EquipmentSlotView]:
	var slots: Array[EquipmentSlotView] = []
	for node in find_children("*", "Control", true, false):
		if node is EquipmentSlotView:
			slots.append(node)
	return slots

## 绑定前一次校验所有槽位，拒绝重复或不存在的标识，避免只绑定部分布局。
func validate_layout(manager: Node, id: String) -> InventoryResult:
	var seen: Dictionary = {}
	var slots := _find_slots()
	if slots.is_empty():
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "装备布局没有配置槽位")
	for slot in slots:
		if seen.has(slot.slot_id):
			return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "装备槽标识重复：%s（%s）" % [slot.slot_id, get_path_to(slot)])
		var result: InventoryResult = manager.get_slot_position(id, slot.slot_id)
		if not result.is_ok():
			return InventoryResult.failure(result.code, "装备槽 %s（%s）绑定失败：%s" % [slot.slot_id, get_path_to(slot), result.message])
		seen[slot.slot_id] = true
	return InventoryResult.success()

## 连接既有槽位；每个槽位自行刷新物品数据，分组和槽位布局保持场景设置。
func bind(manager: Node, id: String, service_type: int, lookup: Callable) -> void:
	unbind()
	_slots = _find_slots()
	for slot in _slots:
		slot.item_selected.connect(_on_item_selected)
		slot.operation_completed.connect(_on_operation_completed)
		slot.bind(manager, id, service_type, lookup)
		slot.drag_preview_scale_source = self

## 清理全部数据和转发订阅，允许关闭后重新绑定，不重建场景节点。
func unbind() -> void:
	for slot in _slots:
		slot.unbind()
		slot.item_selected.disconnect(_on_item_selected)
		slot.operation_completed.disconnect(_on_operation_completed)
	_slots.clear()

## 窗口关闭或失去交互权时取消此布局发起的拖放。
func cancel_interaction() -> void:
	for slot in _slots:
		slot.cancel_interaction()

## 同一布局只保留一个选中槽；仅更新显示，不移动节点。
func _on_item_selected(id: String, record: Dictionary) -> void:
	for slot in _slots:
		slot._selected_id = record.instance.instance_id if not record.is_empty() else -1
		slot.refresh()
	item_selected.emit(id, record)

## 将命令结果交给窗口或测试台显示，不在布局层解释业务规则。
func _on_operation_completed(result: InventoryResult) -> void:
	operation_completed.emit(result)
