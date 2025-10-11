extends BaseState

@onready var Hero: CharacterBody2D    = $"../.."
@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@export var SPEED: int = 50
var direct_x

func enter():
	ani.play("Run")
	
func do(delta):
	direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")

	Hero.velocity = Vector2(direct_x*SPEED, Hero.velocity.y)
	Hero.move_and_slide()
