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
## 从角色装备组件查询当前武器，输入层不保存第二份装备状态。
@export var equipment: PlayerEquipmentComponent

var buffered_actions: Dictionary = {}
var move_direction := 0.0
var _local_ban := false
var _was_banned := false
var is_banned: bool:
	get: return _local_ban or UIManager.gameplay_blocked

func _ready() -> void:
	SignalBus.input_control.connect(ban_input)
	UIManager.state_changed.connect(_on_ui_state_changed)
	_on_ui_state_changed()


func _process(_delta: float) -> void:
	if is_banned:
		return
	
	if Input.is_action_pressed("MoveLeft"):
		move_left_pressed.emit()

	if Input.is_action_pressed("MoveRight"):
		move_right_pressed.emit()
	
	clear_expired_actions()


## 未被界面处理的操作才进入游戏；空手不缓存攻击，也不发送攻击请求。
func _unhandled_input(event: InputEvent) -> void:
	if is_banned:
		return
	
	if event.is_action_pressed("Attack") and equipment != null and equipment.get_current_weapon() != -1:
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
	_local_ban = state
	_on_ui_state_changed()


func _on_ui_state_changed() -> void:
	var blocked := is_banned
	if blocked and not _was_banned:
		buffered_actions.clear()
		move_direction = 0.0
		move_left_released.emit()
		move_right_released.emit()
		input_banned.emit()
	_was_banned = blocked


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
