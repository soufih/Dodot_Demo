class_name BaseWeapon
extends AnimatedSprite2D

var Porperty:DamagePorperty

func _ready() -> void:
	Porperty =  WeaponManager.get_weapon_porperty(self.name)
	add_to_group("Weapon")

func excute_attack():
	before_attack() 

	during_attack()

	after_attack()

func before_attack():
	pass
	
func during_attack():
	pass
	
func after_attack():
	pass
