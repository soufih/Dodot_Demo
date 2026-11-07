extends Node

const LOADING_SCREEN_PATH := Path.LOADING_SCREEN_SCENE
const LEVEL_SCENE_PATH := Path.LEVEL_SCENE
const HOME_SCENE_PATH := Path.HOME_SCENE
const HERO_SCENE_PATH := Path.HERO_SCENE
const LEVEL_UI_PATHS: Array[String] = [
	Path.MENU_UI_SCENE,
	Path.DEATH_UI_SCENE, Path.END_UI_SCENE
]

# 强引用保留动态场景，避免房间实例化后 PackedScene 被释放并重新解析。
static var _scene_cache: Dictionary[String, PackedScene] = {}


static func get_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	var scene := load(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene


static func prepare_scenes(paths: Array[String], tree: SceneTree, progress_callback: Callable = Callable()) -> bool:
	var pending: Array[String] = []
	for path in paths:
		if _scene_cache.has(path) or pending.has(path):
			continue
		var status := ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS and status != ResourceLoader.THREAD_LOAD_LOADED:
			var error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
			if error != OK:
				push_error("无法开始加载场景：%s (%s)" % [path, error_string(error)])
				return false
		pending.append(path)
	var total := pending.size()
	while not pending.is_empty():
		var progress_sum := float(total - pending.size())
		for path in pending.duplicate():
			# 另一批加载可能已完成同一个请求。
			if _scene_cache.has(path):
				pending.erase(path)
				progress_sum += 1.0
				continue
			var progress: Array = []
			var status := ResourceLoader.load_threaded_get_status(path, progress)
			match status:
				ResourceLoader.THREAD_LOAD_LOADED:
					var scene := ResourceLoader.load_threaded_get(path) as PackedScene
					if scene == null:
						return false
					_scene_cache[path] = scene
					pending.erase(path)
					progress_sum += 1.0
				ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					if not progress.is_empty():
						progress_sum += float(progress[0])
				_:
					push_error("场景加载失败：%s" % path)
					return false
		if progress_callback.is_valid():
			progress_callback.call(progress_sum / total)
		if not pending.is_empty():
			await tree.process_frame
	if progress_callback.is_valid():
		progress_callback.call(1.0)
	return true


static func clear_cache() -> void:
	_scene_cache.clear()


static func load_next_scene(next_scene_path: String, wait_for_input: bool = true) -> Error:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return ERR_UNCONFIGURED
	if UIManager.is_open(UIId.LOADING):
		return ERR_BUSY
	var loading_screen := UIManager.open(UIId.LOADING, {"next_scene": next_scene_path, "wait_for_input": wait_for_input})
	return OK if loading_screen != null else ERR_CANT_OPEN
