extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)


func _ready() -> void:
	await get_tree().process_frame
	UIManager.tmp_slot.set_process(false)
	CurrentLevel.set_level_info(0, "小地图测试")
	var level := SceneLoading.get_scene(SceneLoading.LEVEL_SCENE_PATH).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	var generator: LevelGenerator = level.get_node("LevelGenerator")
	var tracker = level.get_node("LevelExploration")
	var minimap = level.get_node("LevelHUD/MiniMapUI")
	assert(generator.generation_succeeded)
	var hero: HeroProperty = DataLoader.get_hero()
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	assert(tracker.current_room_id >= 0)
	assert(tracker.get_explored_rooms().size() == 1)
	assert(minimap._explored_rooms.size() == 1)
	var room_count := 0
	for node in generator._generated_nodes:
		if node.has_node("BaseLayer"):
			room_count += 1
	assert(tracker._rooms.size() == room_count and room_count > 1)
	var start_id: int = tracker.current_room_id
	var next_room: Dictionary
	for room in tracker._rooms:
		if room.id != start_id:
			next_room = room
			break
	# 实际世界位置驱动探索；显示新房间并保留此前探索记录。
	hero.global_position = next_room.bounds.get_center()
	tracker._physics_process(0.0)
	assert(tracker.current_room_id == next_room.id)
	assert(tracker.get_explored_rooms().size() == 2)
	assert(minimap._current_room_id == next_room.id and minimap._explored_rooms.size() == 2)
	hero.global_position = tracker._rooms[start_id].bounds.get_center()
	tracker._physics_process(0.0)
	assert(tracker.current_room_id == start_id)
	assert(tracker.get_explored_rooms().size() == 2)
	# 越界不揭示最近的未知房间，也不留下错误的玩家房间标记。
	tracker.update_player_position(Vector2(-10000000, -10000000))
	assert(tracker.current_room_id == -1)
	assert(minimap._current_room_id == -1 and minimap._explored_rooms.size() == 2)
	assert(minimap.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	if OS.get_cmdline_user_args().has("--preview"):
		for room in tracker._rooms.slice(0, mini(5, tracker._rooms.size() - 1)):
			hero.global_position = room.bounds.get_center()
			tracker.update_player_position(room.bounds.get_center())
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Path.MINIMAP_PREVIEW_TEXTURE)
		print("MINIMAP_PREVIEW_SAVED")
		get_tree().quit()
		return
	# 再次生成时清空旧探索记录；新关卡仅显示出生房间。
	assert(generator.generate_level(0))
	assert(tracker.current_room_id >= 0)
	assert(tracker.get_explored_rooms().size() == 1)
	assert(minimap._explored_rooms.size() == 1)
	generator.destroy_level()
	assert(tracker.get_explored_rooms().is_empty() and tracker.current_room_id == -1)
	assert(minimap._explored_rooms.is_empty() and minimap._current_room_id == -1)
	print("MINIMAP_TESTS_PASSED")
	get_tree().quit()
