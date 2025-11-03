class_name BaseWeapon
extends AnimatedSprite2D

var Damage: int
var Kinds: String

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
