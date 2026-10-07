extends Node

class ProbeState extends BaseState:
	var events: Array[String] = []
	signal resume_enter
	var async_enter := false
	func _on_enter() -> void:
		events.append("enter_hook")
		if async_enter:
			await resume_enter
			events.append("enter_resumed")
	func _on_do(_delta: float) -> void:
		events.append("do_hook")
		return
	func _on_exit() -> void:
		events.append("exit_hook")

class ChildProbe extends ProbeState:
	func _on_enter() -> void:
		events.append("child_hook")
		await super._on_enter()

func _ready() -> void:
	var probe := ChildProbe.new()
	add_child(probe)
	probe.enter_started.connect(func(): probe.events.append("enter_started"))
	probe.enter_finished.connect(func(): probe.events.append("enter_finished"))
	probe.do_started.connect(func(delta: float):
		assert(delta == 0.125)
		probe.events.append("do_started"))
	probe.do_finished.connect(func(delta: float):
		assert(delta == 0.125)
		probe.events.append("do_finished"))
	probe.exit_started.connect(func(): probe.events.append("exit_started"))
	probe.exit_finished.connect(func(): probe.events.append("exit_finished"))
	probe.enter()
	probe.do(0.125)
	probe.exit()
	assert(probe.events == ["enter_started", "child_hook", "enter_hook", "enter_finished", "do_started", "do_hook", "do_finished", "exit_started", "exit_hook", "exit_finished"])
	probe.events.clear()
	probe.async_enter = true
	probe.enter()
	assert(probe.events == ["enter_started", "child_hook", "enter_hook"])
	probe.resume_enter.emit()
	assert(probe.events == ["enter_started", "child_hook", "enter_hook", "enter_resumed", "enter_finished"])
	print("STATE_LIFECYCLE_TESTS_PASSED")
	get_tree().quit()
