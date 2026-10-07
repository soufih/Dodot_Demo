extends Node

const HERO = preload(Path.HERO_SCENE)

func _ready() -> void:
	var hero: HeroProperty = HERO.instantiate()
	add_child(hero)
	hero.set_physics_process(false)
	var manager = hero.get_node("State")
	manager.set_physics_process(false)
	var input: InputController = hero.get_node("InputController")
	input.ban_input(false)
	var skills: SkillController = hero.get_node("SkillController")
	skills.set_physics_process(false)
	var dash: BaseState = manager.get_node("Dash")
	var dash_input := InputEventAction.new()
	dash_input.action = &"Dash"
	dash_input.pressed = true
	SignalBus.skill_remove_requested.emit(hero, &"dash")
	var previous = manager.Current
	input._unhandled_input(dash_input)
	assert(manager.Current == previous)
	SignalBus.skill_acquire_requested.emit(hero, &"dash")
	assert(hero.is_ability_enabled(&"dash"))
	input._unhandled_input(dash_input)
	assert(manager.Current == dash)
	assert(hero.ani.has_animation(&"Dash"))
	assert(skills.skill_timer_map.has(&"dash") and not skills.is_skill_ready(&"dash"))
	manager.switch_state(manager.get_node("Idle"), false)
	await skills.skill_timer_map[&"dash"].timeout
	assert(skills.is_skill_ready(&"dash") and skills.get_skill_cooldown_remaining(&"dash") == 0.0)
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		# 改变距离和速度，验证位移取自 distance 而不是固定时长。
		dash.distance = 225.0
		dash.speed = 750.0
		await get_tree().physics_frame
		manager.switch_state(manager.get_node("Idle"), false)
		hero.position = Vector2.ZERO
		hero.velocity = Vector2.ZERO
		hero.Spirte.flip_h = false
		skills.skill_timer_map[&"dash"].stop()
		input._unhandled_input(dash_input)
		assert(manager.Current.name == &"Dash" and hero.velocity.x == dash.speed)
		assert(not skills.try_activate(&"dash"))
		for frame in range(60):
			await get_tree().physics_frame
			if manager.Current != dash:
				break
			manager.Current.do(1.0 / rate)
		assert(manager.Current != dash and manager.Current.name == &"Falling")
		assert(absf(hero.position.x - dash.distance) < 0.1)
		assert(not skills.is_skill_ready(&"dash"))
	Engine.physics_ticks_per_second = original_rate
	dash.distance = 162.0
	dash.speed = 900.0
	# 朝向、输入禁用、受击中断；取消也保留冷却。
	manager.switch_state(manager.get_node("Idle"), false)
	hero.Spirte.flip_h = true
	skills.skill_timer_map[&"dash"].stop()
	input._unhandled_input(dash_input)
	assert(hero.velocity.x == -900.0)
	assert(hero.is_ability_enabled(&"dash"))
	hero.breaked.emit()
	assert(manager.Current != dash and manager.Current.name == &"Break")
	assert(skills.get_skill_cooldown_remaining(&"dash") > 0.0)
	manager.switch_state(manager.get_node("Idle"), false)
	skills.skill_timer_map[&"dash"].stop()
	input.ban_input(true)
	input._unhandled_input(dash_input)
	assert(manager.Current.name == &"Idle")
	input.ban_input(false)
	# 移除正在执行的冲刺必须离开 Dash，不能留下无法移动的状态。
	input._unhandled_input(dash_input)
	SignalBus.skill_remove_requested.emit(hero, &"dash")
	dash.do(1.0 / 60.0)
	assert(not hero.is_ability_enabled(&"dash"))
	assert(manager.Current != dash and manager.Current.name != &"Dash")
	SignalBus.skill_acquire_requested.emit(hero, &"dash")
	manager.switch_state(manager.get_node("Idle"), false)
	# 撞墙由状态调用 MotionUtil 检测，状态发出结束信号。
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10.0, 300.0)
	collision.shape = shape
	wall.add_child(collision)
	wall.position.x = 80.0
	add_child(wall)
	hero.position = Vector2.ZERO
	hero.Spirte.flip_h = false
	await get_tree().physics_frame
	skills.skill_timer_map[&"dash"].stop()
	input._unhandled_input(dash_input)
	assert(manager.Current == dash)
	for frame in range(30):
		await get_tree().physics_frame
		if manager.Current != dash:
			break
		manager.Current.do(1.0 / 60.0)
	assert(manager.Current != dash and hero.position.x < 80.0)
	wall.queue_free()
	await get_tree().physics_frame
	# 地面冲刺完成回到 Idle；运行中禁用输入同样退出执行状态。
	var floor_body := StaticBody2D.new()
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(1000.0, 10.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = 60.0
	add_child(floor_body)
	manager.switch_state(manager.get_node("Idle"), false)
	hero.position = Vector2.ZERO
	hero.velocity = Vector2(0.0, 300.0)
	for frame in range(30):
		await get_tree().physics_frame
		hero.move_and_slide()
		if hero.is_on_floor():
			break
	assert(hero.is_on_floor())
	skills.skill_timer_map[&"dash"].stop()
	input._unhandled_input(dash_input)
	for frame in range(30):
		await get_tree().physics_frame
		if manager.Current != dash:
			break
		manager.Current.do(1.0 / 60.0)
	assert(manager.Current.name == &"Idle")
	skills.skill_timer_map[&"dash"].stop()
	input._unhandled_input(dash_input)
	input.ban_input(true)
	dash.do(1.0 / 60.0)
	assert(manager.Current != dash and manager.Current.name != &"Dash")
	input.ban_input(false)
	# 死亡状态的空映射拒绝转化，即使输入发出冲刺请求也保持 Death。
	hero.set_character_current_health(0.0)
	assert(manager.Current.name == &"Death")
	skills.skill_timer_map[&"dash"].stop()
	input._unhandled_input(dash_input)
	assert(manager.Current.name == &"Death")
	assert(not skills.try_activate(&"dash"))
	print("DASH_SKILL_TESTS_PASSED")
	get_tree().quit()

