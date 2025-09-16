extends BaseState

@onready var Hero: CharacterBody2D    = $"../.."
@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@export var JumpSpeed: int = -300
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func enter():
	get_parent().jumping = true
	ani.play("Prejump")
	Hero.velocity =Vector2(Hero.velocity.x, JumpSpeed)
	Hero.move_and_slide()
	ani.play("Jump")
	
func do():
	pass
