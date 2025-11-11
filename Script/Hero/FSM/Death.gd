extends BaseState

@onready var FSM = $".."

func enter():
	FSM.dead = true
	FSM.ani.play("Death")
	await FSM.ani.animation_finished
	var NewParent = get_tree().current_scene
	$"../../Camera2D".reparent(NewParent,true)
	FSM.Hero.queue_free()
