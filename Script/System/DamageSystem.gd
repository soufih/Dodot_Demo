extends Node


func damage_assess(Source:BaseCharacter, Target:BaseCharacter, Attack:DamagePorperty):
	randomize()
	apply_damage(Source, Target, Attack)
	#death_assess(Target)
	apply_impact_force(Target, Attack)
	#break_assess(Target)
	#apply_abnormal_condition(Target, Attack)
	#death_assess(Target)
	
func apply_damage(Source:BaseCharacter,Target:BaseCharacter, Attack:DamagePorperty):
	if Target && Source:
		var Damage = calculate_damage(Source, Target, Attack)
		if Damage == -1:
			return
		Target.set_character_current_health(Target.get_character_current_health()-Damage)
		Target.take_damage()
	#其他受伤反馈逻辑

func calculate_damage(Source:BaseCharacter,Target:BaseCharacter, Attack:DamagePorperty)->float:
	if Target && Source:
		var TotalDamage = (Target.get_character_damage_resist()[Attack.DamageType]+1)*Attack.Damage
		if randf()*100 <= Attack.CriticalHit:
			TotalDamage = TotalDamage * 1.5
		TotalDamage = TotalDamage * (1+Source.sum_damage_enhance()+Source.sum_damage_reduce())
		return TotalDamage
	return -1

func apply_impact_force(Target:BaseCharacter, Attack:DamagePorperty):
	if Target:
		Target.set_character_toughness(Target.get_character_toughness()-Attack.ImpactForce)
		Target.toughness_reduced()
	
#func break_assess(Target:BaseCharacter):
	#if Target:
		#if Target.get_character_toughness() <= 0:
			#Target.breaked()

#func apply_abnormal_condition(Target:BaseCharacter, Attack:DamagePorperty):
	#pass
	
#func death_assess(Target:BaseCharacter):
	#if Target:
		#if Target.get_character_current_health() <= 0:
			#Target.death()
	
class AbnormalEffect:
	func effect_1():
		pass

	func effect_2():
		pass

	func effect_3():
		pass
