extends Node
var WeaponPorpertyLog:WeaponPorperty
var EnemyPorpertyLog:EnemyPorperty

func _ready() -> void:
	WeaponPorpertyLog = load("uid://cpjcvujytunnw")
	EnemyPorpertyLog = load("uid://2srf8bdj186")


func get_weapon_porperty(Name:String)->DamagePorperty:
	if WeaponPorpertyLog:
		if WeaponPorpertyLog.Weapon[Name]:
			return WeaponPorpertyLog.Weapon[Name]
	return null


func get_enemy_porperty(Name:String)->DamagePorperty:
	if EnemyPorpertyLog:
		if EnemyPorpertyLog.Enemy[Name]:
			return EnemyPorpertyLog.Enemy[Name]
	return null
