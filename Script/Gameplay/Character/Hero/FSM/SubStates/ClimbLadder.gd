extends BaseState

@export var Speed = 250

func enter():
	AniPlayer.play("Climb")

func do(delta:float):
	var direct = Input.get_action_strength("Down")-Input.get_action_strength("Up")
	Entity.velocity = Vector2(0, direct*Speed)
	Entity.move_and_slide()
