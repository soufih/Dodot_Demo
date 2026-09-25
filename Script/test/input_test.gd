extends Node2D

@onready var input:InputController = $Node

func _ready() -> void:
	input.move_left_pressed.connect(test)

func test():
	print(1)

func _physics_process(delta: float) -> void:
	#if Input.is_action_pressed("MoveLeft"):
			#print(2)
	pass
