extends BaseState
@onready var ani: AnimationPlayer     = $"../../AnimationPlayer"
@onready var Hero: CharacterBody2D = $"../.."


func enter():
	ani.play("Falling")


func do(delta):
	var direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Hero.velocity.x = direct_x*Hero.Speed
	
	if !Hero.is_on_floor():
		Hero.velocity.y += delta*DataLoader.gravity
	Hero.move_and_slide()
