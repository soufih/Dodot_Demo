extends BaseState

func enter():
	Entity.velocity.x = 0

func do(delta):
	Entity.move_and_slide()
