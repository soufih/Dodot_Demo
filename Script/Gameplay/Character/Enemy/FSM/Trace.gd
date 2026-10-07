extends BaseState

@export var DefaultState: BaseState
@export var HateArea: Area2D
@export var Hitbox: Area2D
var Current: BaseState
var Previous: BaseState

func _on_enter():
	Current = DefaultState
	Current.enter()

func _on_do(delta: float):
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			_check("target_in_range")
			break
	Current.do(delta)

func switch_state(next_state: BaseState):
	if next_state == null or next_state == Current:
		return
	Previous = Current
	Current.exit()
	Current = next_state
	Current.enter()

func _check(signal_name: String):
	if Current.NextStates.has(signal_name):
		switch_state(Current.NextStates[signal_name] as BaseState)

func _on_exit():
	Current.exit()
