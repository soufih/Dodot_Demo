extends BaseState


func enter():
	AniPlayer.play("Falling")


func do(delta):
	var direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Entity.velocity.x = direct_x*Entity.Speed
	
	if !Entity.is_on_floor():
		Entity.velocity.y += delta*DataLoader.gravity
	Entity.move_and_slide()
