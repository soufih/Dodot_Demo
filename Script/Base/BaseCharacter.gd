class_name BaseCharacter
extends CharacterBody2D

signal health_changed

@export var MaxHealth: float = 100
var CurrentHealth: float = MaxHealth
var DamageResist: Array[float]
var AbnormalConditionResist: Array[float]


func beginning():
	add_to_group("Chr")
	
func running(delta: float):
	pass
	
func physics_running(delta: float):
	pass
	
func take_hit(AniPlayer: AnimationPlayer):
	AniPlayer.play("TakeHit")
	health_changed.emit()
#	添加其他受击逻辑
	
func death(AniPlayer: AnimationPlayer):
	AniPlayer.play("Death")
#	添加其他死亡逻辑

func get_character_current_health()->float:
	return CurrentHealth
	
func get_character_max_health()->float:
	return MaxHealth
	
func get_character_damage_resist()->Array:
	return DamageResist

func get_character_abnormal_condition_resist()->Array:
	return AbnormalConditionResist

func set_character_current_health(CH: float):
	self.CurrentHealth = CH
	
func set_character_max_health(MH:float):
	self.MaxHealth = MH
