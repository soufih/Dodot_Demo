extends BaseState

var direct_x

func _on_enter():
	AniPlayer.play("Run")
	_InputController.switch_weapon_pressed.connect(_check.bind("switch_weapon_pressed"))
	
func _on_do(_delta):
	Entity.filp_character()
	direct_x = _InputController.get_move_direction()
	Entity.velocity.x = direct_x*Entity.Speed
	if Entity.velocity.x:
		AniPlayer.play("Run")


	Entity.move_and_slide()

func _on_exit():
	_InputController.switch_weapon_pressed.disconnect(_check.bind("switch_weapon_pressed"))
