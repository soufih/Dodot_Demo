extends BaseState

@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@onready var Hero: CharacterBody2D    = $"../.."
var HitBox: Area2D

func enter():
	if $"../../WeaponPosition".get_child(0) == null:
		return
	get_parent().attacking = true
	Hero.velocity = Vector2(0, Hero.velocity.y) 
	ani.play("Attack")
	$"../../WeaponPosition".get_child(0).excute_attack()
