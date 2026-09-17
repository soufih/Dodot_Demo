extends BaseState

var direct_x

func enter():
	AniPlayer.play("Run")
	
func do(_delta):
	Entity.filp_character()
	direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Entity.velocity.x = direct_x*Entity.Speed
	if Entity.velocity.x:
		AniPlayer.play("Run")
	else:
		AniPlayer.play("Idle")

	Entity.move_and_slide()
