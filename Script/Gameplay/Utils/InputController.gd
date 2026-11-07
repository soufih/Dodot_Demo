extends Node
class_name InputController

signal when_attack_tigger
signal move_left_pressed
signal move_left_released
signal move_right_pressed
signal move_right_released
signal jump_pressed
signal dash_pressed
signal switch_weapon_pressed
signal input_banned
signal interact_pressed

@export_range(0.0, 1.0, 0.01) var input_buffer_duration: float = 1
@export var ability_controller: AbilityController

var buffered_actions: Dictionary = {}
var move_direction := 0.0
var is_banned:bool = false

func _ready() -> void:
	SignalBus.input_control.connect(ban_input)


func _process(_delta: float) -> void:
	if is_banned:
		return
	
	if Input.is_action_pressed("MoveLeft"):
		move_left_pressed.emit()

	if Input.is_action_pressed("MoveRight"):
		move_right_pressed.emit()
	
	clear_expired_actions()


func _unhandled_input(event: InputEvent) -> void:
	if is_banned:
		return
	
	if event.is_action_pressed("Attack") && false:
		buffer_action("Attack")
		when_attack_tigger.emit()
	
	if event.is_action_released("MoveLeft"):
		move_left_released.emit()
	
	if event.is_action_released("MoveRight"):
		move_right_released.emit()
	
	if event.is_action_pressed("Jump"):
		jump_pressed.emit()
	
	if event.is_action_pressed("SwitchWeapon"):
		switch_weapon_pressed.emit()
	
	if event.is_action_pressed("Interact"):
		interact_pressed.emit()

	if event.is_action_pressed("Dash"):
		ability_controller.request_activate("dash")

func ban_input(state:bool):
	is_banned = state


func get_move_direction() -> float:
	if is_banned:
		return 0
	return Input.get_axis(&"MoveLeft", &"MoveRight")


func get_climb_direction() -> float:
	if is_banned:
		return 0.0
	return Input.get_axis(&"Up", &"Down")


func is_jump_held() -> bool:
	return not is_banned and Input.is_action_pressed(&"Jump")


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
	#print("Buffered Action:" + action)
	buffered_actions.erase(action)
	return true


func clear_buffered_action(action: StringName) -> void:
	buffered_actions.erase(action)


func clear_expired_actions() -> void:
	for action in buffered_actions.keys():
		if not has_buffered_action(action):
			continue
