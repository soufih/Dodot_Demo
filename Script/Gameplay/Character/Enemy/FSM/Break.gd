extends BaseState

signal is_breaked(i:bool)

func enter():
	AniPlayer.play("Break")
	await AniPlayer.animation_finished
	Entity.Toughness = 100
	is_breaked.emit(false)
