extends BaseState



var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var holdTime: float
var maxHoldtime: float = 0.4

func enter():
	if !Entity.is_on_floor():
		return

	holdTime = 0
	var jump_gravity := get_jump_gravity()
	Entity.velocity.y = -sqrt(2.0 * gravity * Entity.JumpHeight)
	Entity.velocity.y = -sqrt(2.0 * jump_gravity * Entity.JumpHeight)
	AniPlayer.play("Jump")


func do(delta: float):
	var jump_gravity := get_jump_gravity()
	if Input.is_action_pressed("Jump") and holdTime < maxHoldtime:
		holdTime += delta
		var jump_speed := sqrt(2.0 * jump_gravity * Entity.JumpHeight)
		var max_jump_speed := sqrt(2.0 * jump_gravity * Entity.MaxJumpHeight)
		var hold_acceleration := (max_jump_speed - jump_speed) / maxHoldtime
		Entity.velocity.y = min(Entity.velocity.y - hold_acceleration * delta, -max_jump_speed)

	Entity.filp_character()
	if Entity.velocity.y < 0:
		Entity.velocity.y = Entity.velocity.y + gravity * delta
		Entity.velocity.y = Entity.velocity.y + jump_gravity * delta
	else:
		Entity.velocity.y = 0
		Entity.end_jump.emit()
	
	var direct_x = _InputController.get_move_direction()
	Entity.velocity.x = direct_x * Entity.Speed
	
	Entity.move_and_slide()


func exit():
	Entity.velocity = Vector2(0, 0)


func get_jump_gravity() -> float:
	return gravity * Entity.JumpSpeedMultiplier * Entity.JumpSpeedMultiplier
