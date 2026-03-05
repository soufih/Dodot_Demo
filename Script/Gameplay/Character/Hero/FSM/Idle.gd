extends BaseState

func enter():
	AniPlayer.play("Idle")
	Entity.velocity.x = 0

func do(delta):
	Entity.filp_character()
	Entity.move_and_slide()
