class_name BaseCharacter
extends CharacterBody2D

var Health: int = 100
var SpecialStateResist: Array


func Beginning():
	add_to_group("Chr")
	
func Running():
	pass
	
func TakeHit(AniPlayer: AnimationPlayer):
	AniPlayer.play("TakeHit")
#	添加其他受击逻辑
	
func Death(AniPlayer: AnimationPlayer):
	AniPlayer.play("Death")
#	添加其他死亡逻辑
