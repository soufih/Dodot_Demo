extends Node

class TestManager extends "res://Script/Gameplay/Character/Hero/FSM/StateManager.gd":
	func _ready() -> void:
		pass
	func _exit_tree() -> void:
		pass

class TestState extends BaseState:
	var entries: int = 0
	var manager: Node
	var finish_immediately: bool = false
	func enter():
		entries += 1
		assert(manager.Current == self)
		if finish_immediately:
			manager._check("end_attack")

func _ready() -> void:
	var input := InputController.new()
	input.input_buffer_duration = 0.5
	var manager := TestManager.new()
	manager._InputController = input
	var idle := TestState.new()
	idle.name = "Idle"
	idle.manager = manager
	var attack := TestState.new()
	attack.name = "Attack"
	attack.manager = manager
	var hurt := TestState.new()
	hurt.name = "Break"
	hurt.manager = manager
	attack.BufferedStates.append(attack)
	attack.NextStates["end_attack"] = idle
	attack.NextStates["breaked"] = hurt
	attack.NextStates["death"] = hurt
	idle.NextStates["when_attack_tigger"] = attack
	manager.Current = idle
	# 模拟动画在缓冲过期前结束；首次输入不可被重复消费。
	input.buffer_action("Attack")
	manager._check("when_attack_tigger")
	assert(not input.has_buffered_action("Attack"))
	manager._check("end_attack")
	assert(manager.Current == idle and attack.entries == 1)
	# 攻击期间的新输入仍触发一次连击。
	manager._check("when_attack_tigger")
	input.buffer_action("Attack")
	manager._check("end_attack")
	assert(manager.Current == attack and attack.entries == 3)
	manager._check("end_attack")
	assert(manager.Current == idle)
	# 缓冲不能覆盖受击或死亡。
	for event in ["breaked", "death"]:
		manager.Current = attack
		input.buffer_action("Attack")
		manager._check(event)
		assert(manager.Current == hurt)
		input.clear_buffered_action("Attack")
	# enter 同步发出结束信号时，也必须以新状态处理。
	manager.Current = idle
	attack.finish_immediately = true
	manager._check("when_attack_tigger")
	assert(manager.Current == idle)
	for node in [input, manager, idle, attack, hurt]:
		node.free()
	print("ATTACK_FLOW_TESTS_PASSED")
	get_tree().quit()
