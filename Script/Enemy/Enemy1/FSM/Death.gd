extends BaseState

@onready var FSM = $".."

func enter():
	FSM.Dead = true
	FSM.ani.play("Death")
	await FSM.ani.animation_finished
	DroppedItemSystem.create_dropped_item([[2, 1]], FSM.SelfBody.global_position)
	FSM.SelfBody.queue_free()
