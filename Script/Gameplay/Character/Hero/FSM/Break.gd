extends BaseState


func enter():
	Entity.god_mode.emit()
	AniPlayer.play("Break")
	await AniPlayer.animation_finished
	Entity.end_breaked.emit()
