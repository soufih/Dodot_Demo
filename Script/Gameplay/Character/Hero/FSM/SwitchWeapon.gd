extends BaseState

@onready var CurrentWeapon: int = $"../..".CurrentWeapon

func switch_weapon():
	CurrentWeapon = (CurrentWeapon+1)%2
	var WeaponSlot = EquipmentSlotSystem.get_weapon_slot()
	if WeaponSlot.get(CurrentWeapon):
		Entity.equip_weapon(WeaponSlot[CurrentWeapon])
	
