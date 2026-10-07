extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

var progress_samples: Array[float] = []


func _ready() -> void:
	# Dummy 渲染器不能显示背包拖拽图标，该 UI 与加载测试无关。
	UIManager.tmp_slot.set_process(false)
	# 创建生成器不能实例化关卡；资源准备阶段也不能注册玩家或创建房间。
	var preloader := LevelGenerator.new()
	assert(preloader.get_child_count() == 0)
	preloader.auto_generate = false
	add_child(preloader)
	assert(preloader.get_child_count() == 0)
	assert(await preloader.prepare_level_async(0))
	assert(preloader.get_child_count() == 0 and DataLoader.get_hero() == null)
	assert(preloader.loading_progress == 1.0)

	# 同一场景重复请求被去重，进度可安全处理已缓存的资源。
	var paths: Array[String] = [SceneLoading.HERO_SCENE_PATH, SceneLoading.HERO_SCENE_PATH]
	assert(await SceneLoading.prepare_scenes(paths, get_tree(), progress_samples.append))
	assert(not progress_samples.is_empty() and progress_samples.back() == 1.0)
	var hero_scene := SceneLoading.get_scene(SceneLoading.HERO_SCENE_PATH)
	assert(hero_scene == SceneLoading.get_scene(SceneLoading.HERO_SCENE_PATH))

	# 使用实际加载界面，从旧场景切换到生成关卡，玩家引用不能被旧场景退出覆盖。
	var old_scene := SceneLoading.get_scene(SceneLoading.HOME_SCENE_PATH).instantiate()
	get_tree().root.add_child(old_scene)
	get_tree().current_scene = old_scene
	var old_hero = DataLoader.get_hero()
	assert(is_instance_valid(old_hero))
	assert(SceneLoading.load_next_scene(SceneLoading.LEVEL_SCENE_PATH) == OK)
	assert(SceneLoading.load_next_scene(SceneLoading.LEVEL_SCENE_PATH) == ERR_BUSY)
	var loading_ui := old_scene.get_node("SceneLoadingLayer").get_child(0) as LoadingScreenUI
	for frame in range(600):
		if loading_ui._ready_to_continue or loading_ui._failed:
			break
		await get_tree().process_frame
	assert(loading_ui._ready_to_continue and not loading_ui._failed)
	assert(loading_ui._packed_scene != null)
	var event := InputEventAction.new()
	event.action = &"Interact"
	event.pressed = true
	loading_ui._unhandled_input(event)
	await get_tree().scene_changed
	assert(not is_instance_valid(old_scene))
	assert(not is_instance_valid(old_hero))
	var level := get_tree().current_scene
	assert(level.name == "LevelScene")
	var generator := level.get_node("LevelGenerator")
	assert(generator.generation_succeeded)
	assert(is_instance_valid(DataLoader.get_hero()))
	assert(DataLoader.get_hero().get_parent() == generator)

	# 重生成不能累积房间/玩家，并且仍可保留非生成子节点。
	var marker := Node.new()
	marker.name = "PersistentMarker"
	generator.add_child(marker)
	assert(generator.generate_level(0))
	assert(is_instance_valid(marker) and marker.get_parent() == generator)
	assert(generator.find_children("Hero", "", false, false).size() == 1)
	assert(generator.get_child_count() < 30)

	# 未配置的关卡在加载界面失败，保留原场景并允许关闭覆盖层。
	CurrentLevel.CurrentLevel = 999
	assert(SceneLoading.load_next_scene(SceneLoading.LEVEL_SCENE_PATH) == OK)
	loading_ui = level.get_node("SceneLoadingLayer").get_child(0)
	for frame in range(600):
		if loading_ui._failed:
			break
		await get_tree().process_frame
	assert(loading_ui._failed and get_tree().current_scene == level)
	loading_ui._unhandled_input(event)
	await get_tree().process_frame
	assert(not level.has_node("SceneLoadingLayer"))
	CurrentLevel.CurrentLevel = 0

	# 返回家园也走同一入口，完成依赖预加载后才能切换。
	assert(SceneLoading.load_next_scene(SceneLoading.HOME_SCENE_PATH) == OK)
	loading_ui = level.get_node("SceneLoadingLayer").get_child(0)
	for frame in range(600):
		if loading_ui._ready_to_continue or loading_ui._failed:
			break
		await get_tree().process_frame
	assert(loading_ui._ready_to_continue and not loading_ui._failed)
	loading_ui._unhandled_input(event)
	await get_tree().scene_changed
	assert(get_tree().current_scene.name == "Home")
	assert(is_instance_valid(DataLoader.get_hero()) and not UIManager.is_banned)
	print("SCENE_LOADING_TESTS_PASSED")
	get_tree().quit()
