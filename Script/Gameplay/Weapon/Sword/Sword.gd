extends BaseWeapon


var SwordComponent: WeaponComponent = WeaponComponent.new()

func _on_attack(Movement:int) -> void:
	match Movement:
		0:
			Ani.play("Attack")
		1:
			Ani.play("Attack1")
		2:
			Ani.play("Attack2")

func before_attack(_Movement:int):
	pass


func during_attack(_Movement:int):
	SwordComponent.damage_module(Hitboxs.get_child(_Movement), _Movement, Porperty, EquipmentOwner)


func after_attack(_Movement:int):
	pass
