extends BaseState

@onready var FSM = $".."

func enter():
	FSM.Breaked = true
	FSM.Attacking = false
	FSM.ani.play("Break")
	await FSM.ani.animation_finished
	FSM.SelfBody.Toughness = 100
	FSM.Breaked = false
