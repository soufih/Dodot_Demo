extends BaseState

@onready var FSM = $".."

func enter():
	FSM.Dead = true
	FSM.ani.play("Death")
	await FSM.ani.animation_finished
	EnemyManager.drop(FSM.SelfBody.name, FSM.SelfBody.global_position)
	FSM.SelfBody.queue_free()
