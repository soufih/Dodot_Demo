extends SceneTree


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	root.size = Vector2i(640, 360)
	var ui_manager = root.get_node("UIManager")
	ui_manager.tmp_slot.set_process(false)
	var world := Node2D.new()
	var actor := CharacterBody2D.new()
	actor.collision_layer = 2
	actor.collision_mask = 0
	actor.add_to_group("Hero")
	var player_shape := CollisionShape2D.new()
	player_shape.shape = CircleShape2D.new()
	player_shape.shape.radius = 1.0
	actor.add_child(player_shape)
	world.add_child(actor)
	var camera = load(Path.MAIN_CAMERA_SCRIPT).new()
	camera.name = "MainCamera"
	camera.position = Vector2(0, -80)
	camera.look_down_distance = 120.0
	camera.look_hold_duration = 0.4
	camera.look_move_speed = 600.0
	actor.add_child(camera)
	root.add_child(world)
	camera.make_current()
	camera.set_process(false)
	for action in ["Up", "Down"]:
		var expected_position := Vector2(0, -200 if action == "Up" else 40)
		Input.action_press(action)
		camera._update_look(0.2)
		assert(camera.position == Vector2(0, -80))
		camera._update_look(0.2)
		assert(camera.position == expected_position)
		camera._update_look(1.0)
		assert(camera.position == expected_position)
		Input.action_release(action)
		camera._update_look(0.2)
		assert(camera.position == Vector2(0, -80))
	# 切换短按不能累积成长按。
	Input.action_press("Up")
	camera._update_look(0.2)
	Input.action_release("Up")
	Input.action_press("Down")
	camera._update_look(0.2)
	assert(camera.position == Vector2(0, -80))
	ui_manager.is_banned = true
	camera._update_look(1.0)
	assert(camera.position == Vector2(0, -80))
	ui_manager.is_banned = false
	Input.action_release("Down")
	# 下移后画面仍被房间边界约束。
	var boundary = load(Path.CAMERA_BOUNDARY_SCENE).instantiate()
	boundary.fit_tile_map = false
	boundary.bounds = Rect2(-1000, -600, 2000, 1200)
	world.add_child(boundary)
	actor.position = Vector2(0, 580)
	Input.action_press("Down")
	camera._update_look(1.0)
	for frame in range(3):
		await physics_frame
	camera.force_update_scroll()
	assert(camera.get_screen_center_position().y <= 600.0 - root.size.y * 0.5)
	Input.action_release("Down")
	world.queue_free()
	Input.action_release("Up")
	await process_frame
	print("CAMERA_LOOK_TESTS_PASSED")
	quit()
