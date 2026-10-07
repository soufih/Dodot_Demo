extends BaseState

func _on_enter():
	AniPlayer.play("Run")

func _on_do(_delta: float):
