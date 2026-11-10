extends BaseState

const MainCameraScript = preload("res://Script/Gameplay/Character/Hero/MainCamera.gd")

@export var camera: MainCameraScript
## 长按时的镜头偏移距离（像素）：W 向上，S 向下。
@export_range(0.0, 1000.0, 1.0, "or_greater") var look_down_distance: float = 160.0
@export_range(0.0, 3.0, 0.05, "or_greater") var look_hold_duration: float = 0.4
@export_range(1.0, 2000.0, 1.0, "or_greater") var look_move_speed: float = 320.0

var _up_hold_time: float = 0.0
var _down_hold_time: float = 0.0
var _look_displacement: float = 0.0


func _on_enter() -> void:
	_up_hold_time = 0.0
	_down_hold_time = 0.0
	_look_displacement = 0.0


func _on_do(delta: float) -> void:
	var accepts_input := camera.is_current() and not UIManager.has_blocking_ui() \
		and Entity.CurrentHealth > 0.0 and not _InputController.is_banned
	var up_pressed := accepts_input and Input.is_action_pressed("Up")
	var down_pressed := accepts_input and Input.is_action_pressed("Down")
	_up_hold_time = _up_hold_time + delta if up_pressed else 0.0
	_down_hold_time = _down_hold_time + delta if down_pressed else 0.0
	var target: float = 0.0
	if up_pressed and not down_pressed and _up_hold_time >= look_hold_duration:
		target = -look_down_distance
	elif down_pressed and not up_pressed and _down_hold_time >= look_hold_duration:
		target = look_down_distance
	_look_displacement = move_toward(_look_displacement, target, look_move_speed * delta)
	camera.set_look_displacement(_look_displacement)


func _on_exit() -> void:
	_up_hold_time = 0.0
	_down_hold_time = 0.0
	_look_displacement = 0.0
	camera.set_look_displacement(0.0)
