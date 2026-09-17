extends BaseState

@export var mainCamera: Camera2D

func enter():
	Entity.velocity.x = 0
	Entity.ani.play("Death")
	await AniPlayer.animation_finished
	var NewParent = get_tree().root
	mainCamera.reparent(NewParent,true)
	Entity.queue_free()
