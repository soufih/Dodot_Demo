extends BaseState

@onready var BarrierDetect = $"../../BarrierDetect"
@onready var FSM = $".."
@onready var Spirte = $"../../AnimatedSprite2D"

@export var Speed:int

var HasBarrier:bool = false
var Direct = Vector2i.RIGHT.x

func enter():
	FSM.ani.play("Move")
	
func do(delta):
	for body in $"../../HateArea".get_overlapping_bodies():
		if body.is_in_group("Hero"):
			var HeroPos = body.global_position
			var SelfPos = FSM.SelfBody.global_position
			if FSM.SelfBody.scale.y*(HeroPos.x-SelfPos.x) > 0:
				FSM.SelfBody.scale.x = abs(FSM.SelfBody.scale.x)
			else:
				FSM.SelfBody.scale.x = -abs(FSM.SelfBody.scale.x)
			
			if HeroPos > SelfPos:
				$"../Move".Direct = 1
			else:
				$"../Move".Direct = -1
	
	if BarrierDetect.has_overlapping_areas():
		FSM.SelfBody.scale.x= -FSM.SelfBody.scale.x
		Direct= -Direct

	FSM.SelfBody.velocity.x = Direct*Speed

	FSM.SelfBody.move_and_slide()
