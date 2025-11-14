extends BaseState

@onready var FSM = $".."

func enter():
	FSM.ani.play("Idle")
	FSM.SelfBody.velocity.x = 0
