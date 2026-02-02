extends BaseState


func enter():
	get_parent().breaked = true
	Entity.god_mode.emit()
	get_parent().attacking = false
	AniPlayer.play("Break")
	await AniPlayer.animation_finished
	Entity.Toughness = Entity.MaxToughness
	get_parent().breaked = false
