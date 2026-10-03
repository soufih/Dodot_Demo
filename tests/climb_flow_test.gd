extends Node

const HERO_SCENE = preload("res://Scene/Hero/Hero.tscn")
const LADDER_SCENE = preload("res://Scene/Map/MapComponent/Climbables/ladder.tscn")


func _ready() -> void:
	var hero := HERO_SCENE.instantiate() as HeroProperty
	var ladder := LADDER_SCENE.instantiate() as ClimbableLadder
	add_child(ladder)
	add_child(hero)
	var input := hero.get_node("InputController") as InputController
	var controller := hero.get_node("InteractionController") as InteractionController
	var manager := hero.get_node("State")
	input.ban_input(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(controller.detector.get_overlapping_areas().has(ladder))

	# 同一次交互只能进入爬梯；再次交互才退出。
	_press(input, &"Interact")
	assert(manager.Current.name == "Climb" and controller.interacting)
	_press(input, &"Interact")
	assert(manager.Current.name == "Idle")
	assert(not controller.interacting and controller.current_interactable == null)

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
		hero.emit_signal(event)
		assert(manager.Current.name == ("Break" if event == "breaked" else "Death"))
		assert(not controller.interacting and controller.current_interactable == null)

	# enter 内同步退出时，结束信号仍以新的 Current 分发。
	manager.switch_state(manager.get_node("Climb"), false)
	assert(manager.Current.name == "Idle")
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
