extends BaseState

@onready var Hero: CharacterBody2D    = $"../.."
@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
var direct_x

func enter():
	ani.play("Run")
	
func do(_delta):
	direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")

	Hero.velocity.x = direct_x*Hero.Speed
	Hero.move_and_slide()
