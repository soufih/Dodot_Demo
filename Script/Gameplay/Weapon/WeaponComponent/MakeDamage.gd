class_name MakeDamage
extends WeaponAction


func execute(context: WeaponContext):
	damage_module(context.hitbox, context.weapon_data, context.attacker, context.combo_count)

##伤害模块
func damage_module(Hitbox:Area2D, Porperty:WeaponPorperty, Attacker:BaseCharacter, Combo:int) -> void:
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Enemy"):
			var Damage:DamagePorperty = Porperty.BaseDamage.duplicate(true) 
			Damage.Damage *= Porperty.DamageMultipler[Combo]
			DamageSystem.damage_assess(Attacker,body, Damage)
