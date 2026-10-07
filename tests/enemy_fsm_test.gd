extends Node

func _ready() -> void:
	for scene_path in [Path.ENEMY1_SCENE, Path.ENEMY2_SCENE]:
		var enemy = load(scene_path).instantiate()
		add_child(enemy)
		assert(enemy.drop_component.items == enemy.Porperty.Drop)
		assert(enemy.get_node("FSM/Death").drop_component == enemy.drop_component)
		var health_ui := enemy.get_node("EnemyHealthBar") as EnemyHealthBar
		assert(health_ui.target == enemy)
		assert(health_ui.health_bar.value == enemy.CurrentHealth)
		enemy.Atived = true
		var fsm = enemy.get_node("FSM")
		fsm.set_physics_process(false)
		var patrol = fsm.get_node("Potrol")
		var trace = fsm.get_node("Trace")
		var attack = trace.get_node("Attack")
		assert(fsm.Current == patrol)
		# 正常离开启动仇恨倒计时；计时器先退出树时不再启动。
		var target := CharacterBody2D.new()
		add_child(target)
		target.add_to_group("Hero")
		fsm._on_target_exited(target)
		assert(not fsm.HateTimer.is_stopped())
		fsm.HateTimer.stop()
		var timer_parent: Node = fsm.HateTimer.get_parent()
		timer_parent.remove_child(fsm.HateTimer)
		fsm._on_target_exited(target)
		assert(fsm.HateTimer.is_stopped())
		timer_parent.add_child(fsm.HateTimer)
		target.remove_from_group("Hero")
		target.free()
		assert(patrol.Current == patrol.DefaultState)
		patrol.RestTimer.stop()
		patrol.do(0.0)
		assert(patrol.Current == patrol.get_node("Move"))
		patrol.RestTimer.stop()
		patrol.do(0.0)
		assert(patrol.Current == patrol.get_node("Idle"))
		fsm._check("target_found")
		assert(fsm.Current == trace and patrol.RestTimer.is_stopped())
		trace._check("target_in_range")
		assert(trace.Current == attack and attack._active)
		var generation = attack._generation
		for i in range(10):
			trace.do(0.0)
		assert(attack._generation == generation)
		await get_tree().create_timer(1.9).timeout
		assert(trace.Current == trace.get_node("Move") and not attack._active)
		trace._check("target_in_range")
		enemy.breaked.emit()
		assert(fsm.Current == fsm.get_node("Break") and not attack._active)
		# 被中断攻击的旧等待不能切换追踪子状态。
		await get_tree().create_timer(1.2).timeout
		assert(fsm.Current == patrol)
		fsm._check("target_found")
		fsm._on_hate_timeout()
		assert(fsm.Current == patrol)
		enemy.breaked.emit()
		enemy.death.emit()
		assert(fsm.Current == fsm.get_node("Death"))
		fsm._check("target_found")
		enemy.breaked.emit()
		assert(fsm.Current == fsm.get_node("Death"))
		# 整个敌人退出树后，即使对象尚未释放，也应断开外部信号。
		remove_child(enemy)
		assert(not fsm.Hatebox.body_exited.is_connected(fsm._on_target_exited))
		assert(not enemy.death.is_connected(fsm._check.bind("death")))
		enemy.queue_free()
		await get_tree().process_frame
	print("ENEMY_FSM_TEST_PASS")
	get_tree().quit()
