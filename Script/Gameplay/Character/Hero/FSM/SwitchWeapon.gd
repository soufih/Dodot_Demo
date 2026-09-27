extends BaseState


func enter():
	switch_weapon()
	SignalBus.weapon_switch.emit()


func switch_weapon():
	var NextWeapon = EquipmentSlotSystem.get_next_weapon_index()
	EquipmentSlotSystem.switch_current_weapon(NextWeapon)
