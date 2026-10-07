extends SceneTree

class MaskGenerator extends Node:
	signal level_generated
	signal level_clearing
	var generation_succeeded: bool = false

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(960, 540)
	var mask: Control = load(Path.LEVEL_OUTSIDE_MASK_SCRIPT).new()
	var view := Rect2(-100, -100, 400, 300)
	var openings: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(80, 0, 100, 100)]
	var outside: Array[Rect2] = mask.outside_rectangles(view, openings)
	var outside_area := 0.0
	for area in outside:
		outside_area += area.get_area()
		for opening in openings:
			assert(not area.intersection(opening).has_area())
	assert(is_equal_approx(outside_area, view.get_area() - 18000.0))
	var empty_openings: Array[Rect2] = []
	assert(mask.outside_rectangles(view, empty_openings).size() == 1)
	mask.free()
	var level := Node2D.new()
	level.position = Vector2(-200, 100)
	var generator := MaskGenerator.new()
	generator.name = "LevelGenerator"
	level.add_child(generator)
	var room: Node2D = load(Path.S1_SCENE).instantiate()
	var corridor: Node2D = load(Path.C1_SCENE).instantiate()
	generator.add_child(room)
	generator.add_child(corridor)
	corridor.position = room.get_node("RIGHT").position
	var background: CanvasLayer = load(Path.LEVEL_BACKGROUND_SCRIPT).new()
	level.add_child(background)
	var camera := Camera2D.new()
	level.add_child(camera)
	root.add_child(level)
	await process_frame
	generator.level_generated.emit()
	var actual_mask := background.get_node("OutsideRoomMask")
	assert(actual_mask.room_bounds.size() == 2)
	var base_layer := room.get_node("BaseLayer") as TileMapLayer
	var cells := base_layer.get_used_rect()
	var tile_size := Vector2(base_layer.tile_set.tile_size)
	var expected := base_layer.global_transform * Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)
	assert(actual_mask.room_bounds[0].is_equal_approx(expected))
	generator.level_clearing.emit()
	assert(actual_mask.room_bounds.is_empty())
	generator.level_generated.emit()
	assert(actual_mask.room_bounds.size() == 2)
	if DisplayServer.get_name() != "headless":
		camera.global_position = Vector2(1000000, -1000000)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image.get_pixel(480, 270).is_equal_approx(Color("#0f070d")))
		camera.global_position = expected.get_center()
		await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		assert(not image.get_pixel(480, 270).is_equal_approx(Color("#0f070d")))
		camera.global_position = expected.position
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Path.LEVEL_OUTSIDE_MASK_PREVIEW_TEXTURE)
	level.queue_free()
	await process_frame
	print("PASS: room/corridor bounds, union subtraction, transforms, regeneration and outside color fill")
	quit()
