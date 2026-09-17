extends Node

@onready var InputControlller = $"../InputController"
@onready var Hero = $".."

@export var Current:BaseState


func _ready() -> void:
	InputControlller.move_left_pressed.connect(_check.bind("move_left_pressed"))
	InputControlller.move_left_released.connect(_check.bind("move_left_released"))
	InputControlller.move_right_pressed.connect(_check.bind("move_right_pressed"))
	InputControlller.move_right_released.connect(_check.bind("move_right_released"))
	InputControlller.jump_pressed.connect(_check.bind("jump_pressed"))
	InputControlller.when_attack_tigger.connect(_check.bind("when_attack_tigger"))
	
	Hero.is_static.connect(_check.bind("is_static"))
	Hero.on_floor.connect(_check.bind("on_floor"))
	Hero.is_fall.connect(_check.bind("is_fall"))
	Hero.end_jump.connect(_check.bind("end_jump"))
	Hero.end_attack.connect(_check.bind("end_attack"))
	Hero.death.connect(_check.bind("death"))
	Hero.breaked.connect(_check.bind("breaked"))
	Hero.end_breaked.connect(_check.bind("end_breaked"))
	
	Current.enter()

func _physics_process(delta: float) -> void:
	Current.do(delta)

func switch_state(nextState: BaseState):
	Current.exit()
	for bufferedState in Current.BufferedStates:
		if InputControlller.consume_buffered_action(bufferedState.name):
				nextState = bufferedState
	nextState.enter()
	Current = nextState


func _check(signalName:String):
	print(signalName)
	if Current.NextStates.has(signalName):
		switch_state(Current.NextStates.get(signalName))
