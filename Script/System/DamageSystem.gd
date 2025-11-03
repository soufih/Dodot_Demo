extends Node


func damage_assess(Source:BaseCharacter, Target:BaseCharacter, Attack:DamagePorperty):
	apply_damage(Target, Attack)
	death_assess(Target)
	apply_impact_force(Target, Attack)
	apply_abnormal_condition(Target, Attack)
	death_assess(Target)
	
func apply_damage(Target:BaseCharacter, Attack:DamagePorperty):
	var Damage = calculate_damage(Target, Attack)
	Target.set_character_current_health(Target.get_character_current_health()-Damage)

func calculate_damage(Target:BaseCharacter, Attack:DamagePorperty)->float:
	return -1

func apply_impact_force(Target:BaseCharacter, Attack:DamagePorperty):
	pass

func apply_abnormal_condition(Target:BaseCharacter, Attack:DamagePorperty):
	pass
	
func death_assess(Target:BaseCharacter):
	pass
	
class AbnormalEffect:
	func effect_1():
		pass

	func effect_2():
		pass

	func effect_3():
		pass
