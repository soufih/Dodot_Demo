extends Resource
class_name DamagePorperty

@export var Damage: float
@export var DamageType: ENUM.DamageType
@export var ImpactForce: float
@export var AbnormalDamage: Array[ENUM.AbnormalType]
@export var CriticalHit: float


func setter(_Damage: float, _DamageType: ENUM.DamageType, _ImpactForce: float, _AbnormalDamage: Array[ENUM.AbnormalType], _CriticalHit: float) -> void:
	self.Damage = _Damage
	self.DamageType = _DamageType
	self.ImpactForce = _ImpactForce
	self.AbnormalDamage = _AbnormalDamage
	self.CriticalHit = _CriticalHit

func traverse_damage_property() -> String:
	var result: String = "Damage: %f\nDamageType: %s\nImpactForce: %f\nCriticalHit: %f\nAbnormalDamage: " % [Damage, str(DamageType), ImpactForce, CriticalHit]
	for abnormal in AbnormalDamage:
		result += "%s " % str(abnormal)
	return result
