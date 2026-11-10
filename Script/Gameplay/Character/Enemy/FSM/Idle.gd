extends BaseState

func _on_enter():
	AniPlayer.play("Idle")
	(Entity as BaseEnemy).set_move_direction(0, 0.0)

func _on_do(delta: float):
	Entity.velocity.y += DataLoader.gravity * delta
	Entity.move_and_slide()
