extends BaseState


## 通过角色装备组件切换当前武器，只有实际切换成功才发出旧有表现通知。
func _on_enter():
	var result := switch_weapon()
	if result.is_ok():
		SignalBus.weapon_switch.emit()


## 状态机不直接读取或写入装备容器。
func switch_weapon() -> InventoryResult:
	var equipment := PlayerEquipmentComponent.find_for(Entity)
	if equipment == null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "角色没有装备组件")
	return equipment.switch_weapon()
