class_name EquipmentSlotView
extends "res://Script/UI_Script/Inventory/inventory_board_view.gd"
## 固定业务槽位的视图适配器；复用背包拖放协议，位置与大小完全由场景负责。

@export var slot_id: StringName
var _slot_position := Vector2i(-1, -1)

## 解析业务标识后绑定；内部坐标不从节点名称、排列或鼠标位置推断。
func bind(manager: Node, id: String, service_type: int, lookup: Callable) -> void:
	unbind()
	var result: InventoryResult = manager.get_slot_position(id, slot_id)
	if not result.is_ok():
		unbind()
		operation_completed.emit(result)
		return
	_slot_position = result.payload
	super.bind(manager, id, service_type, lookup)

## 解绑时清理旧槽位与图标；禁用输入由共用视图生命周期统一处理。
func unbind() -> void:
	super.unbind()
	_slot_position = Vector2i(-1, -1)
	$Item.hide()
	$Empty.show()

## 更新场景内已有的物品节点与空槽提示，不创建控件，不修改布局。
func refresh() -> void:
	_snapshot = _manager.get_snapshot(container_id)
	var record := record_at(size * 0.5)
	$Item.visible = not record.is_empty()
	$Empty.visible = record.is_empty()
	if not record.is_empty():
		var config: ItemConfig = _lookup.call(record.instance.config_id)
		$Item.display(record.instance, config)
		$Item.set_selected(record.instance.instance_id == _selected_id)

## 仅在槽位自身矩形内返回业务坐标，手动改变节点位置和尺寸不改变绑定。
func _cell_at(point: Vector2) -> Vector2i:
	return _slot_position if Rect2(Vector2.ZERO, size).has_point(point) else Vector2i(-1, -1)

## 装备来源不能按 R 改变方向；拖放到背包时保留原方向与完整占格预览。
func _input(event: InputEvent) -> void:
	if _drag_item == null or not get_viewport().gui_is_dragging():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_R or event.physical_keycode == KEY_R):
		operation_completed.emit(InventoryResult.failure(InventoryResult.Code.UNSUPPORTED, "装备栏不支持旋转"))
		get_viewport().set_input_as_handled()

## 空槽显示业务名称，已有装备沿用物品说明。
func _get_tooltip(at_position: Vector2) -> String:
	if _snapshot.is_empty() or record_at(at_position).is_empty():
		return "%s · 空装备槽" % $Caption.text
	return super._get_tooltip(at_position)
