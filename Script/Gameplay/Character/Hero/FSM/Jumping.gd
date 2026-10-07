extends BaseState



@export_range(0.1, 10000.0, 0.1, "or_greater") var MinJumpHeight: float = 20.0
@export_range(0.1, 10000.0, 0.1, "or_greater") var MaxJumpHeight: float = 30.0

var _can_extend_jump := false
var _jump_gravity: float
var _held_gravity: float


func _on_enter():
	# 合法跳跃输入同步进入此状态；扣除次数后再执行起跳和动画。
	Entity.jump_count_change_requested.emit(-1)
	_InputController.switch_weapon_pressed.connect(_check.bind("switch_weapon_pressed"))
	_can_extend_jump = true

	var min_height := maxf(MinJumpHeight, 0.1)
	var max_height := maxf(MaxJumpHeight, min_height)
	_jump_gravity = get_jump_gravity()
	# 相同起跳速度下，降低按住时的重力，让完整上升高度等于最大高度。
	_held_gravity = _jump_gravity * min_height / max_height
	Entity.velocity.y = -sqrt(2.0 * _jump_gravity * min_height)
	AniPlayer.play("Jump")


func _on_do(delta: float):
	if delta <= 0.0:
		return
	# 松开后本次跳跃不再增高，重新按键不会在空中再次助推。
	if not _InputController.is_jump_held():
		_can_extend_jump = false
	var active_gravity := _held_gravity if _can_extend_jump else _jump_gravity
	var vertical_speed := Entity.velocity.y
	if vertical_speed >= 0.0:
		Entity.end_jump.emit()
		return

	Entity.filp_character()
	Entity.velocity.x = _InputController.get_move_direction() * Entity.Speed
	# 用本帧的平均速度移动；最后一帧只积分到顶点，避免步长改变跳跃高度。
	var ascent_time := minf(delta, -vertical_speed / active_gravity)
	var displacement := vertical_speed * ascent_time + 0.5 * active_gravity * ascent_time * ascent_time
	Entity.velocity.y = displacement / delta
	Entity.move_and_slide()
	Entity.velocity.y = minf(vertical_speed + active_gravity * delta, 0.0)
	if Entity.is_on_ceiling() or Entity.velocity.y >= 0.0:
		Entity.velocity.y = 0.0
		Entity.end_jump.emit()
		return


func _on_exit():
	_InputController.switch_weapon_pressed.disconnect(_check.bind("switch_weapon_pressed"))
	_can_extend_jump = false
	Entity.velocity = Vector2.ZERO


func get_jump_gravity() -> float:
	return maxf(DataLoader.gravity * Entity.JumpSpeedMultiplier * Entity.JumpSpeedMultiplier, 0.001)
