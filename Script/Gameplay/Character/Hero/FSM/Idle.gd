extends BaseState

func _on_enter():
	AniPlayer.play("Idle")
	Entity.velocity.x = 0
	if !_InputController.switch_weapon_pressed.is_connected(_check):
		_InputController.switch_weapon_pressed.connect(_check.bind("switch_weapon_pressed"))

func _on_do(delta):
	Entity.filp_character()
	Entity.move_and_slide()

func _on_exit():
	_InputController.switch_weapon_pressed.disconnect(_check.bind("switch_weapon_pressed"))
