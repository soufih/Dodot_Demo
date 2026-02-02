extends BaseState


func enter():
	AniPlayer.play("Idle")
	Entity.velocity.x = 0
	Entity.velocity.y = DataLoader.gravity
	Entity.move_and_slide()
