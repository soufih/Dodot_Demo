extends BaseState

@export var DefaultState:BaseState
@export var HateArea:Area2D
@export var Hitbox:Area2D

var Attacking:bool = false
var StateController = BaseStateManager.new()

func _ready() -> void:
	StateController.set_physics_process(false)
	StateController.StateArray = get_children()
	StateController.Current = DefaultState


func do(_delta: float):
	check()
	StateController.Current.do(_delta)

func check():
	if Attacking:
		return

	if Hitbox.has_overlapping_bodies():
		for body in Hitbox.get_overlapping_bodies():
			if body.is_in_group("Hero"):
				Attacking = true
				StateController.change_state(0)
				return

	if StateController.Current.name != "Move":
		StateController.change_state(1)

func _on_attack(i: bool) -> void:
	Attacking = i
