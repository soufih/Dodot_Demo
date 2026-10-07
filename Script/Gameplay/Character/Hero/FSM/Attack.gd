extends BaseState

@export var ComboCounter: Timer

## 当前连击次数，可在 on_attack 的接收方读取。
var ComboCount: int = 0
var _attack_generation: int = 0


func _on_enter():
	_attack_generation += 1
	var generation := _attack_generation
	# 只在上一次攻击结束后的窗口内保留计数。
	if ComboCounter.is_stopped() or ComboCounter.time_left <= 0.0:
		ComboCount = 0
	ComboCounter.stop()

	if get_mouse_side() == 1:
		Entity.WeaponPivot.scale.x = 1
		Entity.Spirte.flip_h = false
	elif get_mouse_side() == -1:
		Entity.WeaponPivot.scale.x = -1
		Entity.Spirte.flip_h = true
	Entity.on_attack.emit(ComboCount)

	Entity.velocity.x = 0

	ComboCount = ComboCount+1
	if AniPlayer.is_playing():
		await AniPlayer.animation_finished
	# 离开状态后，旧等待即使被后续动画唤醒也不能结束新的攻击。
	if generation != _attack_generation:
		return

	ComboCounter.start()
	Entity.end_attack.emit()


func _on_exit():
	_attack_generation += 1
	if AniPlayer.current_animation.contains("Attack"):
		AniPlayer.stop()
	AniPlayer.speed_scale = 1.0


## 鼠标在人物左侧返回 -1，右侧返回 1；横坐标相同时返回 1。
func get_mouse_side() -> int:
	var mouse_position: Vector2 = Entity.get_global_mouse_position()
	return -1 if mouse_position.x < Entity.global_position.x else 1
