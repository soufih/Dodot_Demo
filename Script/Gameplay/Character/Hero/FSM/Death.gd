extends BaseState

func enter():
	get_parent().dead = true
	Entity.velocity.x = 0
	Entity.ani.play("Death")
	await AniPlayer.animation_finished
	var NewParent = get_tree().current_scene
	$"../../MainCamera".reparent(NewParent,true)
	Entity.queue_free()
