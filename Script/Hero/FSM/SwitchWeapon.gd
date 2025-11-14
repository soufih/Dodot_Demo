extends Node

@onready var Hero:CharacterBody2D = $"../.."
@onready var CurrentWeapon: int = $"../..".CurrentWeapon

func switch_weapon():
	CurrentWeapon = (CurrentWeapon+1)%2
	var WeaponSlot = EquipmentSlotSystem.get_weapon_slot()
	if WeaponSlot.get(CurrentWeapon):
		Hero.equip_weapon(WeaponSlot[CurrentWeapon])
	
