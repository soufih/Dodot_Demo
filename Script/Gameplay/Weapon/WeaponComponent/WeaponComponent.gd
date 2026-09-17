extends Node
class_name WeaponComponent

##伤害模块
func damage_module(Hitbox:Area2D, Movement:int, Porperty:WeaponPorperty, EquipmentOwner:BaseCharacter) -> void:
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Enemy"):
			var Damage:DamagePorperty = Porperty.BaseDamage.duplicate(true)
			Damage.Damage = Damage.Damage * Porperty.DamageMultipler[Movement]
			DamageSystem.damage_assess(EquipmentOwner,body, Damage)
