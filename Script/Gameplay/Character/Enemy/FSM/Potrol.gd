extends BaseState

@export var DefaultState: BaseState
@export var RestTimer: Timer
var Current: BaseState
var Previous: BaseState

func _on_enter():
	Current = DefaultState
	Current.enter()
	RestTimer.start(randf_range(1.0, 3.0))

func _on_do(delta: float):
	if RestTimer.is_stopped():
		_check("rest_finished")
	Current.do(delta)

func switch_state(next_state: BaseState):
	Previous = Current
	Current.exit()
	Current = next_state
	Current.enter()
	RestTimer.start(randf_range(2.0, 4.0) if Current != DefaultState else randf_range(1.0, 3.0))

func _check(signal_name: String):
	if Current.NextStates.has(signal_name):
		switch_state(Current.NextStates[signal_name] as BaseState)

func _on_exit():
	RestTimer.stop()
	Current.exit()
