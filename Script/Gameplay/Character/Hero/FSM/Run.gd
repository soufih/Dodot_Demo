extends BaseState

var direct_x

func enter():
	AniPlayer.play("Run")
	
func do(_delta):
	Entity.filp_character()
	direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	#if direct_x == 0:
		#direct_x = 1
	Entity.velocity.x = direct_x*Entity.Speed
	Entity.move_and_slide()
