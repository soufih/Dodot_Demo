extends BaseState

@onready var Hero: CharacterBody2D    = $"../.."
@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@export var JumpSpeed: int = -500
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func enter():
	get_parent().jumping = true
	Hero.velocity.y += JumpSpeed
	ani.play("Jump")
	

func do(delta: float):
	if Hero.velocity.y < 0:
		Hero.velocity.y = Hero.velocity.y + gravity*delta
	else:
		Hero.velocity.y = 0
		get_parent().jumping = false
	print(Hero.velocity.y)
	
	var direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Hero.velocity.x = direct_x*Hero.Speed
	
	Hero.move_and_slide()
