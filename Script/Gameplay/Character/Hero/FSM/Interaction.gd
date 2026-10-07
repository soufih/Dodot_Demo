extends BaseState



enum subState {
	Default,
	climbLadder,
}

var stateController:BaseStateManager = BaseStateManager.new()

func _ready() -> void:
	stateController.StateArray = get_children()
	stateController.Current = stateController.StateArray[subState.Default]

func check():
	for area in Entity.InteractBox.get_overlapping_areas():
		if Input.is_action_just_pressed("Interact") || Input.is_action_just_pressed("Jump"):
			get_parent().interacting = false

		if area.name == "Ladder" && stateController.Current.name != "climbLadder":
			get_parent().interacting = true
			stateController.change_state(subState.climbLadder)
		

func _on_do(_delta: float):
	check()
	stateController.Current.do(_delta)

func _on_exit():
	stateController.Current = stateController.StateArray[subState.Default]


func _on_interact_box_area_exited(area: Area2D) -> void:
	get_parent().interacting = false
