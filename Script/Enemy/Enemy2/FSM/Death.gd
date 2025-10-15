extends BaseState

@onready var FSM = $".."

func enter():
	FSM.Dead = true
	FSM.ani.play("Death")
