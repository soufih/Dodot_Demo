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

##获取武器名称
func get_weapon_name(Name:String)->String:
	if ReferWeaponPorpertyLog:
		if ReferWeaponPorpertyLog.Weapon.get(Name):
			return ReferWeaponPorpertyLog.Weapon[Name].Name
	return ""

##获取武器类型
func get_weapon_type(Name:String)->ENUM.WeaponType:
	if ReferWeaponPorpertyLog:
		if ReferWeaponPorpertyLog.Weapon.get(Name):
			return ReferWeaponPorpertyLog.Weapon[Name].Type
	return ENUM.WeaponType.Sword

##获取武器基础伤害
func get_weapon_basedamage(Name:String)->DamagePorperty:
	if ReferWeaponPorpertyLog:
		if ReferWeaponPorpertyLog.Weapon.get(Name):
			return ReferWeaponPorpertyLog.Weapon[Name].BaseDamage
	return null

##获取武器攻击速度
func get_weapon_attackspeed(Name:String)->float:
	if ReferWeaponPorpertyLog:
		if ReferWeaponPorpertyLog.Weapon.get(Name):
			return ReferWeaponPorpertyLog.Weapon[Name].AttackSpeed
	return 1.0