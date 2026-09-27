extends BaseState

@export var ComboCounter: Timer
@export var maxCombo:int = 2
@export var ComboAnimations: Array[StringName] = [&"Attack", &"Attack2"]

## 当前连击次数，可在 on_attack 的接收方读取。
var ComboCount: int = 0


func enter():
	Entity.breaked.connect(break_attack)
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

	AniPlayer.play(ComboAnimations[ComboCount])
	
	ComboCount = (ComboCount+1)%maxCombo
	await AniPlayer.animation_finished
	
	ComboCounter.start()
	Entity.end_attack.emit()


func break_attack():
	if AniPlayer.current_animation in ComboAnimations:
		AniPlayer.stop()
	Entity.end_attack.emit()


func exit():
	Entity.breaked.disconnect(break_attack)


## 鼠标在人物左侧返回 -1，右侧返回 1；横坐标相同时返回 1。
func get_mouse_side() -> int:
	var mouse_position: Vector2 = Entity.get_global_mouse_position()
	return -1 if mouse_position.x < Entity.global_position.x else 1
