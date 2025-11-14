extends BaseState

@onready var FSM = $".."

func enter():
	FSM.breaked = true
	FSM.Hero.god_mode.emit()
	FSM.Hero.velocity.x = 0
	FSM.attacking = false
	FSM.ani.play("Break")
	await FSM.ani.animation_finished
	FSM.Hero.Toughness = FSM.Hero.MaxToughness
	FSM.breaked = false
