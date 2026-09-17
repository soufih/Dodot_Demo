extends Node
class_name InputController

signal when_attack_tigger
signal move_left_pressed
signal move_left_released
signal move_right_pressed
signal move_right_released
signal jump_pressed

@export_range(0.0, 1.0, 0.01) var input_buffer_duration: float = 1

var buffered_actions: Dictionary = {}
var move_direction := 0.0
var is_banned:bool = false

func _ready() -> void:
	SignalBus.input_control.connect(ban_input)

func _process(_delta: float) -> void:
	clear_expired_actions()


func _input(event: InputEvent) -> void:
	if is_banned:
		return
	
	if event.is_action("Attack"):
		buffer_action("Attack")
		when_attack_tigger.emit()
	
	if event.is_action_pressed("MoveLeft"):
		buffer_action("Run")
		move_left_pressed.emit()
	
	if event.is_action_released("MoveLeft"):
		move_left_released.emit()

	if event.is_action_pressed("MoveRight"):
		buffer_action("Run")
		move_right_pressed.emit()
	
	if event.is_action_released("MoveRight"):
		move_right_released.emit()
	
	if event.is_action_pressed("Jump"):
		buffer_action("Jumping")
		jump_pressed.emit()


func ban_input(state:bool):
	is_banned = state
	print(is_banned)


func get_move_direction() -> float:
	if is_banned:
		return 0
	return Input.get_axis(&"MoveLeft", &"MoveRight")


func buffer_action(action: StringName) -> void:
	buffered_actions[action] = Time.get_ticks_msec()


func has_buffered_action(action: StringName) -> bool:
	if not buffered_actions.has(action):
		return false

	var input_time: int = buffered_actions[action]
	var buffer_duration_msec := int(input_buffer_duration * 1000.0)
	if Time.get_ticks_msec() - input_time > buffer_duration_msec:
		buffered_actions.erase(action)
		return false

	return true


func consume_buffered_action(action: StringName) -> bool:
	if not has_buffered_action(action):
		return false
	print("Buffered Action:" + action)
	buffered_actions.erase(action)
	return true


func clear_buffered_action(action: StringName) -> void:
	buffered_actions.erase(action)


func clear_expired_actions() -> void:
	for action in buffered_actions.keys():
		if not has_buffered_action(action):
			continue
