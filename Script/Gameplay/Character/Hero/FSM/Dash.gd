extends BaseState

@export_range(0.1, 10000.0, 0.1, "or_greater") var speed := 900
## 冲刺距离（像素）；实际持续时间由距离 / 速度计算。
@export_range(0.0, 10000.0, 0.1, "or_greater") var distance := 300
var remaining_duration := 0.0
var initial_velocity := Vector2.ZERO

func _on_enter() -> void:
	initial_velocity = Entity.velocity
	var direction := _InputController.get_move_direction()
	if is_zero_approx(direction):
		direction = -1.0 if Entity.Spirte.flip_h else 1.0
	Entity.Spirte.flip_h = direction < 0.0
	Entity.WeaponPivot.scale.x = direction
	var dash_speed := maxf(speed, 0.1)
	Entity.velocity = Vector2(direction * dash_speed, 0.0)
	remaining_duration = maxf(distance, 0.0) / dash_speed
	if AniPlayer.has_animation(&"Dash"):
		AniPlayer.play(&"Dash")

func _on_do(delta: float) -> void:
	if delta <= 0.0:
		return
	# 移动后调用工具检测碰撞，由状态发出结束信号。
	var _speed := Entity.velocity.x
	Entity.velocity.x = _speed * minf(delta, remaining_duration) / delta
	Entity.move_and_slide()
	Entity.velocity.x = _speed
	remaining_duration = maxf(0.0, remaining_duration - delta)
	if Entity.is_on_wall() or remaining_duration <= 0.0:
		finish()

func finish() -> void:
	if Entity.is_on_floor():
		Entity.end_dash_ground.emit()
	else:
		Entity.end_dash_air.emit()

func _on_exit() -> void:
	Entity.velocity = Vector2(0.0, 0.0 if Entity.is_on_floor() else maxf(initial_velocity.y, 0.0))
	remaining_duration = 0.0
