extends Node

var ReferWeaponPorpertyLog:WeaponPorpertyLog

##加载武器属性日志
func load_weapon():
	ReferWeaponPorpertyLog = load("uid://btq5vs0iwj7jm") as WeaponPorpertyLog
	if !ReferWeaponPorpertyLog:
		push_error("ERRO!WHEN LOADING WEAPON")

##获取武器属性
func get_weapon_porperty(Name:String)->WeaponPorperty:
	if ReferWeaponPorpertyLog:
		if ReferWeaponPorpertyLog.Weapon.get(Name):
			return ReferWeaponPorpertyLog.Weapon[Name]
	return null
