extends Node

const HERO_SCENE = preload("res://Scene/Hero/Hero.tscn")
const LADDER_SCENE = preload("res://Scene/Map/MapComponent/Climbables/ladder.tscn")

var hero: HeroProperty
var ladder: ClimbableLadder
var input: InputController
var controller: InteractionController
var manager: Node


func _ready() -> void:
	hero = HERO_SCENE.instantiate()
	ladder = LADDER_SCENE.instantiate()
	add_child(ladder)
	add_child(hero)
	input = hero.get_node("InputController")
	controller = hero.get_node("InteractionController")
	manager = hero.get_node("State")
	# 手动在物理帧驱动状态，避免下落更新影响顶点测量。
	hero.set_physics_process(false)
	manager.set_physics_process(false)
	input.ban_input(false)
	var original_tick_rate := Engine.physics_ticks_per_second
	for tick_rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = tick_rate
		await get_tree().physics_frame
		var short_height: float = await _measure_height(20.0, 80.0, "short")
		var long_height: float = await _measure_height(20.0, 80.0, "long")
		var partial_height: float = await _measure_height(20.0, 80.0, "partial")
		var repressed_height: float = await _measure_height(20.0, 80.0, "repress")
		assert(absf(short_height - 20.0) < 0.05)
		assert(absf(long_height - 80.0) < 0.05)
		assert(partial_height > short_height and partial_height < long_height)
		assert(absf(repressed_height - partial_height) < 0.05)
		print("JUMP_HEIGHTS rate=%d short=%.3f long=%.3f partial=%.3f" % [tick_rate, short_height, long_height, partial_height])

	# 相同高度、反向配置和速度倍率均不能改变高度上限。
	var equal_height: float = await _measure_height(40.0, 40.0, "long")
	var inverted_height: float = await _measure_height(40.0, 20.0, "long")
	assert(absf(equal_height - 40.0) < 0.05)
	assert(absf(inverted_height - 40.0) < 0.05)
	hero.JumpSpeedMultiplier = 0.75
	var slow_height: float = await _measure_height(20.0, 80.0, "long")
	assert(absf(slow_height - 80.0) < 0.05)

	# 撞到天花板后应立即切换下落，不继续施加向上速度。
	var ceiling := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(300.0, 10.0)
	collision.shape = shape
	ceiling.add_child(collision)
	ceiling.position.y = -60.0
	add_child(ceiling)
	await get_tree().physics_frame
	var ceiling_height: float = await _measure_height(20.0, 80.0, "long")
	assert(ceiling_height < 80.0 and hero.is_on_ceiling())
	assert(manager.Current.name == "Falling" and hero.velocity.y == 0.0)
	Engine.physics_ticks_per_second = original_tick_rate
	Input.action_release(&"Jump")
	print("JUMP_HEIGHT_TESTS_PASSED")
	get_tree().quit()


func _measure_height(min_height: float, max_height: float, mode: String) -> float:
	Input.action_release(&"Jump")
	manager.switch_state(manager.get_node("Idle"), false)
	hero.global_position = Vector2.ZERO
	var jump_state := manager.get_node("Jumping")
	jump_state.MinJumpHeight = min_height
	jump_state.MaxJumpHeight = max_height
	controller.current_interactable = ladder
	manager.switch_state(manager.get_node("Climb"), false)
	Input.action_press(&"Jump")
	var event := InputEventAction.new()
	event.action = &"Jump"
	event.pressed = true
	input._unhandled_input(event)
	assert(manager.Current == jump_state)
	var origin_y := hero.global_position.y
	var highest_y := origin_y
	for frame in range(300):
		await get_tree().physics_frame
		if mode == "short" or ((mode == "partial" or mode == "repress") and frame >= 2):
			Input.action_release(&"Jump")
		if mode == "repress" and frame >= 3:
			Input.action_press(&"Jump")
		jump_state.do(1.0 / Engine.physics_ticks_per_second)
		highest_y = minf(highest_y, hero.global_position.y)
		if manager.Current != jump_state:
			assert(manager.Current.name == "Falling")
			Input.action_release(&"Jump")
			return origin_y - highest_y
	assert(false, "跳跃未在预期时间内到达顶点")
	return 0.0
