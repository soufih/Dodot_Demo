extends BaseWeapon

var SwordComponent: WeaponComponent = WeaponComponent.new()


func _on_attack(Movement:int) -> void:
	excute_attack(0)


func during_attack(_Movement:int):
	SwordComponent.damage_module(Hitboxs.get_child(_Movement), _Movement, Porperty, EquipmentOwner)


func after_attack(_Movement:int):
	SwordComponent.spawn_bullet(
		WeaponManager.get_bullet_scene("SwordSlash"),
		EquipmentOwner.global_position,
		EquipmentOwner.facing_direction,
		800,
		Porperty,
		EquipmentOwner
	)
