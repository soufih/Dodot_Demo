extends BaseState

var _generation: int = 0

func _on_enter():
	_generation += 1
	var generation := _generation
	Entity.velocity.x = 0
	AniPlayer.play("Break")
	var finished_animation: StringName = await AniPlayer.animation_finished
	if generation != _generation or finished_animation != &"Break":
		return
	Entity.Toughness = Entity.MaxToughness
	Entity.end_breaked.emit()

func _on_exit():
	_generation += 1
	if AniPlayer.current_animation == "Break":
		AniPlayer.stop()
