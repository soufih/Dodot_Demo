extends BaseState

func enter():
	Entity.on_attack.emit()
	Entity.velocity.x = 0
	AniPlayer.play("Attack")

	await AniPlayer.animation_finished
	Entity.end_attack.emit()
