extends BaseState

@export var mainCamera: Camera2D

func enter():
	Entity.velocity.x = 0
	Entity.ani.play("Death")
	var NewParent = get_tree().root
	mainCamera.reparent(NewParent,true)
	await AniPlayer.animation_finished
	Entity.queue_free()
