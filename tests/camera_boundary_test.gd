extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(640, 360)
	for path in [
		Path.BASE_ROOM_SCENE,
		Path.S1_SCENE,
		Path.E1_SCENE,
		Path.R4_SCENE,
		Path.R5_SCENE,
		Path.R6_SCENE,
		Path.C1_SCENE,
		Path.C2_SCENE,
		Path.C3_SCENE,
	]:
		var saved_room: Node2D = load(path).instantiate()
		var saved_boundary := saved_room.get_node("CameraBoundary")
		assert(saved_boundary.get_parent() == saved_room)
		assert(saved_boundary.fit_tile_map)
		assert(saved_boundary.get_node(saved_boundary.tile_map_path) == saved_room.get_node("BaseLayer"))
		saved_room.free()
	var world := Node2D.new()
	var hero := CharacterBody2D.new()
	hero.collision_layer = 2
	hero.collision_mask = 0
	hero.add_to_group("Hero")
	var player_shape := CollisionShape2D.new()
	player_shape.shape = CircleShape2D.new()
	player_shape.shape.radius = 1.0
	hero.add_child(player_shape)
	world.add_child(hero)
	var camera: Camera2D = load(Path.MAIN_CAMERA_SCRIPT).new()
	camera.name = "MainCamera"
	camera.set_process(false)
	hero.add_child(camera)
	var boundary: Node2D = load(Path.CAMERA_BOUNDARY_SCENE).instantiate()
	boundary.fit_tile_map = false
	boundary.bounds = Rect2(-1000, -600, 2000, 1200)
	world.add_child(boundary)
	root.add_child(world)
	await process_frame
	hero.position = Vector2(980, 580)
	await settle()
	camera.force_update_scroll()
	assert(camera.active_boundary == boundary)
	assert(camera.get_screen_center_position().is_equal_approx(Vector2(1000, 600) - camera.get_viewport_rect().size * 0.5))
	hero.position = Vector2(-980, -580)
	await settle()
	camera.force_update_scroll()
	assert(camera.get_screen_center_position().is_equal_approx(Vector2(-1000, -600) + camera.get_viewport_rect().size * 0.5))
	camera.set_view_zoom(Vector2(2, 2))
	await settle()
	camera.force_update_scroll()
	assert(camera.get_screen_center_position().is_equal_approx(Vector2(-1000, -600) + camera.get_viewport_rect().size * 0.25))
	# 小于视口的走廊锁定中心，不产生互相冲突的限制。
	boundary.bounds = Rect2(-100, -50, 200, 100)
	camera.set_view_zoom(Vector2.ONE)
	hero.position = Vector2.ZERO
	await settle()
	camera.force_update_scroll()
	assert(camera.get_screen_center_position().is_equal_approx(Vector2.ZERO))
	# 相邻房间切换与重叠区域的手工覆盖。
	var next_room: Node2D = load(Path.CAMERA_BOUNDARY_SCENE).instantiate()
	next_room.fit_tile_map = false
	next_room.bounds = Rect2(200, -600, 2000, 1200)
	world.add_child(next_room)
	hero.position = Vector2(1000, 0)
	await settle()
	assert(camera.active_boundary == next_room)
	boundary.bounds = next_room.bounds
	boundary.priority = 10
	await settle()
	assert(camera.active_boundary == boundary)
	boundary.enabled = false
	await settle()
	assert(camera.active_boundary == next_room)
	# 无敌状态切换碰撞层仍留在房间；越界后取消限制。
	hero.collision_layer = 64
	await settle()
	assert(camera.active_boundary == next_room)
	hero.position = Vector2(10000, 10000)
	await settle()
	assert(camera.active_boundary == null and not camera.limit_enabled)
	hero.position = Vector2(1000, 0)
	await settle()
	assert(camera.active_boundary == next_room)
	# 房间直接销毁时也会发出离开信号，清除镜头引用。
	next_room.queue_free()
	await settle()
	assert(camera.active_boundary == null and not camera.limit_enabled)
	# 自动边界继承 TileMap 的平移与缩放。
	var room: Node2D = load(Path.S1_SCENE).instantiate()
	room.position = Vector2(-500, 100)
	world.add_child(room)
	var auto_boundary: Node2D = room.get_node("CameraBoundary")
	var tiles := room.get_node("BaseLayer") as TileMapLayer
	var cells := tiles.get_used_rect()
	var tile_size := Vector2(tiles.tile_set.tile_size)
	assert(auto_boundary.get_world_bounds().is_equal_approx(tiles.global_transform * Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)))
	camera.boundary_collision_enabled = false
	await settle()
	assert(not camera.limit_enabled)
	world.queue_free()
	await process_frame
	# 用固定房间连接验证真实生成流程，不依赖随机模板能否拼接成功。
	var generator: Node = load(Path.CAMERA_BOUNDARY_GENERATOR_FIXTURE_SCRIPT).new()
	root.add_child(generator)
	assert(generator.generate_level(0))
	assert(get_nodes_in_group("CameraBoundary").size() == 2)
	assert(generator.generate_level(0))
	assert(get_nodes_in_group("CameraBoundary").size() == 2)
	generator.destroy_level()
	assert(get_nodes_in_group("CameraBoundary").is_empty())
	generator.queue_free()
	await process_frame
	print("PASS: camera edges, zoom, small rooms, boundary switching, priority and TileMap bounds")
	quit()


func settle() -> void:
	for frame in range(3):
		await physics_frame
	await process_frame
