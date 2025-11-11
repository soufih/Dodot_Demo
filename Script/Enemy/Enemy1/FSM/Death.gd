extends BaseState

@onready var FSM = $".."

func enter():
	FSM.Dead = true
	FSM.ani.play("Death")
	await FSM.ani.animation_finished
	FSM.SelfBody.queue_free()
