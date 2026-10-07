extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)


func _ready() -> void:
	var preloader := LevelGenerator.new()
	preloader.auto_generate = false
	add_child(preloader)
	var use_preload := OS.get_cmdline_user_args().has("--preload")
	for run in range(3):
		var started := Time.get_ticks_usec()
		if use_preload:
			assert(await preloader.prepare_level_async(0))
		var prepared := Time.get_ticks_usec()
		var scene := load(Path.LEVEL_SCENE) as PackedScene
		var loaded := Time.get_ticks_usec()
		var level := scene.instantiate()
		var instantiated := Time.get_ticks_usec()
		add_child(level)
		var attached := Time.get_ticks_usec()
		assert(level.get_node("LevelGenerator").generation_succeeded)
		assert(is_instance_valid(DataLoader.get_hero()))
		print("LEVEL_LOAD_BENCHMARK run=%d preload_ms=%.3f load_ms=%.3f instantiate_ms=%.3f attach_ms=%.3f total_ms=%.3f" % [run, (prepared - started) / 1000.0, (loaded - prepared) / 1000.0, (instantiated - loaded) / 1000.0, (attached - instantiated) / 1000.0, (attached - started) / 1000.0])
		remove_child(level)
		level.free()
		await get_tree().process_frame
	print("LEVEL_LOAD_BENCHMARK_FINISHED")
	get_tree().quit()
