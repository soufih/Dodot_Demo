extends Node

const HERO_SCENE = preload(Path.HERO_SCENE)
const LADDER_SCENE = preload(Path.LADDER_SCENE)


func _ready() -> void:
	var hero := HERO_SCENE.instantiate() as HeroProperty
	var ladder := LADDER_SCENE.instantiate() as ClimbableLadder
	add_child(ladder)
	add_child(hero)
	var prompt := hero.get_node("PlayerUI/InteractionPrompt") as Label
	assert(not prompt.visible)
	var input := hero.get_node("InputController") as InputController
	var controller := hero.get_node("InteractionController") as InteractionController
	var manager := hero.get_node("State")
	input.ban_input(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(controller.detector.get_overlapping_areas().has(ladder))
	assert(prompt.visible and prompt.text == "[E] 攀爬梯子")
	# 共用玩家 UI 提示；多个目标重叠时与实际交互目标保持一致。
	var endpoint := preload(Path.EXIT_POINT_SCENE).instantiate()
	add_child(endpoint)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(controller.detector.get_current_interactable() == ladder)
	assert(prompt.text == "[E] 攀爬梯子")
	ladder.position.x = 1000.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(prompt.visible and prompt.text == "[E] 完成关卡")
	endpoint.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(not prompt.visible)
	ladder.position.x = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(prompt.visible and prompt.text == "[E] 攀爬梯子")

	# 进入攀爬清除已有偏移，W/S 仅驱动攀爬；退出后重新计时。
	var camera := hero.mainCamera
	camera.make_current()
	camera.set_process(false)
	var base_camera_position := camera.position
	Input.action_press("Up")
	camera._update_look(2.0)
	assert(camera.position.y < base_camera_position.y)
	_press(input, &"Interact")
	assert(manager.Current.name == "Climb")
	assert(not camera._look_enabled and camera.position == base_camera_position)
	camera._update_look(0.01)
	assert(camera.position == base_camera_position)
	Input.action_release("Up")
	for action in ["Up", "Down"]:
		Input.action_press(action)
		camera._update_look(2.0)
		assert(camera.position == base_camera_position)
		Input.action_release(action)
	_press(input, &"Interact")
	assert(manager.Current.name == "Idle")
	assert(camera._look_enabled)
	Input.action_press("Up")
	camera._update_look(0.1)
	assert(camera.position == base_camera_position)
	camera._update_look(2.0)
	assert(camera.position.y < base_camera_position.y)
	Input.action_release("Up")
	camera._update_look(2.0)
	assert(camera.position == base_camera_position)

	# 梯子固定指定攀爬朝向，不受进入前朝向影响；退出恢复原朝向。
	for climb_flip in [false, true]:
		ladder.climb_flip_h = climb_flip
		for entry_flip in [false, true]:
			hero.Spirte.flip_h = entry_flip
			_press(input, &"Interact")
			assert(manager.Current.name == "Climb")
			assert(hero.Spirte.flip_h == climb_flip)
			manager.Current.do(0.0)
			assert(hero.Spirte.flip_h == climb_flip)
			_press(input, &"Interact")
			assert(manager.Current.name == "Idle")
			assert(hero.Spirte.flip_h == entry_flip)
	ladder.climb_flip_h = false

	# 同一次交互只能进入爬梯；再次交互才退出。
	_press(input, &"Interact")
	assert(manager.Current.name == "Climb" and controller.interacting)
	assert(not prompt.visible and prompt.text.is_empty())
	_press(input, &"Interact")
	assert(manager.Current.name == "Idle")
	assert(not controller.interacting and controller.current_interactable == null)
	assert(not prompt.visible)
	# 交互后保持隐藏；离开并重新进入才能再次提示。
	ladder.position.x = 1000.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(not prompt.visible)
	ladder.position.x = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(prompt.visible and prompt.text == "[E] 攀爬梯子")

	# 从空中的梯子起跳，初始化速度并消费跳跃输入。
	_press(input, &"Interact")
	assert(not hero.is_on_floor())
	_press(input, &"Jump")
	assert(manager.Current.name == "Jumping" and hero.velocity.y < 0.0)
	assert(not controller.interacting and not input.has_buffered_action("Jumping"))
	var jump_state: BaseState = manager.Current
	var launch_speed := hero.velocity.y

	# 跳跃途中交互进入爬梯，再起跳必须重新初始化上升速度。
	_press(input, &"Interact")
	assert(manager.Current.name == "Climb" and controller.interacting)
	assert(hero.velocity == Vector2.ZERO)
	_press(input, &"Jump")
	assert(manager.Current == jump_state and hero.velocity.y < 0.0)
	assert(is_equal_approx(hero.velocity.y, launch_speed))
	assert(not controller.interacting and controller.current_interactable == null)
	assert(not input.has_buffered_action("Jumping"))

	# 受击和死亡也必须经过 Climb.exit() 清理交互。
	for event in ["breaked", "death"]:
		manager.switch_state(manager.get_node("Idle"), false)
		_press(input, &"Interact")
		assert(manager.Current.name == "Climb")
		assert(not camera._look_enabled)
		hero.emit_signal(event)
		assert(manager.Current.name == ("Break" if event == "breaked" else "Death"))
		assert(camera._look_enabled)
		assert(not controller.interacting and controller.current_interactable == null)

	# enter 内同步退出时，结束信号仍以新的 Current 分发。
	manager.switch_state(manager.get_node("Climb"), false)
	assert(manager.Current.name == "Idle")
	assert(camera._look_enabled)
	assert(not controller.interacting)

	# 梯子销毁后的物理检查应正常退出。
	_press(input, &"Interact")
	assert(manager.Current.name == "Climb")
	ladder.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(manager.Current.name != "Climb" and not controller.interacting)
	print("CLIMB_FLOW_TESTS_PASSED")
	get_tree().quit()


func _press(input: InputController, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	input._unhandled_input(event)
