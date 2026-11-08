extends BaseState

func _on_enter():
	AniPlayer.play("Idle")
	Entity.velocity.x = 0
	Substates["look"].enter()
	if !_InputController.switch_weapon_pressed.is_connected(_check):
		_InputController.switch_weapon_pressed.connect(_check.bind("switch_weapon_pressed"))

func _on_do(delta):
	Entity.filp_character()
	Entity.move_and_slide()
	Substates["look"].do(delta)

func _on_exit():
	Substates["look"].exit()
	_InputController.switch_weapon_pressed.disconnect(_check.bind("switch_weapon_pressed"))
