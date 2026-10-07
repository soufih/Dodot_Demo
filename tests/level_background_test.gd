extends SceneTree

class BackgroundGenerator extends Node:
	signal level_generated
	signal level_clearing
	var generation_succeeded: bool = false

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(960, 540)
	var level := Node2D.new()
	var generator := BackgroundGenerator.new()
	generator.name = "LevelGenerator"
	level.add_child(generator)
	var room := Node2D.new()
	var legacy := Node2D.new()
	legacy.name = "Background"
	room.add_child(legacy)
	generator.add_child(room)
	var hero := Node2D.new()
	var camera := Camera2D.new()
	camera.name = "MainCamera"
	hero.add_child(camera)
	var old_fill := Node2D.new()
	old_fill.name = "background"
	camera.add_child(old_fill)
	generator.add_child(hero)
	var background: CanvasLayer = load(Path.LEVEL_BACKGROUND_SCRIPT).new()
	level.add_child(background)
	root.add_child(level)
	await process_frame
	generator.level_generated.emit()
	assert(not legacy.visible and not old_fill.visible)
	var material := background.get_node("BackgroundSurface").material as ShaderMaterial
	for position in [Vector2.ZERO, Vector2(-4000, 3000), Vector2(6000, -5000)]:
		camera.position = position
		await process_frame
		await process_frame
		assert(material.get_shader_parameter("camera_position").is_equal_approx(camera.get_screen_center_position()))
	assert(material.get_shader_parameter("elapsed") > 0.0)
	generator.level_clearing.emit()
	assert(legacy.visible and old_fill.visible)
	generator.level_generated.emit()
	assert(not legacy.visible and not old_fill.visible)
	camera.position = Vector2.ZERO
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(not image.is_empty())
		image.save_png(Path.LEVEL_BACKGROUND_PREVIEW_TEXTURE)
	level.queue_free()
	await process_frame
	var real_level: Node2D = load(Path.LEVEL_SCENE).instantiate()
	root.add_child(real_level)
	await process_frame
	var real_generator := real_level.get_node("LevelGenerator")
	assert(real_generator.generation_succeeded)
	for room_node in real_generator.get_children():
		for old_name in ["Background", "Backgroud", "MainCamera/background"]:
			var old := room_node.get_node_or_null(old_name) as CanvasItem
			if old != null:
				assert(not old.visible)
	assert(real_generator.generate_level(0))
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Path.LEVEL_BACKGROUND_INGAME_TEXTURE)
	real_level.queue_free()
	await process_frame
	print("PASS: background layers, camera tracking, legacy restoration and regeneration")
	quit()

