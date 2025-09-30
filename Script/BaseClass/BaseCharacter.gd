class_name BaseCharacter
extends CharacterBody2D

var Health: int = 100
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
