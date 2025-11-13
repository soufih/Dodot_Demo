extends Node
var PorpertyLog:WeaponPorperty

func _ready() -> void:
	PorpertyLog = load("res://Rescource/WeaponPorpertyLog.tres")

func get_weapon_porperty_log()->Dictionary:
	if PorpertyLog:
		return PorpertyLog.Weapon
	return {}
