extends Node

@onready var Hero:CharacterBody2D = $"../.."
@onready var WeaponSlot:Array = $"../..".WeaponSlot
@onready var CurrentWeapon: int = $"../..".CurrentWeapon

func switch_weapon():
	CurrentWeapon = (CurrentWeapon+1)%2
	Hero.equip_weapon(WeaponSlot[CurrentWeapon])
	
