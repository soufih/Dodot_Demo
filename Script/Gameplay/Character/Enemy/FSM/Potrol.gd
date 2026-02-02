extends BaseState

@export var DefaultState:BaseState
@export var RestTimer:Timer
var StateController: BaseStateManager = BaseStateManager.new()

func _ready() -> void:
	StateController.set_physics_process(false)
	StateController.StateArray = get_children()
	StateController.Current = DefaultState

func enter():
	print(Entity.name, "potrol now")

func do(_delta: float):
	check()
	StateController.Current.do(_delta)


func check():
	if !RestTimer.is_stopped():
		return

	if StateController.Current.name != "Move":
		StateController.change_state(1)
		RestTimer.start(randf_range(2, 4))
		return

	if StateController.Current.name != "Idle":
		StateController.change_state(0)
		RestTimer.start(randf_range(1, 3))
		return
