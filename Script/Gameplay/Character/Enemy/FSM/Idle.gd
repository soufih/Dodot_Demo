extends BaseState

func _on_enter():
	AniPlayer.play("Idle")
	Entity.velocity.x = 0

func _on_do(delta: float):
	Entity.velocity.y += DataLoader.gravity * delta
	Entity.move_and_slide()
