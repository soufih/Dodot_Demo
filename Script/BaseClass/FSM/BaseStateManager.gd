extends Node
class_name BaseStateManager

@export var Current: BaseState
var StateArray: Array = []

func _ready() -> void:
	StateArray = get_children()
	Current.enter()

func _physics_process(delta: float) -> void:
	check()
	Current.do(delta)
	
func change_state(id: int):
	Current.exit()
	Current = StateArray[id]
	Current.enter()
	
func check():
	pass
	
