extends Node

@onready var _InputController = $"../InputController"
@onready var Hero = $".."

@export var Current:BaseState
var Previous: BaseState


func _ready() -> void:
	_InputController.move_left_pressed.connect(_check.bind("move_left_pressed"))
	_InputController.move_left_released.connect(_check.bind("move_left_released"))
	_InputController.move_right_pressed.connect(_check.bind("move_right_pressed"))
	_InputController.move_right_released.connect(_check.bind("move_right_released"))
	_InputController.jump_pressed.connect(_check.bind("jump_pressed"))
	_InputController.when_attack_tigger.connect(_check.bind("when_attack_tigger"))
	_InputController.input_banned.connect(_check.bind("input_banned"))
	
	
	Hero.is_static.connect(_check.bind("is_static"))
	Hero.on_floor.connect(_check.bind("on_floor"))
	Hero.is_fall.connect(_check.bind("is_fall"))
	Hero.end_jump.connect(_check.bind("end_jump"))
	Hero.end_attack.connect(_check.bind("end_attack"))
	Hero.death.connect(_check.bind("death"))
	Hero.breaked.connect(_check.bind("breaked"))
	Hero.end_breaked.connect(_check.bind("end_breaked"))
	Hero.on_climb.connect(_check.bind("on_climb"))
	Hero.end_climb.connect(_check.bind("end_climb"))
	
	Current.enter()


func _exit_tree() -> void:
	_InputController.move_left_pressed.disconnect(_check.bind("move_left_pressed"))
	_InputController.move_left_released.disconnect(_check.bind("move_left_released"))
	_InputController.move_right_pressed.disconnect(_check.bind("move_right_pressed"))
	_InputController.move_right_released.disconnect(_check.bind("move_right_released"))
	_InputController.jump_pressed.disconnect(_check.bind("jump_pressed"))
	_InputController.when_attack_tigger.disconnect(_check.bind("when_attack_tigger"))
	_InputController.input_banned.disconnect(_check.bind("input_banned"))
	
	
	Hero.is_static.disconnect(_check.bind("is_static"))
	Hero.on_floor.disconnect(_check.bind("on_floor"))
	Hero.is_fall.disconnect(_check.bind("is_fall"))
	Hero.end_jump.disconnect(_check.bind("end_jump"))
	Hero.end_attack.disconnect(_check.bind("end_attack"))
	Hero.death.disconnect(_check.bind("death"))
	Hero.breaked.disconnect(_check.bind("breaked"))
	Hero.end_breaked.disconnect(_check.bind("end_breaked"))
	Hero.on_climb.disconnect(_check.bind("on_climb"))
	Hero.end_climb.disconnect(_check.bind("end_climb"))


func _physics_process(delta: float) -> void:
	Current.do(delta)


func switch_state(nextState: BaseState, allow_buffer: bool = true):
	Previous = Current
	Current.exit()
	if allow_buffer:
		for bufferedState in Current.BufferedStates:
			if _InputController.consume_buffered_action(bufferedState.name):
				nextState = bufferedState
				break
	# 已用于进入状态的输入不能在状态结束时再次触发。
	_InputController.clear_buffered_action(nextState.name)
	Current = nextState
	Current.enter()


func _check(signalName:String):
	if Current.NextStates.has(signalName):
		switch_state(Current.NextStates.get(signalName), signalName != "breaked" and signalName != "death")
