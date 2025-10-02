class_name BaseCharacter
extends CharacterBody2D

@export var CurrentHealth: int = 100
@export var MaxHealth: int = 100
var SpecialStateResist: Array


func beginning():
	add_to_group("Chr")
	
func running():
	pass
	
func take_hit(AniPlayer: AnimationPlayer):
	AniPlayer.play("TakeHit")
#	添加其他受击逻辑
	
func death(AniPlayer: AnimationPlayer):
	AniPlayer.play("Death")
#	添加其他死亡逻辑

func get_character_current_health()->int:
	return CurrentHealth
	
func get_character_max_health()->int:
	return MaxHealth
