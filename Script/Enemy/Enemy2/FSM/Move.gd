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

	if BarrierDetect.has_overlapping_areas():
		FSM.SelfBody.scale.x= -FSM.SelfBody.scale.x
		Direct= -Direct
		
	
	FSM.SelfBody.velocity.x = Direct*Speed
	
	FSM.SelfBody.move_and_slide()
