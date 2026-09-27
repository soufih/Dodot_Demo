extends Node

##伤害检测
func damage_assess(Source:BaseCharacter, Target:BaseCharacter, Attack:DamagePorperty):
	randomize()
	apply_damage(Source, Target, Attack)
	apply_impact_force(Target, Attack)
	#apply_abnormal_condition(Target, Attack)

##施加伤害
func apply_damage(Source:BaseCharacter,Target:BaseCharacter, Attack:DamagePorperty):
	if Target:
		var Damage = calculate_damage(Source, Target, Attack)
		if Damage == -1:
			return
		Target.set_character_current_health(Target.get_character_current_health()-Damage)


##计算最终伤害值
func calculate_damage(Source:BaseCharacter,Target:BaseCharacter, Attack:DamagePorperty)->float:
	if Target:
		var TotalDamage = Attack.Damage
		if Target.get_character_damage_resist().size():
			if Target.get_character_damage_resist().get(Attack.DamageType):
				TotalDamage = TotalDamage - Target.get_character_damage_resist().get(Attack.DamageType)*TotalDamage
		if randf()*100 <= Attack.CriticalHit:
			TotalDamage = TotalDamage * 1.5
		if Source:
			TotalDamage = TotalDamage * (1+Source.sum_damage_enhance()+Source.sum_damage_reduce())
		return TotalDamage
	return -1

##施加冲击力
func apply_impact_force(Target:BaseCharacter, Attack:DamagePorperty):
	if Target:
		
		Target.set_character_toughness(Target.get_character_toughness()-Attack.ImpactForce)


#func apply_abnormal_condition(Target:BaseCharacter, Attack:DamagePorperty):
	#pass

	
class AbnormalEffect:
	func effect_1():
		pass

	func effect_2():
		pass

	func effect_3():
		pass
