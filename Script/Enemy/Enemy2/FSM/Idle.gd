extends BaseState

@onready var FSM = $".."

func enter():
	FSM.ani.play("Idle")
	FSM.SelfBody.velocity.y=DataLoader.gravity
	FSM.SelfBody.move_and_slide()
