extends Node

var WeaponPorpertyLog:WeaponPorperty

func _ready() -> void:
	load_weapon()

func load_weapon():
	WeaponPorpertyLog = load("uid://cpjcvujytunnw")
	if !WeaponPorpertyLog:
		push_error("ERRO!WHEN LOADING WEAPON")

func get_weapon_porperty(Name:String)->DamagePorperty:
	if WeaponPorpertyLog:
		if WeaponPorpertyLog.Weapon.get(Name):
			return WeaponPorpertyLog.Weapon[Name]
	return null
