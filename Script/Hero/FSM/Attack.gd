extends BaseState

@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@onready var Hero: CharacterBody2D    = $"../.."
var HitBox: Area2D

func enter():
	get_parent().attacking = true
	Hero.velocity = Vector2(0, Hero.velocity.y) 
	ani.play("Attack")
